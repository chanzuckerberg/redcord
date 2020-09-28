# frozen_string_literal: true

# typed: strict

require 'sorbet-coerce'

require 'redcord/relation'

module Redcord
  # Raised by Model.find
  class RecordNotFound < StandardError; end
end

module Redcord::Actions
  extend T::Sig
  extend T::Helpers

  sig { params(klass: T.class_of(T::Struct)).void }
  def self.included(klass)
    klass.extend(ClassMethods)
    klass.include(InstanceMethods)
  end

  module ClassMethods
    extend T::Sig

    sig { params(args: T::Hash[Symbol, T.untyped]).returns(T.untyped) }
    def create!(args)
      Redcord::Base.trace(
       'redcord_actions_class_methods_create!',
        model_name: name,
      ) do
        args[:created_at] = args[:updated_at] = Time.zone.now
        instance = TypeCoerce[self].new.from(args)
        id = redis.create_hash_returning_id(model_key, to_redis_hash(args))
        instance.send(:id=, id)
        instance
      end
    end

    sig { params(id: T.untyped).returns(T.untyped) }
    def find(id)
      Redcord::Base.trace(
       'redcord_actions_class_methods_find',
        model_name: name,
      ) do
        instance_key = "#{model_key}:id:#{id}"
        args = redis.hgetall(instance_key)
        if args.empty?
          raise Redcord::RecordNotFound, "Couldn't find #{name} with 'id'=#{id}"
        end

        coerce_and_set_id(args, id)
      end
    end

    sig { params(args: T::Hash[Symbol, T.untyped]).returns(T.untyped) }
    def find_by(args)
      Redcord::Base.trace(
       'redcord_actions_class_methods_find_by_args',
        model_name: name,
      ) do
        where(args).to_a.first
      end
    end

    sig { params(args: T::Hash[Symbol, T.untyped]).returns(Redcord::Relation) }
    def where(args)
      Redcord::Relation.new(T.let(self, T.untyped)).where(args)
    end

    sig { params(id: T.untyped).returns(T::Boolean) }
    def destroy(id)
      Redcord::Base.trace(
       'redcord_actions_class_methods_destroy',
        model_name: name,
      ) do
        redis.delete_hash(model_key, id) == 1
      end
    end
  end

  module InstanceMethods
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { abstract.returns(T.nilable(ActiveSupport::TimeWithZone)) }
    def created_at; end

    sig {
      abstract.params(
        time: ActiveSupport::TimeWithZone,
      ).returns(T.nilable(ActiveSupport::TimeWithZone))
    }
    def created_at=(time); end

    sig { abstract.returns(T.nilable(ActiveSupport::TimeWithZone)) }
    def updated_at; end

    sig {
      abstract.params(
        time: ActiveSupport::TimeWithZone,
      ).returns(T.nilable(ActiveSupport::TimeWithZone))
    }
    def updated_at=(time); end

    sig { void }
    def save!
      Redcord::Base.trace(
       'redcord_actions_instance_methods_save!',
        model_name: self.class.name,
      ) do
        self.updated_at = Time.zone.now
        _id = id
        if _id.nil?
          self.created_at = T.must(self.updated_at)
          _id = redis.create_hash_returning_id(
            self.class.model_key,
            self.class.to_redis_hash(serialize),
          )
          send(:id=, _id)
        else
          redis.update_hash(
            self.class.model_key,
            _id,
            self.class.to_redis_hash(serialize),
          )
        end
      end
    end

    sig { params(args: T::Hash[Symbol, T.untyped]).void }
    def update!(args = {})
      Redcord::Base.trace(
       'redcord_actions_instance_methods_update!',
        model_name: self.class.name,
      ) do
        _id = id
        if _id.nil?
          _set_args!(args)
          save!
        else
          args[:updated_at] = Time.zone.now
          _set_args!(args)
          redis.update_hash(
            self.class.model_key,
            _id,
            self.class.to_redis_hash(args),
          )
        end
      end
    end

    sig { returns(T::Boolean) }
    def destroy
      Redcord::Base.trace(
       'redcord_actions_instance_methods_destroy',
        model_name: self.class.name,
      ) do
        return false if id.nil?

        self.class.destroy(T.must(id))
      end
    end

    sig { returns(String) }
    def instance_key
      "#{self.class.model_key}:id:#{T.must(id)}"
    end

    sig { params(args: T::Hash[Symbol, T.untyped]).void }
    def _set_args!(args)
      args.each do |key, value|
        send(:"#{key}=", value)
      end
    end

    sig { returns(T.nilable(String)) }
    def id
      instance_variable_get(:@_id)
    end

    private

    sig { params(id: String).returns(String) }
    def id=(id)
      instance_variable_set(:@_id, id)
    end
  end

  mixes_in_class_methods(ClassMethods)
end
