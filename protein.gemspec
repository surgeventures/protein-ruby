lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'protein/version'

Gem::Specification.new do |spec|
  spec.name     = 'protein'
  spec.version  = Protein::VERSION
  spec.authors  = ['Karol Słuszniak']
  spec.email    = 'karol@shedul.com'
  spec.homepage = 'http://github.com/surgeventures/protein-ruby'
  spec.license  = 'MIT'
  spec.platform = Gem::Platform::RUBY

  spec.summary = 'Multi-platform remote procedure call (RPC) system based on Protocol Buffers'

  spec.files            = Dir["lib/**/*.rb"]
  spec.extra_rdoc_files = ["README.md"]
  spec.test_files       = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths    = ["lib"]

  spec.add_runtime_dependency 'bunny', '~> 2.7'
  spec.add_runtime_dependency 'concurrent-ruby', '~> 1.0', '>= 1.0.5'
  spec.add_runtime_dependency 'google-protobuf', '~> 3.0'

  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rack'
  spec.add_development_dependency 'pry'
end
