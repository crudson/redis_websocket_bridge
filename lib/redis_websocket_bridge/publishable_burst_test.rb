# Require this to add methods to Publishable instances to allow batches of test messages to be published.
#  require 'redis_websocket_bridge/publishable_burst_test'
module RedisWebsocketBridge
  module Publishable
    def emit_test_burst(n: 200, sleep_scale_factor: 0.2)
      n.times do
        publish (30 + rand(70)).times.reduce([]) { |a, c| a << [*?a..?z].sample }.join
        sleep(rand * sleep_scale_factor)
      end
      publish "done burst test", merge: { major: true }
    end
  end
end
