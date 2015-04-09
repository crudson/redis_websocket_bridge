require 'minitest/autorun'
require 'faye/websocket'
require 'timeout'

require_relative 'test_model'

class ServerTest < Minitest::Test
  def setup
    @test_model = TestModel.new
  end

  def test_register_sends_confirmation
    # TODO: get timeout from config
    Timeout::timeout(2) do
      EM.run do
        ws = Faye::WebSocket::Client.new('ws://localhost:9919')
        ws.on :open do |event|
          ws.send({cmd: 'register', gid: @test_model.publish_id}.to_json)
        end

        ws.on :message do |event|
          data = JSON.parse event.data
          assert_equal 'Connected', data['msg']
          EM.stop
        end
      end
    end
  rescue Timeout::Error
    flunk 'timed out'
  end

  def test_correct_message_received
    Timeout::timeout(5) do
      EM.run do
        ws = Faye::WebSocket::Client.new('ws://localhost:9919')
        ws.on :open do |event|
          ws.send({cmd: 'register', gid: @test_model.publish_id}.to_json)
        end

        ws.on :message do |event|
          data = JSON.parse event.data
          p data
          if data['msg'] == 'Connected'
            p @test_model.publish "Test Message 1"
            p @test_model.publish "Test Message 2"
            p @test_model.publish "Test Message 3"
          end
        end
      end
    end
  rescue Timeout::Error
    flunk 'timed out'
  end
end
