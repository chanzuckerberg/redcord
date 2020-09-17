# frozen_string_literal: true

# typed: strict

require 'rails'
require 'yaml'

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

  config.after_initialize do
    config_file = 'config/redcord.yml'

    if File.file?(config_file)
      Redcord::Base.configurations = YAML.load(
        ERB.new(File.read(config_file)).result
      )
    end

    Redcord::PreparedRedis.load_server_scripts!
  end
end
