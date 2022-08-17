# typed: strong
module Redcord
  extend T::Sig

  @@configuration_blks = T.let(
    [],
    T::Array[T.proc.params(arg0: T.untyped).void],
  )

  sig {
    params(
      blk: T.proc.params(arg0: T.untyped).void,
    ).void
  }
  def self.configure(&blk); end

  sig { void }
  def self._after_initialize!; end
end
