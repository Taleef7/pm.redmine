# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

# Main search interface (integrated with Redmine search)
get '/rass', :to => 'rass#index'

# API endpoint for semantic search only
get '/rass/semantic_search', :to => 'rass#semantic_search'
post '/rass/semantic_search', :to => 'rass#semantic_search'