# Rails script to generate diverse test data for semantic search testing
# Run this in the Redmine Rails console

puts "🚀 Starting Enhanced Test Data Generation via Rails Console..."

# Project definitions
project_defs = [
  { name: "Software Platform", identifier: "software-platform", description: "Platform for software development and deployment." },
  { name: "Marketing Campaigns", identifier: "marketing-campaigns", description: "All marketing and outreach efforts." },
  { name: "HR Operations", identifier: "hr-operations", description: "Human resources and employee management." },
  { name: "Research & Development", identifier: "rnd", description: "R&D and innovation projects." }
]

# Ensure projects exist
projects = project_defs.map do |defn|
  Project.find_or_create_by!(identifier: defn[:identifier]) do |p|
    p.name = defn[:name]
    p.description = defn[:description]
  end
end
puts "✅ Ensured #{projects.size} projects exist."

# Ensure trackers, priorities, statuses
trackers = Tracker.all.presence || [Tracker.create!(name: "Bug"), Tracker.create!(name: "Feature"), Tracker.create!(name: "Task")]
priorities = IssuePriority.all.presence || [IssuePriority.create!(name: "Low"), IssuePriority.create!(name: "Normal"), IssuePriority.create!(name: "High")] 
statuses = IssueStatus.all.presence || [IssueStatus.create!(name: "Open"), IssueStatus.create!(name: "In Progress"), IssueStatus.create!(name: "Closed")]

# Ensure some users for assignment - only use valid assignees
admin = User.find_by(login: 'admin')
valid_users = User.where(status: 1).select { |u| u.allowed_to?(:add_issues, nil, global: true) }.to_a
valid_users << admin if admin && !valid_users.include?(admin)

if valid_users.empty?
  puts "⚠️  No valid assignees found. Issues will be created without assignment."
  valid_users = [nil]
end

puts "✅ Found #{valid_users.size} valid assignees."

# Ensure custom fields
custom_fields = []
custom_fields << IssueCustomField.find_or_create_by!(name: "Severity", field_format: "list") do |cf|
  cf.possible_values = ["Critical", "Major", "Minor", "Trivial"]
  cf.is_for_all = true
  cf.is_filter = true
end
custom_fields << IssueCustomField.find_or_create_by!(name: "Customer", field_format: "string") do |cf|
  cf.is_for_all = true
  cf.is_filter = true
end
custom_fields << IssueCustomField.find_or_create_by!(name: "Due Quarter", field_format: "list") do |cf|
  cf.possible_values = ["Q1", "Q2", "Q3", "Q4"]
  cf.is_for_all = true
  cf.is_filter = true
end
custom_fields << IssueCustomField.find_or_create_by!(name: "Remote Work", field_format: "bool") do |cf|
  cf.is_for_all = true
  cf.is_filter = true
end
custom_fields << IssueCustomField.find_or_create_by!(name: "Launch Date", field_format: "date") do |cf|
  cf.is_for_all = true
  cf.is_filter = true
end
puts "✅ Ensured #{custom_fields.size} custom fields exist."

# Issue templates for each project
issue_templates = {
  "Software Platform" => [
    ["Fix authentication bug", "Users can't log in with special characters."],
    ["Implement CI/CD pipeline", "Automate build and deployment for all services."],
    ["Refactor legacy code", "Improve maintainability of the payment module."],
    ["Add API documentation", "Generate OpenAPI docs for all endpoints."],
    ["Upgrade Ruby version", "Move to Ruby 3.2 for performance and security."],
    ["Optimize database queries", "Reduce load times for dashboard reports."],
    ["Integrate OAuth login", "Allow users to sign in with Google and GitHub."],
    ["Fix session timeout issue", "Sessions expire too quickly for some users."],
    ["Add error tracking", "Integrate Sentry for real-time error monitoring."],
    ["Implement feature flags", "Enable gradual rollout of new features."]
  ],
  "Marketing Campaigns" => [
    ["Launch Q4 social campaign", "Target LinkedIn and Twitter for B2B leads."],
    ["Design new email template", "Increase open rates with modern design."],
    ["Update website banners", "Highlight new product features."],
    ["Plan influencer outreach", "Identify 10 key industry influencers."],
    ["Create product explainer video", "Script and storyboard for YouTube."],
    ["Optimize landing page", "A/B test new call-to-action buttons."],
    ["Print trade show materials", "Brochures and roll-up banners for booth."],
    ["Collect customer testimonials", "Video interviews with top clients."],
    ["Plan PR for launch", "Coordinate with tech media outlets."],
    ["Design infographic", "Visualize 2024 industry trends."]
  ],
  "HR Operations" => [
    ["Update employee handbook", "Add new remote work and leave policies."],
    ["Plan team building retreat", "Outdoor activities for all departments."],
    ["Review performance process", "Standardize annual review forms."],
    ["Organize diversity training", "Mandatory for all managers."],
    ["Update job descriptions", "Reflect new hybrid work expectations."],
    ["Launch recognition program", "Monthly awards for top performers."],
    ["Review compensation bands", "Benchmark against industry data."],
    ["Organize wellness week", "Yoga, nutrition, and stress management."],
    ["Streamline recruitment", "Automate resume screening."],
    ["Plan leadership workshop", "Develop future managers."]
  ],
  "Research & Development" => [
    ["Prototype AI assistant", "Build a chatbot for customer support."],
    ["Evaluate new database", "Test performance of TimescaleDB."],
    ["Run user interviews", "Gather feedback on beta features."],
    ["Develop mobile app POC", "iOS and Android MVP for field teams."],
    ["Integrate IoT sensors", "Real-time data from factory equipment."],
    ["Test AR onboarding", "Augmented reality for new hires."],
    ["Analyze competitor patents", "Identify gaps in our IP portfolio."],
    ["Publish research paper", "Submit to top industry conference."],
    ["Build data pipeline", "Automate ETL for analytics."],
    ["Explore quantum algorithms", "Assess feasibility for logistics."]
  ]
}

puts "📊 Generating Issues for Each Project..."
total_created = 0

projects.each do |project|
  puts "\nProject: #{project.name}"
  templates = issue_templates[project.name]
  created_count = 0
  
  templates.each_with_index do |(subject, description), i|
    begin
      tracker = trackers[i % trackers.size]
      priority = priorities[i % priorities.size]
      status = statuses[i % statuses.size]
      assignee = valid_users[i % valid_users.size]
      
      custom_values = {
        custom_fields[0].id => ["Critical", "Major", "Minor", "Trivial"][i % 4],
        custom_fields[1].id => "Customer_#{project.identifier}_#{i+1}",
        custom_fields[2].id => ["Q1", "Q2", "Q3", "Q4"][i % 4],
        custom_fields[3].id => (i % 2 == 0 ? "1" : "0"),
        custom_fields[4].id => (Date.today + i).to_s
      }
      
      issue = Issue.new(
        project: project,
        subject: subject,
        description: "#{description}\n\nProject: #{project.name}\nUnique tag: ##{project.identifier}_#{i+1}",
        author: admin,
        tracker: tracker,
        status: status,
        priority: priority,
        assigned_to: assignee,
        custom_field_values: custom_values
      )
      
      if issue.save
        created_count += 1
        print "."
      else
        puts "\n⚠️  Failed to create issue: #{issue.errors.full_messages.join(', ')}"
      end
      
    rescue => e
      puts "\n❌ Error creating issue #{i+1} for #{project.name}: #{e.message}"
      next
    end
  end
  
  puts "\n✅ Created #{created_count} issues for #{project.name}"
  total_created += created_count
end

puts "\n🎉 Enhanced Test Data Generation Complete!"
puts "📊 Total issues created: #{total_created}"
puts "🌐 Now run the ETL script to index this data: ./run-etl.sh" 