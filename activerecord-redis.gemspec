Gem::Specification.new do |s|
  s.name          = %q{activerecord-redis}
  s.version       = "0.0.1"
  s.date          = %q{2020-06-01}
  s.summary       = %q{A Ruby ORM API for Redis}
  s.authors       = ["Chan Zuckerberg Initiative"]
  s.email         = "opensource@chanzuckerberg.com"
  s.homepage      = "https://github.com/FB-PLP/redis-record"
  s.license       = 'MIT'
  s.require_paths = ["lib"]
  s.files         = Dir.glob('lib/**/*')

  s.required_ruby_version = ['>= 2.4.0']

  s.add_dependency 'redis', '~> 4.0'

  s.add_dependency 'sorbet', '>= 0.4.4704'
  s.add_dependency 'sorbet-static', '>= 0.4.4704'

  s.add_runtime_dependency 'sorbet-runtime', '>= 0.4.4704'

end
