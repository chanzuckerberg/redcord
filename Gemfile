source 'https://rubygems.org'

gemspec

rails_version = ENV["RAILS_VERSION"] || "default"

case rails_version
when "master"
  gem "activesupport", {github: "rails/activesupport"}
  gem "railties", {github: "rails/railties"}
when "5.0"
  gem "activesupport", "~> 5.0.7"
  gem "railties", "~> 5.0.7"
when "5.1"
  gem "activesupport", "~> 5.1.7"
  gem "railties", "~> 5.1.7"
when "5.2"
  gem "activesupport", "~> 5.2.3"
  gem "railties", "~> 5.2.3"
when "6.0"
  gem "activesupport", "~> 6.0.0"
  gem "railties", "~> 6.0.0"
else
  gem "activesupport", "~> 5.2.3"
  gem "railties", "~> 5.2.3"
end
