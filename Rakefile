require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'yard'
require 'ruby-lint/rake_task'

RSpec::Core::RakeTask.new
YARD::Rake::YardocTask.new

RubyLint::RakeTask.new do |task|
  task.name = 'lint'
  task.files = %w(lib)
  task.configuration = 'ruby-lint.yml'
end

task :default => [:spec, :lint]
task :test => :spec

task :doc => :yard do
  index_file = File.join File.dirname(__FILE__), 'doc/index.html'
  system "open #{index_file}" if RUBY_PLATFORM.include? 'darwin'
  system "xdg-open #{index_file}" if RUBY_PLATFORM.include? 'linux'
end
