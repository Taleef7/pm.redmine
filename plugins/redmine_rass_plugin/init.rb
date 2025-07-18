Redmine::Plugin.register :redmine_rass_plugin do
  name 'Redmine RASS Plugin'
  author 'Taleef Tamsal'
  description 'This plugin provides semantic search capabilities using OpenSearch with embeddings and advanced filtering.'
  version '1.0.0'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  # Define permissions for semantic search
  permission :view_semantic_search, { :rass => [:index, :semantic_search] }, :public => true
  permission :use_semantic_search, { :rass => [:semantic_search] }, :public => true
  
  # Add menu items
  menu :top_menu, :rass, { :controller => 'rass', :action => 'index' }, :caption => 'RASS', :after => :home
  
  # Register search provider
  Redmine::Search.register :issues, :class => 'SemanticIssueSearch'
  
  # Add search options to the search form
  require_dependency 'search_helper'
  SearchHelper.send(:include, RassSearchHelper)
end