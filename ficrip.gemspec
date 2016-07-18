# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ficrip/version'

Gem::Specification.new do |spec|
  spec.name          = 'ficrip'
  spec.version       = Ficrip::VERSION
  spec.license       = 'MIT'
  spec.summary       = 'A fanfiction.net to EPUB2/3 tool.'
  spec.author        = 'Katherine Whitlock'
  spec.email         = 'toroidalcode@gmail.com'
  spec.homepage      = 'https://github.com/toroidal-code/ficrip'


  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to? :metadata
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'nokogiri', '~> 1.6'
  spec.add_dependency 'ruby-progressbar', '~> 1.8'
  spec.add_dependency 'gepub', '0.7.0beta3'

  spec.add_development_dependency 'bundler', '~> 1.12'
  spec.add_development_dependency 'rake', '~> 11.2'
  spec.add_development_dependency 'rspec', '~> 3.5'
end
