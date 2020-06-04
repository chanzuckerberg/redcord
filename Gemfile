source 'https://rubygems.org'

gemspec

rails_version = ENV["RAILS_VERSION"] || "default"

case rails_version
when "master"
  gem "rails", {github: "rails/rails"}
  gem "bundler", ">= 1.3.0"
when "5.0"
  gem "rails", "~> 5.0.7"
  gem "bundler", ">= 2.0"
when "5.1"
  gem "rails", "~> 5.1.7"
  gem "bundler", ">= 2.0"
when "5.2"
  gem "rails", "~> 5.2.3"
  gem "bundler", ">= 2.0"
when "6.0"
  gem "rails", "~> 6.0.0"
  gem "bundler", ">= 2.0"
else
  gem "rails", "~> 5.2.3"
  gem "bundler", ">= 2.0"
end
