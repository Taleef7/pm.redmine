# frozen_string_literal: true

require_dependency 'search_controller'

module RedmineRassPlugin
  module SearchControllerPatch
    def self.included(base)
      base.class_eval do
        alias_method :orig_index, :index

        def index
          # Check for semantic search toggle (cookie or param)
          semantic = (cookies['semantic_search'] == '1') || (params[:semantic] == '1')
          if semantic && params[:q].present?
            # Call semantic search logic (example, adapt as needed)
            sanitized_options = { query: params[:q] }
            @results = ::SemanticIssueSearch.semantic_search(params[:q], User.current, sanitized_options)
            @result_count = @results.size
            @result_count_by_type = {} # Optionally, group by type if needed
            @tokens = [] # Optionally, extract tokens if needed
            render 'search/index'
          else
            orig_index
          end
        end
      end
    end
  end
end

unless SearchController.included_modules.include?(RedmineRassPlugin::SearchControllerPatch)
  SearchController.send(:include, RedmineRassPlugin::SearchControllerPatch)
end 