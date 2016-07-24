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

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'nokogiri', '~> 1.6'
  spec.add_dependency 'ruby-progressbar', '~> 1.8'
  spec.add_dependency 'gepub', '0.7.0beta3'
  spec.add_dependency 'slop', '~> 4.3'
  spec.add_dependency 'contracts', '~> 0.14'
  spec.add_dependency 'i18n_data', '~> 0.7'
  spec.add_dependency 'fastimage', '~> 1.8'
  spec.add_dependency 'chronic_duration', '~> 0.10'
  spec.add_dependency 'retryable', '~> 2.0'
  spec.add_dependency 'ruby_deep_clone'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.5'
end
