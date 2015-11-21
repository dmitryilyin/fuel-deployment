$:.unshift File.expand_path('lib', File.dirname(__FILE__))
require 'deployment/version'

Gem::Specification.new do |s|
  s.name = 'deployment'
  s.version = Deployment::VERSION
  s.licenses = 'Apache v2.0'
  s.summary = 'Task deployment engine for Astute'
  s.authors = 'Dmitry Ilyin'
  s.email = 'dilyin@mirantis.com'
  s.homepage = 'http://mirantis.com'

  s.files = Dir.glob %w(lib/*.rb lib/deployment/*.rb)
  s.require_paths = 'lib'
end
