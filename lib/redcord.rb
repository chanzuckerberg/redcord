# frozen_string_literal: true

# typed: true

require 'sorbet-runtime'

module Redcord
  extend T::Sig

  @@configuration_blks = []

  def self.configure(&blk)
    @@configuration_blks << blk
  end

  def self._after_initialize!
    @@configuration_blks.each do |blk|
      blk.call(Redcord::Base)
    end

    @@configuration_blks.clear
  end
end

require 'redcord/base'
require 'redcord/migration'
require 'redcord/migration/migrator'
require 'redcord/migration/version'
require 'redcord/railtie'
require 'redcord/vacuum_helper'
