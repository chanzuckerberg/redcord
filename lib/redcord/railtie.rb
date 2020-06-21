# typed: strict
require 'rails'

class Redcord::Railtie < Rails::Railtie
  railtie_name 'redcord'

  rake_tasks do
    path = File.expand_path(T.must(__dir__))
    Dir.glob("#{path}/tasks/**/*.rake").each { |f| load f }
  end

  # Load necessary dependency to configure redcord
  config.before_configuration do
    require 'redcord/base'
  end
end
