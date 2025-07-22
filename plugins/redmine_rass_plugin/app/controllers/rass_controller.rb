require 'net/http'
require 'uri'
require 'json'

class RassController < ApplicationController
  helper RassSearchHelper
  before_action :find_optional_project_by_id, :authorize_global
  before_action :intercept_semantic_search, only: [:index]

  private

  def intercept_semantic_search
    if request.cookies['semantic_search'] == '1'
      # Route to semantic search logic
      # (This is a placeholder; actual routing/interception may require monkey-patching or a middleware approach)
      # Example: render 'semantic_search_results' and halt
    end
  end

  # Finds the project by ID if provided, or sets it to nil
  def find_optional_project_by_id
    @project = Project.find_by_id(params[:project_id]) if params[:project_id].present?
  end
  accept_api_auth :index, :semantic_search

  # Remove index action and any /rass page logic. Only keep helper methods or API endpoints if needed.

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

  # Class method to be called from SearchController for semantic search
  def self.semantic_search_from_search_controller(params, user)
    # Extract query and options from params
    query = params[:q]&.strip || ""
    options = {
      algorithm: params[:search_algorithm] || 'hybrid',
      threshold: params[:similarity_threshold] || 0.6
      # Add more options as needed
    }
    # Call the SemanticIssueSearch model
    results = SemanticIssueSearch.semantic_search(query, user, options)
    # TODO: Integrate with RASS-specific APIs/services as needed (placeholder)
    # Return results in the format expected by the search view
    results
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