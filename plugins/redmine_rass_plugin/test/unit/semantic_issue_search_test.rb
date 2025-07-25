require File.expand_path('../../test_helper', __FILE__)
require 'semantic_issue_search'

class SemanticIssueSearchTest < ActiveSupport::TestCase
  def setup
    @user = User.new(id: 1)
    Setting.plugin_redmine_rass_plugin = {
      'rass_engine_url' => 'https://rass.example.com',
      'rass_api_key' => 'testkey',
      'rass_default_page_size' => 5
    }
  end

  def test_rass_semantic_search_success
    response_body = {
      'results' => [
        {
          'id' => 123,
          'subject' => 'Test Issue',
          'description' => 'Test description',
          'created_at' => '2024-06-01T12:00:00Z',
          'project' => 'Test Project',
          'project_id' => 42,
          'score' => 0.99,
          'highlights' => { 'subject' => ['<em>Test</em> Issue'] }
        }
      ]
    }.to_json
    mock_http_request(mock(code: '200', body: response_body))

    results = SemanticIssueSearch.rass_semantic_search('Test', @user)
    assert_equal 1, results.size
    result = results.first
    assert_equal 'Test Issue', result.event_title
    assert_equal 123, result.instance_variable_get(:@id)
    assert_equal 'Test Project', result.instance_variable_get(:@project_name)
    assert_equal 0.99, result.score
    assert_equal({ 'subject' => ['<em>Test</em> Issue'] }, result.highlights)
  end

  def test_rass_semantic_search_error_fallback
    http = mock()
    req = mock()
    Net::HTTP.stubs(:new).returns(http)
    http.stubs(:use_ssl=)
    Net::HTTP::Post.stubs(:new).returns(req)
    req.stubs(:[]=)
    req.stubs(:body=)
    http.stubs(:request).raises(StandardError.new('connection failed'))

    results = SemanticIssueSearch.rass_semantic_search('Test', @user)
    assert_equal [], results
  end

  def test_rass_semantic_search_non_200_response
    http = mock()
    req = mock()
    Net::HTTP.stubs(:new).returns(http)
    http.stubs(:use_ssl=)
    Net::HTTP::Post.stubs(:new).returns(req)
    req.stubs(:[]=)
    req.stubs(:body=)
    http.stubs(:request).returns(mock(code: '500', body: 'Internal Server Error'))

    results = SemanticIssueSearch.rass_semantic_search('Test', @user)
    assert_equal [], results
  end
end 