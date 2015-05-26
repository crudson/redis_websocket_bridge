require 'json'
require 'redis'

# Initially made to be mixed into ActiveRecord with GlobalID::Identification (i.e. > rails 4), but
# will work with any plain old object (just set publish_id).
module RedisWebsocketBridge
  class PublishableError < StandardError; end

  module Publishable
    # configuration passed to redis client
    # see https://github.com/redis/redis-rb#getting-started
    def self.config
      @@config ||= { host: "127.0.0.1", port: 6379 }
    end

    def self.configure
      yield config
    end

    def self.get_redis
      @@redis ||= Redis.new(config)
    end

    def self.reconnect
      @@redis = Redis.new(config)
    end

    def self.included(include_class)
      include_class.instance_eval do
        # Provide callback(s) before publishing
        def before_publish(&block)
          @redis_websocket_bridge_callbacks ||= []
          @redis_websocket_bridge_callbacks << block
        end
      end

      # Set default publish_id method (not the value, that is returned by the method)
      # If GlobalID::Identification is mixed into the include class already (it must be before including
      # this module) then use that, otherwise use .id
      # Note that using GlobalID needs GlobalID.app set and an id method on the class (active_record/rails does this).
      #
      # Override publish_id in the class including this module to customize this value to something else.
      include_class.class_eval do
        if defined?(GlobalID::Identification) &&
            included_modules.include?(GlobalID::Identification) &&
            GlobalID.app
          def publish_id
            to_global_id.to_s
          end
        else
          def publish_id
            id_val = self.id
            raise(PublishableError, "No id") unless id_val
            "#{self.class.name}/#{id_val}"
          end
        end
      end

    end

    # attributes are obtained by self[attribute]
    # merge hash is simply merged as-is
    #
    # no_publish is so that callbacks can still be invoked (for logging or other
    #  processing), but the message is never published to redis.
    #
    # returns the payload
    def publish(msg, no_publish: false, attributes: [], merge: {})
      payload = {
        t: Time.now,
        msg: msg,
        pub_id: publish_id
      }

      [*attributes].reduce(payload) { |acc, cur| acc[cur] = self[cur]; acc }

      payload.merge!(merge) if merge

      if self.class.instance_variable_defined? :@redis_websocket_bridge_callbacks
        # if any of the callbacks return falsey, halt the chain
        continue_chain = self.class.instance_variable_get(:@redis_websocket_bridge_callbacks).all? do |callback|
          !!callback.call(self, payload)
        end

        return unless continue_chain
      end

      unless no_publish
        redis_channel = "rwb://#{payload[:pub_id]}"
        Publishable.get_redis.publish(redis_channel, payload.to_json)
      end

      payload
    end

    # Allow publishing without including module
    # Will complain if there is no publish_id
    # To publish anything, use publish_to_channel
    def self.publish(obj, msg)
      raise "not implemented"
    end

    def self.publish_to_channel(channel, msg)
      raise "not implemented"
    end

  end
end
