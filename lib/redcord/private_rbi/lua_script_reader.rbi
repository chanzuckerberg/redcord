# typed: true

module Redcord::LuaScriptReader
  sig { params(script_name: String).returns(String) }
  def self.read_lua_script(script_name)
  end

  sig { params(relative_path: String).returns(String) }
  def self.include_lua(relative_path)
  end
end
