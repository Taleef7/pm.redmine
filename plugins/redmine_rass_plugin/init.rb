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
  permission :manage_rass_settings, { :rass_settings => [:index, :update, :test_embedding] }, :require => :loggedin
  
  # Register search provider
  Redmine::Search.register :issues, :class => 'SemanticIssueSearch'
  
  # Add search options to the search form
  require_dependency 'search_helper'
  SearchHelper.send(:include, RassSearchHelper)
  
  # Add the plugin's lib directory to the load path
  lib_path = File.expand_path('../lib', __FILE__)
  $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
  require 'redmine_rass_plugin/hooks/semantic_search_hook_listener'
  
  # Load settings
  settings :default => {
    'embedding_provider' => 'hash',
    'openai_api_key' => '',
    'cohere_api_key' => '',
    'default_search_algorithm' => 'hybrid',
    'default_similarity_threshold' => '0.6',
    'enable_embedding_cache' => true,
    'embedding_cache_ttl' => 3600,
    'embedding_cache_size' => 1000
  }, :partial => 'rass_settings/index'
end

Rails.application.config.to_prepare do
  require_dependency 'search_controller'
  require_dependency 'redmine_rass_plugin/search_controller_patch'
end