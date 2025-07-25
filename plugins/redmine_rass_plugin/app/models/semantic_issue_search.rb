require 'net/http'
require 'uri'
require 'json'

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
      # Generate embedding for the query
      query_embedding = generate_embedding(query)
      
      {
        query: {
          bool: {
            must: [
              {
                knn: {
                  embedding_vector: {
                    vector: query_embedding,
                    k: 50
                  }
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
      # Generate embedding for the query
      query_embedding = generate_embedding(query)
      
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
              # Vector similarity with boost
              {
                knn: {
                  embedding_vector: {
                    vector: query_embedding,
                    k: 50
                  }
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
    
    def generate_embedding(text)
      # Use production-grade embedding service with proper error handling and caching
      return generate_hash_embedding(text) if text.blank?
      
      # Check cache first
      cache = EmbeddingCache.instance
      cached_embedding = cache.get(text)
      return cached_embedding if cached_embedding
      
      # Try to use the configured embedding provider
      provider = get_embedding_provider
      
      embedding = case provider
      when 'openai'
        generate_openai_embedding(text)
      when 'cohere'
        generate_cohere_embedding(text)
      when 'gemini'
        generate_gemini_embedding(text)
      else
        generate_hash_embedding(text)
      end
      
      # Cache the result
      cache.set(text, embedding)
      embedding
      
    rescue => e
      Rails.logger.error "Embedding generation failed: #{e.message}, falling back to hash-based embedding"
      fallback_embedding = generate_hash_embedding(text)
      cache.set(text, fallback_embedding) if text.present?
      fallback_embedding
    end
    
    def get_embedding_provider
      # Check environment variable first
      provider = ENV['EMBEDDING_PROVIDER']
      return provider if provider.present?
      
      # Check Redmine settings
      Setting.plugin_redmine_rass_plugin&.dig('embedding_provider') || 'hash'
    end
    
    def generate_openai_embedding(text)
      api_key = ENV['OPENAI_API_KEY'] || Setting.plugin_redmine_rass_plugin&.dig('openai_api_key')
      return generate_hash_embedding(text) unless api_key.present?
      
      api_url = ENV['OPENAI_API_URL'] || Setting.plugin_redmine_rass_plugin&.dig('openai_api_url') || 'https://api.openai.com/v1/embeddings'
      uri = URI.parse(api_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri.request_uri)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'
      request.body = {
        input: text,
        model: 'text-embedding-ada-002'
      }.to_json
      
      response = http.request(request)
      
      if response.is_a?(Net::HTTPSuccess)
        result = JSON.parse(response.body)
        result['data'][0]['embedding']
      else
        raise "OpenAI API error: #{response.code} - #{response.body}"
      end
    rescue => e
      Rails.logger.error "OpenAI embedding failed: #{e.message}"
      raise e
    end
    
    def generate_cohere_embedding(text)
      api_key = ENV['COHERE_API_KEY'] || Setting.plugin_redmine_rass_plugin&.dig('cohere_api_key')
      return generate_hash_embedding(text) unless api_key.present?
      
      uri = URI.parse('https://api.cohere.ai/v1/embed')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri.request_uri)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'
      request.body = {
        texts: [text],
        model: 'embed-english-v3.0'
      }.to_json
      
      response = http.request(request)
      
      if response.is_a?(Net::HTTPSuccess)
        result = JSON.parse(response.body)
        result['embeddings'][0]
      else
        raise "Cohere API error: #{response.code} - #{response.body}"
      end
    rescue => e
      Rails.logger.error "Cohere embedding failed: #{e.message}"
      raise e
    end
    
    def generate_gemini_embedding(text)
      api_key = ENV['GEMINI_API_KEY'] || Setting.plugin_redmine_rass_plugin&.dig('gemini_api_key')
      model = ENV['GEMINI_MODEL'] || Setting.plugin_redmine_rass_plugin&.dig('gemini_model') || 'models/gemini-embedding-001'
      return generate_hash_embedding(text) unless api_key.present?

      uri = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.request_uri)
      request['x-goog-api-key'] = api_key
      request['Content-Type'] = 'application/json'
      request.body = {
        model: 'models/gemini-embedding-001',
        content: {
          parts: [ { text: text } ]
        }
      }.to_json

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        result = JSON.parse(response.body)
        result.dig('embedding', 'values')
      else
        raise "Gemini API error: #{response.code} - #{response.body}"
      end
    rescue => e
      Rails.logger.error "Gemini embedding failed: #{e.message}"
      raise e
    end

    def generate_hash_embedding(text)
      # Fallback hash-based embedding for development or when APIs fail
      require 'digest'
      
      if text.blank?
        return Array.new(1536, 0.0)
      end
      
      # Create a deterministic vector based on text hash
      hash_obj = Digest::SHA256.digest(text)
      hash_bytes = hash_obj.bytes
      
      vector = []
      (0...1536).each do |i|
        byte_index = i % hash_bytes.length
        vector << (hash_bytes[byte_index] / 255.0) * 2 - 1
      end
      
      vector
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
      return [] if opensearch_results['hits']['hits'].empty?
      
      opensearch_results['hits']['hits'].map do |hit|
        source = hit['_source']
        highlights = hit['highlight'] || {}
        
        SearchResult.new(
          'issue',
          source['id'],
          source['subject'] || '',
          source['description'] || '',
          source['created_on'] || Time.current,
          source.dig('project', 'name') || '',
          source.dig('project', 'id'),
          hit['_score'] || 0.0,
          highlights
        )
      end
    end

    # Call RASS Engine for semantic search if enabled
    def self.rass_semantic_search(query, user, options = {})
      rass_url = Setting.plugin_redmine_rass_plugin['rass_engine_url']
      page_size = (Setting.plugin_redmine_rass_plugin['rass_default_page_size'] || 10).to_i
      api_key = Setting.plugin_redmine_rass_plugin['rass_api_key']
      return [] if rass_url.blank?

      uri = URI(rass_url) + '/search/semantic'
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')

      req = Net::HTTP::Post.new(uri.path)
      req['Content-Type'] = 'application/json'
      req['x-user-id'] = user.id.to_s
      req['Authorization'] = "Bearer #{api_key}" if api_key.present?
      filters = options[:filters] || {}
      req.body = {
        q: query,
        k: options[:per_page] || page_size,
        filters: filters
      }.to_json

      begin
        resp = http.request(req)
        if resp.code.to_i == 200
          data = JSON.parse(resp.body)
          if data['results']
            return data['results'].map { |r| rass_result_to_search_result(r) }
          elsif data['data'] && data['data']['results']
            return data['data']['results'].map { |r| rass_result_to_search_result(r) }
          end
        else
          # Log error and trigger fallback to classic search
          Rails.logger.error "RASS Engine returned error: #{resp.code} #{resp.body}"
        end
        []
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => e
        Rails.logger.error "RASS Engine network error: #{e.message}"
        # Return empty array to trigger fallback to classic search
        []
      rescue JSON::ParserError => e
        Rails.logger.error "RASS Engine JSON parsing error: #{e.message}"
        # Return empty array to trigger fallback to classic search
        []
      rescue StandardError => e
        Rails.logger.error "RASS Engine unexpected error: #{e.message}"
        # Return empty array to trigger fallback to classic search
        []
      end
    end

    # Map a RASS result to a Redmine SearchResult (stub for now)
    def self.rass_result_to_search_result(rass_result)
      # Robust mapping from RASS result to Redmine SearchResult
      # Handles alternative field names and missing data gracefully
      SearchResult.new(
        'issue',
        rass_result['id'] || rass_result['issue_id'] || 0,
        rass_result['subject'] || rass_result['title'] || '',
        rass_result['description'] || rass_result['summary'] || '',
        rass_result['created_at'] || rass_result['created_on'] || Time.current,
        rass_result['project'] || rass_result['project_name'] || '',
        rass_result['project_id'] || nil,
        rass_result['score'] || rass_result['similarity'] || 0.0,
        rass_result['highlights'] || {}
      )
    end
  end
end

class SearchResult
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

  def score
    @score
  end

  def highlights
    @highlights
  end
end 