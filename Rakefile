require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'yard'

RSpec::Core::RakeTask.new
YARD::Rake::YardocTask.new

task :default => :spec
task :test => :spec

task :doc => :yard do
  index_file = File.join File.dirname(__FILE__), 'doc/index.html'
  system "open #{index_file}" if RUBY_PLATFORM.include? 'darwin'
  system "xdg-open #{index_file}" if RUBY_PLATFORM.include? 'linux'
end