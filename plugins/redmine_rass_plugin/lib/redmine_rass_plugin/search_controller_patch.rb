# frozen_string_literal: true

require_dependency 'search_controller'

module RedmineRassPlugin
  module SearchControllerPatch
    def self.included(base)
      base.class_eval do
        alias_method :orig_index, :index

        def index
          semantic = (cookies['semantic_search'] == '1') || (params[:semantic] == '1')
          if semantic && params[:q].present?
            @question = params[:q]&.strip || ""
            @all_words = params[:all_words] ? params[:all_words].present? : true
            @titles_only = params[:titles_only] ? params[:titles_only].present? : false
            @search_attachments = params[:attachments].presence || '0'
            @open_issues = params[:open_issues] ? params[:open_issues].present? : false
            @scope = Redmine::Search.available_search_types.dup
            @result_pages = nil
            @offset = nil
            @limit = Setting.search_results_per_page.to_i
            @limit = 10 if @limit == 0
            @results = SemanticIssueSearch.rass_semantic_search(@question, User.current, page: params[:page] || 1, per_page: @limit)
            @result_count = @results.size
            @result_count_by_type = { 'issues' => @result_count }
            @tokens = @question.present? ? @question.split(/\s+/) : []
            respond_to do |format|
              format.html {render :layout => false if request.xhr?}
              format.api do
                @results ||= []
                render :layout => false
              end
            end
            return
          end
          orig_index
        end
      end
    end
  end
end

unless SearchController.included_modules.include?(RedmineRassPlugin::SearchControllerPatch)
  SearchController.send(:include, RedmineRassPlugin::SearchControllerPatch)
end 