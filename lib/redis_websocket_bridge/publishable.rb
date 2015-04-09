require 'json'
require 'redis'

# Initially made to be mixed into ActiveRecord with GlobalID::Identification (i.e. > rails 4), but
# will work with any plain old object (just set publish_id).
module RedisWebsocketBridge
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
    end

    # channel name to publish to.
    # override if not using GlobalID::Identification or want to use another value
    def publish_id
      to_global_id.to_s
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
      payload.merge! merge

      if self.class.instance_variable_defined? :@redis_websocket_bridge_callbacks
        # if any of the callbacks return falsey, halt the chain
        continue_chain = self.class.instance_variable_get(:@redis_websocket_bridge_callbacks).all? do |callback|
          !!callback.call(self, payload)
        end

        return unless continue_chain
      end

      unless no_publish
        Publishable.get_redis.publish(payload[:pub_id], payload.to_json)
      end

      payload
    end

  end
end
