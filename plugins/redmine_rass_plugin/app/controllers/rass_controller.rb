require 'net/http'
require 'uri'
require 'json'

class RassController < ApplicationController
  helper RassSearchHelper
  before_action :find_optional_project_by_id, :authorize_global

  private

  # Finds the project by ID if provided, or sets it to nil
  def find_optional_project_by_id
    @project = Project.find_by_id(params[:project_id]) if params[:project_id].present?
  end
  accept_api_auth :index, :semantic_search

  def index
    # Show the enhanced search interface
    @question = params[:q]&.strip || ""
    @semantic_search = params[:semantic_search] == '1'
    @search_algorithm = params[:search_algorithm] || 'hybrid'
    @similarity_threshold = params[:similarity_threshold] || '0.6'
    
    # Get all the standard search parameters
    @all_words = params[:all_words] ? params[:all_words].present? : true
    @titles_only = params[:titles_only] ? params[:titles_only].present? : false
    @search_attachments = params[:attachments].presence || '0'
    @open_issues = params[:open_issues] ? params[:open_issues].present? : false
    
    # Handle pagination
    case params[:format]
    when 'xml', 'json'
      @offset, @limit = api_offset_and_limit
    else
      @offset = nil
      @limit = Setting.search_results_per_page.to_i
      @limit = 10 if @limit == 0
    end

    # Quick jump to an issue
    if !api_request? && (m = @question.match(/^#?(\d+)$/)) && (issue = Issue.visible.find_by_id(m[1].to_i))
      redirect_to issue_path(issue)
      return
    end

    # Determine projects to search
    projects_to_search = determine_search_scope
    
    # Get available object types
    @object_types = Redmine::Search.available_search_types.dup
    if projects_to_search.is_a? Project
      @object_types.delete('projects')
      @object_types = @object_types.select {|o| User.current.allowed_to?(:"view_#{o}", projects_to_search)}
    end

    @scope = @object_types.select {|t| params[t].present?}
    @scope = @object_types if @scope.empty?

    # Perform search based on type
    if @semantic_search && @question.present?
      perform_semantic_search(projects_to_search)
    else
      perform_standard_search(projects_to_search)
    end

    respond_to do |format|
      format.html { render :layout => false if request.xhr? }
      format.api do
        @results ||= []
        render :layout => false
      end
    end
  end

  def semantic_search
    # API endpoint for semantic search only
    @question = params[:q]&.strip || ""
    @search_algorithm = params[:algorithm] || 'hybrid'
    @similarity_threshold = params[:threshold] || 0.6
    
    if @question.present?
      perform_semantic_search(nil)
    else
      @results = []
      @result_count = 0
    end

    respond_to do |format|
      format.json { render json: format_semantic_results }
      format.xml { render xml: format_semantic_results }
    end
  end

  private

  def determine_search_scope
    case params[:scope]
    when 'all'
      nil
    when 'my_projects'
      User.current.projects
    when 'bookmarks'
      Project.where(id: User.current.bookmarked_project_ids)
    when 'subprojects'
      @project ? (@project.self_and_descendants.to_a) : nil
    else
      @project
    end
  end

  def perform_semantic_search(projects_to_search)
    options = {
      algorithm: @search_algorithm,
      threshold: @similarity_threshold.to_f,
      all_words: @all_words,
      titles_only: @titles_only,
      attachments: @search_attachments,
      open_issues: @open_issues
    }

    # Get semantic search results
    semantic_results = SemanticIssueSearch.semantic_search(@question, User.current, options)
    
    # Apply project filtering if needed
    if projects_to_search
      semantic_results = filter_by_projects(semantic_results, projects_to_search)
    end

    # Apply scope filtering
    semantic_results = filter_by_scope(semantic_results)

    # Paginate results
    @result_count = semantic_results.size
    @result_pages = Paginator.new @result_count, @limit, params['page']
    @offset ||= @result_pages.offset
    @results = semantic_results[@offset, @limit] || []

    # Count by type
    @result_count_by_type = { 'issues' => @result_count }
    
    # Set tokens for highlighting (extract from query)
    @tokens = @question.present? ? @question.split(/\s+/) : []
  end

  def perform_standard_search(projects_to_search)
    # Use Redmine's standard search
    fetcher = Redmine::Search::Fetcher.new(
      @question, User.current, @scope, projects_to_search,
      :all_words => @all_words, :titles_only => @titles_only, 
      :attachments => @search_attachments, :open_issues => @open_issues,
      :cache => params[:page].present?, :params => params.to_unsafe_hash
    )

    if fetcher.tokens.present?
      @result_count = fetcher.result_count
      @result_count_by_type = fetcher.result_count_by_type
      @tokens = fetcher.tokens

      @result_pages = Paginator.new @result_count, @limit, params['page']
      @offset ||= @result_pages.offset
      @results = fetcher.results(@offset, @result_pages.per_page)
    else
      @question = ""
      @results = []
      @result_count = 0
    end
  end

  def filter_by_projects(results, projects)
    project_ids = Array(projects).map(&:id).to_set
    results.select { |result| project_ids.include?(result.project_id) }
  end

  def filter_by_scope(results)
    return results if @scope.include?('issues')
    results.select { |result| @scope.include?(result.event_type) }
  end

  def format_semantic_results
    {
      query: @question,
      algorithm: @search_algorithm,
      threshold: @similarity_threshold,
      total_count: @result_count,
      results: @results.map do |result|
        {
          id: result.id,
          type: result.event_type,
          title: result.event_title,
          description: result.event_description,
          project: result.project_name,
          project_id: result.project_id,
          datetime: result.event_datetime,
          score: result.score,
          url: result.event_url,
          highlights: result.highlights
        }
      end
    }
  end
end