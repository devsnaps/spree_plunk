# encoding: UTF-8
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'spree_plunk/version'

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'spree_plunk'
  s.version = SpreePlunk::VERSION
  s.summary = 'Spree Commerce integration for Plunk contact sync and event tracking'
  s.required_ruby_version = '>= 3.0'

  s.author = 'spree_plunk contributors'
  s.email = 'maintainers@example.com'
  s.homepage = 'https://example.com/spree_plunk'
  s.license = 'MIT'

  s.metadata = {
    'bug_tracker_uri' => 'https://example.com/spree_plunk/issues',
    'changelog_uri' => "https://example.com/spree_plunk/releases/v#{s.version}",
    'documentation_uri' => 'https://docs.spreecommerce.org/',
    'source_code_uri' => "https://example.com/spree_plunk/tree/v#{s.version}"
  }

  s.files = Dir['{app,config,db,lib,script,vendor}/**/*', 'Rakefile', 'README.md'].reject do |file|
    file.match(/^spec/) && !file.match(/^spec\/fixtures/)
  end
  s.require_path = 'lib'
  s.requirements << 'none'

  spree_opts = '>= 5.3.0'
  s.add_dependency 'spree', spree_opts
  s.add_dependency 'spree_admin', spree_opts

  s.add_development_dependency 'dotenv'
  s.add_development_dependency 'rubocop-rspec'
  s.add_development_dependency 'spree_dev_tools'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'i18n-tasks'
end
