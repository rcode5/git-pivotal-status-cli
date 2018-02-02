#!/usr/bin/env ruby

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem 'git'
  gem 'tracker_api'
  gem 'byebug'
end

require "tracker_api"
require "git"

pivotal_api_key = ENV["PIVOTAL_TRACKER_API_KEY"]
project_id = ENV["PIVOTAL_TRACKER_PROJECT_ID"]

if !pivotal_api_key || !project_id
  puts "************************************************************************"
  puts "*"
  puts "* You need to set PIVOTAL_TRACKER_API_KEY and PIVOTAL_TRACKER_PROJECT_ID"
  puts "* in your environment."
  puts "*"
  puts "* The api key value is available on the Pivotal Tracker site at the "
  puts "* bottom or your account's profile page."
  puts "*"
  puts "* Please set those environment variable and try again."
  puts "* "
  exit(1)
end

pivotal_client = TrackerApi::Client.new(token: pivotal_api_key)
project = pivotal_client.project(project_id)

git = Git.open(File.absolute_path("."))
git.fetch

StoryStatus = Struct.new(:id, :state, :name, :owners, :branch_name, :sha)

print "Fetching Stories ..."

stories = git.branches.each_with_object([]) do |branch, memo|
  next unless branch.name =~ /(\d{9})$/
  id = $1;

  story = project.story(id)
  memo << StoryStatus.new(id,
                          story.current_state, story.name, story.owners.map(&:name),
                          branch.name, branch.gcommit.sha)
  print "."
end

puts

stories_by_state = stories.each_with_object({}) do |story, memo|
  (memo[story.state] ||= []) << story
end

story_types = (ARGV + ["finished"]).flatten.compact.uniq

stories_by_state.slice(*story_types).each do |type, stories|
  puts "--- #{type} stories"
  stories.each do |story|
    puts "#{story.id} #{story.branch_name} : #{story.name} by #{story.owners.join(',')}"
  end
end
