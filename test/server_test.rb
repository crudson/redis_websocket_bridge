require 'minitest/autorun'

require 'faye/websocket'
require 'timeout'

require_relative 'test_model'

class ServerTest < Minitest::Test
  def setup
    @test_model = TestModel.new
  end

  def test_register_sends_confirmation
    Timeout::timeout(2) do
      EM.run do
        ws = Faye::WebSocket::Client.new('ws://localhost:9919')
        ws.on :open do |event|
          ws.send({ cmd: 'register', pub_id: @test_model.publish_id }.to_json)
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

  def test_correct_messages_received
    messages = [*1..10].map { |i| "Test message ##{i}" }

    Timeout::timeout(2) do
      EM.run do
        ws = Faye::WebSocket::Client.new('ws://localhost:9919')
        ws.on :open do |event|
          ws.send({ cmd: 'register', pub_id: @test_model.publish_id }.to_json)
        end

        ws.on :message do |event|
          data = JSON.parse event.data
          if data['msg'] == 'Connected'
            # server has associated this client with TestModel's pub_id so we will now receive messages for it
            # send out some messages, then check we have been notified of them
            EM.next_tick do
              messages.each { |m| @test_model.publish m }
            end
          else
            assert_equal data['msg'], messages.delete(data['msg'])
            EM.stop if messages.empty?
          end
        end
      end
    end
  rescue Timeout::Error
    flunk 'timed out'
  end

end
