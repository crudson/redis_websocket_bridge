require_relative 'publishable'

class ExampleModel
  include RedisWebsocketBridge::Publishable

  before_publish do |o|
    o[:callback_attribute] = 'callback attribute'
  end

  def publish_id
    "ExampleModel/#{object_id}"
  end
end
