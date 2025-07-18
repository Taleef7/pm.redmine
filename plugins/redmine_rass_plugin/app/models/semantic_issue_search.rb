class SemanticIssueSearch
  # Remove the problematic acts_as_searchable line since this is not an ActiveRecord model
  
  class << self
    def semantic_search(query, user, options = {})
      return [] if query.blank?
      
      # Get semantic search results from OpenSearch
      semantic_results = perform_semantic_search(query, user, options)
      
      # Filter results based on user permissions
      filtered_results = filter_by_permissions(semantic_results, user)
      
      # Convert to Redmine search result format
      convert_to_search_results(filtered_results)
    end
    
    private
    
    def perform_semantic_search(query, user, options = {})
      algorithm = options[:algorithm] || 'hybrid'
      threshold = options[:threshold] || 0.6
      
      opensearch_host = ENV['OPENSEARCH_HOST'] || 'http://opensearch:9200'
      uri = URI.parse("#{opensearch_host}/issues/_search")
      
      # Build search query based on algorithm
      search_body = build_search_query(query, algorithm, threshold, options)
      
      # Make request to OpenSearch
      response = make_opensearch_request(uri, search_body)
      
      if response&.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        { 'hits' => { 'hits' => [], 'total' => { 'value' => 0 } } }
      end
    rescue => e
      Rails.logger.error "Semantic search error: #{e.message}"
      { 'hits' => { 'hits' => [], 'total' => { 'value' => 0 } } }
    end
    
    def build_search_query(query, algorithm, threshold, options)
      case algorithm
      when 'semantic'
        build_semantic_query(query, threshold)
      when 'hybrid'
        build_hybrid_query(query, threshold)
      when 'lexical'
        build_lexical_query(query)
      else
        build_hybrid_query(query, threshold)
      end
    end
    
    def build_semantic_query(query, threshold)
      {
        query: {
          bool: {
            must: [
              {
                multi_match: {
                  query: query,
                  fields: [
                    "subject^3",
                    "description^2", 
                    "project_name^2",
                    "search_text"
                  ],
                  type: "best_fields",
                  fuzziness: "AUTO"
                }
              }
            ],
            filter: [
              { range: { similarity_score: { gte: threshold } } }
            ]
          }
        },
        size: 50,
        _source: ['id', 'subject', 'description', 'project_name', 'tracker_name', 'status_name', 'priority_name', 'author_name', 'assigned_to_name', 'created_on', 'updated_on'],
        highlight: {
          fields: {
            subject: {},
            description: {},
            project_name: {},
            search_text: {}
          }
        }
      }
    end
    
    def build_hybrid_query(query, threshold)
      {
        query: {
          bool: {
            should: [
              # Text matching with boost
              {
                multi_match: {
                  query: query,
                  fields: [
                    "subject^3",
                    "description^2",
                    "project_name^2",
                    "tracker_name",
                    "status_name", 
                    "priority_name",
                    "author_name",
                    "assigned_to_name",
                    "search_text"
                  ],
                  type: "best_fields",
                  fuzziness: "AUTO"
                }
              },
              # Similarity score boost
              {
                range: {
                  similarity_score: {
                    gte: threshold,
                    boost: 2.0
                  }
                }
              }
            ],
            minimum_should_match: 1
          }
        },
        size: 50,
        _source: ['id', 'subject', 'description', 'project_name', 'tracker_name', 'status_name', 'priority_name', 'author_name', 'assigned_to_name', 'created_on', 'updated_on'],
        highlight: {
          fields: {
            subject: {},
            description: {},
            project_name: {},
            search_text: {}
          }
        }
      }
    end
    
    def build_lexical_query(query)
      {
        query: {
          multi_match: {
            query: query,
            fields: [
              "subject^3",
              "description^2",
              "project_name^2",
              "tracker_name",
              "status_name",
              "priority_name", 
              "author_name",
              "assigned_to_name",
              "search_text"
            ],
            type: "best_fields",
            fuzziness: "AUTO"
          }
        },
        size: 50,
        _source: ['id', 'subject', 'description', 'project_name', 'tracker_name', 'status_name', 'priority_name', 'author_name', 'assigned_to_name', 'created_on', 'updated_on'],
        highlight: {
          fields: {
            subject: {},
            description: {},
            project_name: {},
            search_text: {}
          }
        }
      }
    end
    
    def make_opensearch_request(uri, search_body)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      request.body = search_body.to_json
      
      # Add authentication if configured
      if ENV['OPENSEARCH_USER'] && ENV['OPENSEARCH_PASS']
        request.basic_auth(ENV['OPENSEARCH_USER'], ENV['OPENSEARCH_PASS'])
      end
      
      http.request(request)
    end
    
    def filter_by_permissions(results, user)
      return [] if results['hits']['hits'].empty?
      
      issue_ids = results['hits']['hits'].map { |hit| hit['_source']['id'] }
      visible_issues = Issue.visible(user).where(id: issue_ids).pluck(:id).to_set
      
      results['hits']['hits'].select do |hit|
        visible_issues.include?(hit['_source']['id'])
      end
    end
    
    def convert_to_search_results(opensearch_results)
      opensearch_results.map do |hit|
        source = hit['_source']
        highlight = hit['highlight'] || {}
        
        SearchResult.new(
          'issue',
          source['id'],
          source['subject'],
          source['description'],
          source['created_on'],
          source['project_name'],
          nil, # project_id not available in simplified structure
          hit['_score'],
          highlight
        )
      end
    end
  end
end

# Custom search result class
class SearchResult
  attr_accessor :type, :id, :title, :description, :datetime, :project_name, :project_id, :score, :highlights
  
  def initialize(type, id, title, description, datetime, project_name, project_id, score, highlights = {})
    @type = type
    @id = id
    @title = title
    @description = description
    @datetime = datetime
    @project_name = project_name
    @project_id = project_id
    @score = score
    @highlights = highlights
  end
  
  def event_type
    @type
  end
  
  def event_title
    @title
  end
  
  def event_description
    @description
  end
  
  def event_datetime
    @datetime
  end
  
  def project
    Project.find(@project_id) if @project_id
  end
  
  def event_url
    case @type
    when 'issue'
      "/issues/#{@id}"
    else
      "#"
    end
  end
end 