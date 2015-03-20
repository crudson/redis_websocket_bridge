require 'json'
require 'redis'

# Really designed to be mixed into ActiveRecord with GlobalID::Identification (i.e. > 4), but
# will work with any previous version or any plain old object (just set publish_id).
module RedisWebsocketBridge
  module Publishable
    def self.included(include_class)
      $redis ||= Redis.new

      include_class.instance_eval do
        # Provide callback(s) before publishing
        def before_publish(&block)
          puts "RedisWebsocketBridge::Publishable before_publish hook register"
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

    # attributes are added to data.instance JSON attribute.
    # add_to_instance: precalculated values to add to instance after standard and "attributes"
    # extra is added to base data object. can signal behavior at this stage or to a client
    def publish(msg, no_publish: false, attributes: [], merge: {})
      unless no_publish
        data = {
          t: Time.now,
          msg: msg,
          pub_id: publish_id
        }

        attributes.reduce(data) { |acc, cur| acc[cur] = self[cur]; acc }
        data.merge! merge

        if self.class.instance_variable_defined? :@redis_websocket_bridge_callbacks
          # if any of the callbacks return falsey, halt the chain
          continue_chain = self.class.instance_variable_get(:@redis_websocket_bridge_callbacks).all? do |callback|
            !!callback.call(self, data)
          end

          return unless continue_chain
        end

        $redis.publish(data[:pub_id], data.to_json)
      end
    end

  end
end
