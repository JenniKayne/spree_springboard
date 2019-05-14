
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'spree_springboard/version'

Gem::Specification.new do |spec|
  spec.platform = Gem::Platform::RUBY
  spec.name          = 'spree_springboard'
  spec.version       = SpreeSpringboard::VERSION
  spec.authors       = ['Wojtek', 'Paweł Strzałkowski']
  spec.email         = ['wojtek@praesens.co', 'pawel@praesens.co']

  spec.summary       = 'Spree Springboard'
  spec.homepage      = 'http://praesens.co/'
  spec.required_ruby_version = '>= 2.2.7'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.15'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'

  spree_version = '~> 3.3.0'
  spec.add_dependency 'sentry-raven'
  spec.add_dependency 'spree_api',         spree_version
  spec.add_dependency 'spree_backend',     spree_version
  spec.add_dependency 'spree_core',        spree_version
  spec.add_dependency 'spree_frontend',    spree_version
  spec.add_dependency 'springboard-retail', '~> 4.1.1'
end
