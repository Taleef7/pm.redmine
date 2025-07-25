require File.expand_path('../../test_helper', __FILE__)

class SearchControllerTest < ActionController::TestCase
  def setup
    @user = User.new(id: 1)
    Setting.plugin_redmine_rass_plugin = {
      'rass_engine_url' => 'https://rass.example.com',
      'rass_api_key' => 'testkey',
      'rass_default_page_size' => 5
    }
    @controller = SearchController.new
    @request.cookies['semantic_search'] = '1'
    User.stubs(:current).returns(@user)
  end

  def test_semantic_search_routed_to_rass
    SemanticIssueSearch.stubs(:rass_semantic_search).returns([
      SearchResult.new('issue', 123, 'Semantic Issue', 'desc', Time.current, 'Project', 1, 0.9, {})
    ])
    get :index, params: { q: 'Semantic', format: :html }
    assert_response :success
    assert assigns(:results).any? { |r| r.event_title == 'Semantic Issue' }
  end

  def test_semantic_search_fallback_to_classic
    SemanticIssueSearch.stubs(:rass_semantic_search).returns([])
    @controller.expects(:orig_index).once
    get :index, params: { q: 'Classic', format: :html }
  end
end 