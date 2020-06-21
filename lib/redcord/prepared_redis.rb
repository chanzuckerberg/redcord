# typed: strict
require 'redis'
require 'redcord/server_scripts'

class Redcord::PreparedRedis < Redis
  extend T::Sig
  include Redcord::ServerScripts

  sig { returns(T::Hash[Symbol, String]) }
  def redcord_server_script_shas
    instance_variable_get(:@_redcord_server_script_shas)
  end

  sig { params(shas: T::Hash[Symbol, String]).void }
  def redcord_server_script_shas=(shas)
    instance_variable_set(:@_redcord_server_script_shas, shas)
  end
end
