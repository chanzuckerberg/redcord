# typed: strict
require 'rails'
class RedisRecord::Railtie < Rails::Railtie
  railtie_name 'yarr'

  rake_tasks do
    path = File.expand_path(T.must(__dir__))
    Dir.glob("#{path}/tasks/**/*.rake").each { |f| load f }
  end
end