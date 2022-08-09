# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'bundler-audited_update'
  s.version     = '0.2.0'
  s.summary     = 'Streamlined bundler audit with Changelog detection and summary ouput'
  s.description = 'Runs a bundle upgrade, shows the changelog for each gem that was upgraded, and outputs a summary view of gem changes plus their impact.'
  s.authors     = ['Brendan Mulholland']
  s.email       = 'audited_bundle_update@bmulholland.ca'
  s.bindir      = 'bin'
  s.files       = ['lib/bundler/audited_update.rb']
  s.executables << 'audited_bundle_update'
  s.homepage    = 'http://rubygems.org/gems/bundler-audited_update'
  s.license     = 'MIT'
  s.add_runtime_dependency 'bundler'
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'launchy'
  s.add_runtime_dependency 'versionomy'
  s.metadata['rubygems_mfa_required'] = 'true'
end
