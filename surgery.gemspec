lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'surgery/version'

Gem::Specification.new do |spec|
  spec.name     = 'surgery'
  spec.version  = Surgery::VERSION
  spec.authors  = ['Karol Słuszniak']
  spec.email    = 'karol@shedul.com'
  spec.homepage = 'http://github.com/surgeventures/surgery'
  spec.license  = 'MIT'
  spec.platform = Gem::Platform::RUBY

  spec.summary = 'All Things Ruby @ Surge Ventures Inc, the creators of Shedul.'

  spec.description = "This is the official entry point and hub for all company-wide Ruby efforts at Surge Ventures."

  spec.files            = Dir["lib/**/*.rb"]
  spec.has_rdoc         = false
  spec.extra_rdoc_files = ["README.md"]
  spec.test_files       = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths    = ["lib"]
end
