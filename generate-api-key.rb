#!/usr/bin/env ruby
# Script to generate a new API key for the admin user

puts "🔑 Generating new API key for admin user..."

# Find the admin user
admin = User.find_by(login: 'admin')

if admin.nil?
  puts "❌ Admin user not found!"
  exit 1
end

puts "✅ Found admin user: #{admin.name}"

# Delete any existing API tokens for admin
Token.where(user: admin, action: 'api').destroy_all
puts "🗑️  Deleted existing API tokens"

# Create a new API token
token = Token.create!(
  user: admin,
  action: 'api'
)

puts "✅ New API key generated successfully!"
puts "🔑 API Key: #{token.value}"
puts ""
puts "📝 Add this to your .env file:"
puts "REDMINE_API_KEY=#{token.value}"
puts ""
puts "🌐 Test the API with:"
puts "curl -H \"X-Redmine-API-Key: #{token.value}\" \"http://localhost:3000/issues.json?limit=1\"" 