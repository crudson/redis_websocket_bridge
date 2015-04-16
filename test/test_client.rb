# Fire up a console websocket client that receives published messages for the TestModel.
#
# Use this to simulate a client from the console, without needing a browser-based client.
#
# That's all this does, it isn't run as part of a test suite.

require 'faye/websocket'
require 'json'

require_relative 'test_model'

EM.run do
  ws = Faye::WebSocket::Client.new('ws://localhost:9919')
  ws.on :open do |event|
    ws.send({ cmd: 'register', pub_id: TestModel.new.publish_id }.to_json)
    EM.next_tick do
      TestModel.new.publish("Test Message 1")
    end
  end

  ws.on :message do |event|
    data = JSON.parse event.data
    p data
  end
end
