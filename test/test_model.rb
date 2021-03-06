require 'redis_websocket_bridge/publishable'

class TestModel
  def id
    "1234567890"
  end

  include RedisWebsocketBridge::Publishable

  # An example callback
  before_publish do |instance, msg|
    msg[:foo] = 12345
  end

  attr_accessor :some_attribute

  # mimic accessing attributes ala ActiveModel
  def [](attr)
      self.send attr
  end
end
