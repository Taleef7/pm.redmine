#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

# Test Redmine API access
api_key = ENV['REDMINE_API_KEY']
if api_key.nil? || api_key.empty?
  raise "❌ Error: REDMINE_API_KEY environment variable is not set."
end
base_url = 'http://localhost:3000'

puts "Testing Redmine API access..."
puts "API Key: #{api_key}"
puts "Base URL: #{base_url}"

# Test basic connectivity
begin
  uri = URI("#{base_url}/issues.json")
  http = Net::HTTP.new(uri.host, uri.port)
  
  request = Net::HTTP::Get.new(uri)
  request['X-Redmine-API-Key'] = api_key
  request['Content-Type'] = 'application/json'
  
  puts "\nMaking request to: #{uri}"
  response = http.request(request)
  
  puts "Response Code: #{response.code}"
  puts "Response Headers: #{response.to_hash}"
  puts "Response Body: #{response.body[0..500]}..."
  
  if response.code == '200'
    data = JSON.parse(response.body)
    puts "\n✅ Success! Found #{data['issues']&.length || 0} issues"
  else
    puts "\n❌ Failed with status: #{response.code}"
  end
  
rescue => e
  puts "❌ Error: #{e.message}"
end 