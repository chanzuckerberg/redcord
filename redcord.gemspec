# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name          = 'redcord'
  s.version       = '0.1.0'
  s.date          = '2020-06-01'
  s.summary       = 'A Ruby ORM like Active Record, but for Redis'
  s.authors       = ['Chan Zuckerberg Initiative']
  s.email         = 'opensource@chanzuckerberg.com'
  s.homepage      = 'https://github.com/chanzuckerberg/redis-record'
  s.license       = 'MIT'
  s.require_paths = ['lib']
  s.files         = Dir.glob('lib/**/*')

  s.required_ruby_version = ['>= 2.5.0']

  s.add_dependency 'activesupport', '>= 5'
  s.add_dependency 'railties', '>= 5'
  s.add_dependency 'redis', '~> 4'
  s.add_dependency 'sorbet', '>= 0.4.4704'
  s.add_dependency 'sorbet-coerce', '>= 0.2.7'
  s.add_dependency 'sorbet-runtime', '>= 0.4.4704'
  s.add_dependency 'sorbet-static', '>= 0.4.4704'

  s.add_development_dependency 'codecov'
  s.add_development_dependency 'rspec', '~> 3.2'
  s.add_development_dependency 'simplecov'
end
