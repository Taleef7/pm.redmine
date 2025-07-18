#!/usr/bin/env ruby

# Rails script to export issues and index them into OpenSearch
# Run this in the Redmine Rails console

require 'net/http'
require 'uri'
require 'json'

puts "🚀 Starting Issue Export and Indexing..."

# OpenSearch configuration
opensearch_host = 'http://opensearch:9200'
opensearch_user = 'admin'
opensearch_pass = ENV['OPENSEARCH_PASS'] || (raise "Environment variable OPENSEARCH_PASS is not set")

# Function to make OpenSearch requests
def make_opensearch_request(url, method='GET', data=nil, user=nil, password=nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  
  request = case method
  when 'GET'
    Net::HTTP::Get.new(uri.request_uri)
  when 'POST'
    Net::HTTP::Post.new(uri.request_uri)
  when 'PUT'
    Net::HTTP::Put.new(uri.request_uri)
  when 'DELETE'
    Net::HTTP::Delete.new(uri.request_uri)
  end
  
  request['Content-Type'] = 'application/json'
  
  if user && password
    require 'base64'
    credentials = Base64.strict_encode64("#{user}:#{password}")
    request['Authorization'] = "Basic #{credentials}"
  end
  
  if data
    request.body = data.to_json
  end
  
  response = http.request(request)
  return JSON.parse(response.body) if response.code.to_i < 400
  nil
rescue => e
  puts "Error making request: #{e.message}"
  nil
end

# Test OpenSearch connection
puts "🔍 Testing OpenSearch connection..."
opensearch_info = make_opensearch_request(opensearch_host, 'GET', nil, opensearch_user, opensearch_pass)
if opensearch_info
  puts "✅ OpenSearch connected: #{opensearch_info['version']['number']}"
else
  puts "❌ Failed to connect to OpenSearch"
  exit 1
end

# Create or update index mapping
puts "📋 Creating index mapping..."
mapping = {
  mappings: {
    properties: {
      id: { type: "keyword" },
      subject: { type: "text", analyzer: "standard" },
      description: { type: "text", analyzer: "standard" },
      project: {
        properties: {
          id: { type: "keyword" },
          name: { type: "text", analyzer: "standard" },
          identifier: { type: "keyword" }
        }
      },
      tracker: {
        properties: {
          id: { type: "keyword" },
          name: { type: "keyword" }
        }
      },
      status: {
        properties: {
          id: { type: "keyword" },
          name: { type: "keyword" }
        }
      },
      priority: {
        properties: {
          id: { type: "keyword" },
          name: { type: "keyword" }
        }
      },
      author: {
        properties: {
          id: { type: "keyword" },
          name: { type: "text", analyzer: "standard" }
        }
      },
      assigned_to: {
        properties: {
          id: { type: "keyword" },
          name: { type: "text", analyzer: "standard" }
        }
      },
      start_date: { type: "date" },
      due_date: { type: "date" },
      done_ratio: { type: "integer" },
      is_private: { type: "boolean" },
      created_on: { type: "date" },
      updated_on: { type: "date" },
      closed_on: { type: "date" },
      similarity_score: { type: "float" },
      search_text: { type: "text", analyzer: "standard" }
    }
  },
  settings: {
    number_of_shards: 1,
    number_of_replicas: 0
  }
}

# Delete existing index if it exists
make_opensearch_request("#{opensearch_host}/issues", 'DELETE', nil, opensearch_user, opensearch_pass)

# Create new index
index_result = make_opensearch_request("#{opensearch_host}/issues", 'PUT', mapping, opensearch_user, opensearch_pass)
if index_result
  puts "✅ Index created successfully"
else
  puts "❌ Failed to create index"
  exit 1
end

# Fetch all issues from database
puts "📥 Fetching issues from database..."
issues = Issue.includes(:project, :tracker, :status, :priority, :author, :assigned_to).all

puts "📊 Found #{issues.count} issues"

# Transform and index issues
puts "🔄 Transforming and indexing issues..."
bulk_data = ""

issues.each_with_index do |issue, index|
  # Prepare text for search
  subject = issue.subject || ""
  description = issue.description || ""
  project_name = issue.project&.name || ""
  
  search_text = "#{subject} #{description} #{project_name}".strip
  
  # Calculate simple similarity score
  similarity_score = [1.0, search_text.length / 1000.0].min
  
  # Transform issue to OpenSearch format
  issue_doc = {
    id: issue.id,
    subject: subject,
    description: description,
    project: {
      id: issue.project&.id,
      name: issue.project&.name,
      identifier: issue.project&.identifier
    },
    tracker: {
      id: issue.tracker&.id,
      name: issue.tracker&.name
    },
    status: {
      id: issue.status&.id,
      name: issue.status&.name
    },
    priority: {
      id: issue.priority&.id,
      name: issue.priority&.name
    },
    author: {
      id: issue.author&.id,
      name: issue.author&.name
    },
    assigned_to: {
      id: issue.assigned_to&.id,
      name: issue.assigned_to&.name
    },
    start_date: issue.start_date&.iso8601,
    due_date: issue.due_date&.iso8601,
    done_ratio: issue.done_ratio,
    is_private: issue.is_private,
    created_on: issue.created_on&.iso8601,
    updated_on: issue.updated_on&.iso8601,
    closed_on: issue.closed_on&.iso8601,
    similarity_score: similarity_score,
    search_text: search_text
  }
  
  # Add to bulk data
  bulk_data += { index: { _index: "issues", _id: issue.id } }.to_json + "\n"
  bulk_data += issue_doc.to_json + "\n"
  
  if (index + 1) % 10 == 0
    print "."
  end
end

puts "\n📤 Indexing #{issues.count} issues..."

# Bulk index the data
bulk_result = make_opensearch_request("#{opensearch_host}/_bulk", 'POST', bulk_data, opensearch_user, opensearch_pass)

if bulk_result
  puts "✅ Successfully indexed #{issues.count} issues"
  
  # Verify the indexing
  count_result = make_opensearch_request("#{opensearch_host}/issues/_count", 'GET', nil, opensearch_user, opensearch_pass)
  if count_result
    puts "📊 Index now contains #{count_result['count']} documents"
  end
else
  puts "❌ Failed to index issues"
end

puts "🎉 Export and indexing complete!"
puts "🌐 Test semantic search at: http://localhost:3000/rass" 