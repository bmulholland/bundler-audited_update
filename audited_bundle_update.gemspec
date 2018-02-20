Gem::Specification.new do |s|
  s.name        = 'audited_bundle_update'
  s.version     = '0.0.0'
  s.date        = '2018-02-20'
  s.summary     = "Audited Bundle Update"
  s.description = "Bunlde update with audited output"
  s.authors     = ["Brendan Mulholland"]
  s.email       = "audited_bundle_update@bmulholland.ca"
  s.files       = ["lib/audited_bundle_update.rb"]
  #s.homepage    = 'http://rubygems.org/gems/hola'
  s.license       = 'MIT'
  s.add_runtime_dependency 'bundler'
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'versionomy'
end
