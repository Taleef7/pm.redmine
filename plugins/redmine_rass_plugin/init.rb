Redmine::Plugin.register :redmine_rass_plugin do
  name 'Redmine Rass Plugin'
  author 'Taleef Tamsal'
  description 'This plugin provides an interface to the RASS engine.'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  # Define a new permission for our plugin
  permission :view_rass_page, { :rass => [:index] }, :public => true
  
  # Add a new item to the top menu
  menu :top_menu, :rass, { :controller => 'rass', :action => 'index' }, :caption => 'RASS', :after => :home
end