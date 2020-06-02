# typed: strict
#
# This adds the TTL functionality to RedisRecord.TTL is specified at the model
# level. If it is specified, when saving or updating an object, the TTL will be
# refreshed. A record older than the model's TTL will be deleted by Redis
# automatically.
#
module RedisRecord::TTL
  sig { params(klass: T.any(Module, T.class_of(T::Struct))).void }
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    sig { params(duration: T.nilable(ActiveSupport::Duration)).void }
    def ttl(duration)
      RedisRecord::RedisConnection.procs_to_prepare << Proc.new do |redis|
        if duration.nil?
          redis.set("#{model_key}:ttl", -1)
        else
          redis.set("#{model_key}:ttl", duration)
        end
      end
    end
  end

  mixes_in_class_methods(ClassMethods)
end
