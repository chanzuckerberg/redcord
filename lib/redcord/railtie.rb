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
    Redcord::Base.logger = Rails.logger

    config_file = 'config/redcord.yml'

    if File.file?(config_file)
      if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.1.0')
        Redcord::Base.configurations = YAML.load(
          ERB.new(File.read(config_file)).result,
        )
      else
        Redcord::Base.configurations = YAML.load(
          ERB.new(File.read(config_file)).result,
          aliases: true,
        )
      end
    end

    Redcord._after_initialize!
  end
end
