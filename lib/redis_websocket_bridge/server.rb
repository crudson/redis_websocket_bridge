require 'rubygems'
require 'bundler/setup'

require 'em-websocket'
require 'em-hiredis'

require 'json'
require 'logger'

module RedisWebsocketBridge
  class Server
    def self.run(port: 9919, verbose: false)
      STDOUT.sync = true

      # keys are redis channel names, typically equal to object.to_global_id.to_s
      # values are arrays of websocket connections to be notified
      %w(INT TERM).each do |signal|
        Signal.trap(signal) do
          EventMachine.stop
        end
      end

      @logger = Logger.new STDOUT
      if verbose
        @logger.level = Logger::DEBUG
      else
        @logger.level = Logger::INFO
      end

      @logger.info "#{self} VERSION=#{VERSION}"
      @logger.debug "port=#{port}"
      @logger.debug "verbose=#{verbose}"

      @clients = Hash.new { |h, k| h[k] = [] }
      @global_stats = {
        total_clients: 0,
        received: 0,
        sent: 0
      }

      @logger.info "booting..."
      EventMachine.run do
        redis = EM::Hiredis.connect
        pubsub = redis.pubsub
        pattern = "*"
        pubsub.psubscribe(pattern)
        @logger.info "subscribing to redis channels with pattern:#{pattern}"

        pubsub.on(:pmessage) do |key, channel, msg|
          @logger.debug "pmessage key=#{key} channel=#{channel} msg=#{msg}"
          @clients[channel].each do |c|
            @global_stats[:sent] += 1
            c.send msg
          end
        end

        EventMachine::WebSocket.start(host: "0.0.0.0", port: port) do |ws|
          @global_stats[:total_clients] += 1

          @logger.info "new WebSocket client ##{@total_clients}: #{ws.inspect}"

          # Also track outgoing messages
          # duration of connection
          # other meta/stats?
          ws.instance_variable_set(:@stats, {
            received: 0,
            sent: 0,
            created_at: Time.new,
            opened_at: nil,
            last_sent_at: nil
          })

          ws.onopen do
            @logger.debug "onopen"
            ws.instance_variable_get(:@stats)[:opened_at] = Time.new
            ws.send({ t: Time.now, msg: 'Connected' }.to_json)
          end

          # Handle incoming messages on a websocket
          # All we do here is register which redis channel messages should be bridged to this websocket.
          # TODO: handle patterns: translate to regexp
          ws.onmessage do |msg|
            ws.instance_variable_get(:@stats)[:received] += 1
            @global_stats[:received] += 1
            @logger.debug "onmessage:#{msg.inspect}"

            data = JSON.parse msg
            case data['cmd']
            when 'register'
              progress_pub_sub_channel = data['gid']
              puts "Received subscription for gid=#{progress_pub_sub_channel}"
              @clients[progress_pub_sub_channel] << ws
              # @logger.info "there are now #{@lients.reduce(0) { |acc, cur| acc += cur.length }} clients across #{@clients.length} patterns"
            end
          end

          ws.onclose do
            @logger.debug "onclose: #{@msg_count} messages on this connection were received."
            @clients.delete ws
          end

          ws.onerror do |e|
            @logger.error "onerror: #{e.inspect}"
          end
        end
      end

    end
  end
end
