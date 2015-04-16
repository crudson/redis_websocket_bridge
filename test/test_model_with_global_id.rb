require 'redis_websocket_bridge/publishable'
require 'global_id'

# GlobalID needs an "app"
GlobalID.app = 'Foo'

class TestModelWithGlobalID
  include GlobalID::Identification
  include RedisWebsocketBridge::Publishable

  # An example callback
  before_publish do |instance, msg|
    msg[:foo] = 12345
  end

  attr_accessor :some_attribute

  # GlobalID needs an id
  def id
    '1234567890'
  end

  # mimic accessing attributes ala ActiveModel
  def [](attr)
      self.send attr
  end
end
