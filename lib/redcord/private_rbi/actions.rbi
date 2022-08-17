# typed: true
module Redcord::Actions
  extend T::Sig
  extend T::Helpers

  sig { params(klass: T.class_of(T::Struct)).void }
  def self.included(klass)
  end

  module ClassMethods
    extend T::Sig

    sig { returns(Integer) }
    def count
    end

    sig { params(args: T::Hash[Symbol, T.untyped]).returns(T.untyped) }
    def create!(args)
    end

    sig { params(id: T.untyped).returns(T.untyped) }
    def find(id)
    end

    sig { params(args: T::Hash[Symbol, T.untyped]).returns(T.untyped) }
    def find_by(args)
    end

    sig { params(args: T::Hash[Symbol, T.untyped]).returns(Redcord::Relation) }
    def where(args)
    end

    sig { params(id: T.untyped).returns(T::Boolean) }
    def destroy(id)
    end
  end

  module InstanceMethods
    extend T::Sig
    extend T::Helpers

    sig { returns(T.nilable(ActiveSupport::TimeWithZone)) }
    def created_at; end

    sig {
      params(
        time: ActiveSupport::TimeWithZone,
      ).returns(T.nilable(ActiveSupport::TimeWithZone))
    }
    def created_at=(time); end

    sig { returns(T.nilable(ActiveSupport::TimeWithZone)) }
    def updated_at; end

    sig {
      params(
        time: ActiveSupport::TimeWithZone,
      ).returns(T.nilable(ActiveSupport::TimeWithZone))
    }
    def updated_at=(time); end

    sig { void }
    def save!
    end

    sig { returns(T::Boolean) }
    def save
    end

    sig { params(args: T::Hash[Symbol, T.untyped]).void }
    def update!(args)
    end

    sig { params(args: T::Hash[Symbol, T.untyped]).returns(T::Boolean) }
    def update(args)
    end

    sig { returns(T::Boolean) }
    def destroy
    end

    sig { returns(String) }
    def instance_key
    end

    sig { params(args: T::Hash[Symbol, T.untyped]).void }
    def _set_args!(args)
    end

    sig { returns(T.nilable(String)) }
    def id
    end

    private

    sig { params(id: String).returns(String) }
    def id=(id)
    end
  end
end

module Redcord::Base
  extend Redcord::Actions::ClassMethods

  include Redcord::Actions::InstanceMethods
end
