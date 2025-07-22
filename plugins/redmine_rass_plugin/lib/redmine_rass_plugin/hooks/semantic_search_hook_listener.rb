module RedmineRassPlugin
  module Hooks
    class SemanticSearchHookListener < Redmine::Hook::ViewListener
      render_on :view_search_index_options_content_bottom, partial: 'rass/semantic_search_toggle'
    end
  end
end 