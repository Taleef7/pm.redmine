#!/usr/bin/env ruby

# Simple Rails script to export issues and index them into OpenSearch
# Run this in the Redmine Rails console

require 'net/http'
require 'uri'
require 'json'

puts "🚀 Starting Simple Issue Export and Indexing..."

# OpenSearch configuration
opensearch_host = 'http://opensearch:9200'
opensearch_user = 'admin'
opensearch_pass = 'S3cure!Passw0rd2024'

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
  puts "Response: #{response.code} - #{response.body[0..200]}" if response.code.to_i >= 400
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

# Create index mapping
puts "📋 Creating index mapping..."
mapping = {
  mappings: {
    properties: {
      id: { type: "keyword" },
      subject: { type: "text", analyzer: "standard" },
      description: { type: "text", analyzer: "standard" },
      project_name: { type: "text", analyzer: "standard" },
      tracker_name: { type: "keyword" },
      status_name: { type: "keyword" },
      priority_name: { type: "keyword" },
      author_name: { type: "text", analyzer: "standard" },
      assigned_to_name: { type: "text", analyzer: "standard" },
      created_on: { type: "date" },
      updated_on: { type: "date" },
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

# Index issues one by one
puts "🔄 Indexing issues..."
success_count = 0

issues.each_with_index do |issue, index|
  # Prepare text for search
  subject = issue.subject || ""
  description = issue.description || ""
  project_name = issue.project&.name || ""
  
  search_text = "#{subject} #{description} #{project_name}".strip
  
  # Transform issue to OpenSearch format
  issue_doc = {
    id: issue.id,
    subject: subject,
    description: description,
    project_name: project_name,
    tracker_name: issue.tracker&.name,
    status_name: issue.status&.name,
    priority_name: issue.priority&.name,
    author_name: issue.author&.name,
    assigned_to_name: issue.assigned_to&.name,
    created_on: issue.created_on&.iso8601,
    updated_on: issue.updated_on&.iso8601,
    search_text: search_text
  }
  
  # Index the document
  result = make_opensearch_request("#{opensearch_host}/issues/_doc/#{issue.id}", 'PUT', issue_doc, opensearch_user, opensearch_pass)
  
  if result
    success_count += 1
    print "." if (index + 1) % 10 == 0
  else
    puts "\n❌ Failed to index issue #{issue.id}"
  end
end

puts "\n📤 Indexing complete!"
puts "✅ Successfully indexed #{success_count} out of #{issues.count} issues"

# Verify the indexing
count_result = make_opensearch_request("#{opensearch_host}/issues/_count", 'GET', nil, opensearch_user, opensearch_pass)
if count_result
  puts "📊 Index now contains #{count_result['count']} documents"
end

puts "🎉 Export and indexing complete!"
puts "🌐 Test semantic search at: http://localhost:3000/rass" 