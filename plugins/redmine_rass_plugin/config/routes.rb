# Only keep settings or API routes if needed. Remove /rass or index routes.
# Example:
# RedmineApp::Application.routes.draw do
#   # No /rass route
# end

# Settings management
get '/rass/settings', :to => 'rass_settings#index'
post '/rass/settings', :to => 'rass_settings#update'
post '/rass/settings/test_embedding', :to => 'rass_settings#test_embedding'