require 'redis_websocket_bridge/publishable'

class TestModel
  include ::RedisWebsocketBridge::Publishable

  before_publish do |instance, msg|
    msg[:foo] = 12345
  end

  attr_accessor :some_attribute

  # mimic accessing attributes ala ActiveModel
  def [](attr)
      self.send attr
  end

  def publish_id
    # "ExampleModel/#{object_id}"
    # use a fixed publish id to aid testing
    "ExampleModel/1234567890"
  end
end
