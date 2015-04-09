require 'rubygems'
require 'bundler/setup'

require 'em-websocket'
require 'em-hiredis'

require 'json'
require 'logger'

module RedisWebsocketBridge
  class Server

    def self.run(port: 9919, log_level: 'info', log_tick: 60 * 5, log_prefix: 'rwb')
      STDOUT.sync = true

      log_progname = "#{log_prefix}.main"
      log_progname_redis = "#{log_prefix}.redis"
      log_progname_websocket = "#{log_prefix}.ws"
      log_progname_stats = "#{log_prefix}.stats"
      @logger = Logger.new STDOUT
      @logger.level = Logger.const_get log_level.upcase

      # keys are redis channel names, typically equal to object.to_global_id.to_s
      # values are arrays of websocket connections to be notified
      %w(INT TERM).each do |signal|
        Signal.trap(signal) do
          EventMachine.stop
        end
      end

      @logger.info(log_progname) { "#{self} VERSION=#{VERSION}" }
      @logger.debug(log_progname) { "port=#{port}" }
      @logger.debug(log_progname) { "log level=#{@logger.level}" }
      @logger.debug(log_progname) { "log tick (seconds)=#{log_tick}" }

      case
      when log_tick <= 0
        @logger.fatal(log_progname) { "invalid log_tick (#{log_tick})" }
        exit 1
      when log_tick < 60
        @logger.warn(log_progname) { "log_tick is small (#{log_tick})" }
      end

      @clients = Hash.new { |h, k| h[k] = [] }
      @global_stats = {
        total_clients: 0,
        ws_received: 0,
        ws_sent: 0
      }

      EventMachine.run do

        # ==================
        # 1 redis subscriber
        # ==================
        redis = EM::Hiredis.connect
        pubsub = redis.pubsub
        pattern = "*"
        pubsub.psubscribe(pattern)
        @logger.info(log_progname_redis) { "subscribing to redis channels with pattern:#{pattern}" }
        pubsub.on(:pmessage) do |key, channel, msg|
          @logger.debug(log_progname_redis) { "pmessage key=#{key} channel=#{channel} msg=#{msg}" }
          @clients[channel].each do |ws|
            @global_stats[:ws_sent] += 1
            ws.stats[:sent] += 1
            ws.send msg
          end
        end

        # ===================
        # 2. Websocket server
        # ===================
        EventMachine::WebSocket.start(host: "0.0.0.0", port: port) do |ws|
          @global_stats[:total_clients] += 1
          @logger.info(log_progname_websocket) { "new WebSocket client ##{@total_clients}: #{ws.inspect}" }
          # per socket stats
          ws.instance_eval do
            @stats = {
              received: 0,
              sent: 0,
              channels: [],
              opened_at: Time.new
            }
            def stats
              @stats
            end
          end

          ws.onopen do
            @logger.debug(log_progname_websocket) { "onopen" }
            ws.stats[:opened_at] = Time.new
            ws.send({ t: Time.now, msg: 'Connected' }.to_json)
          end

          # Handle incoming messages on a websocket
          # All we do here is register which redis channel messages should be bridged to this websocket.
          # TODO: handle patterns: translate to regexp
          ws.onmessage do |msg|
            ws.stats[:received] += 1
            @global_stats[:ws_received] += 1
            @logger.debug(log_progname_websocket) { "onmessage:#{msg.inspect}" }

            data = JSON.parse msg
            case data['cmd']
            when 'register'
              progress_pub_sub_channel = data['gid']
              @logger.info(log_progname_websocket) { "Received subscription for gid=#{progress_pub_sub_channel}" }
              @clients[progress_pub_sub_channel] << ws
              # @logger.info(log_progname_websocket) { "there are now #{@lients.reduce(0) { |acc, cur| acc += cur.length }} clients across #{@clients.length} patterns" }
            end
          end

          ws.onclose do
            @logger.debug(log_progname_websocket) { "closing connection stats=#{ws.stats.inspect}" }
            @clients.delete ws
          end

          ws.onerror do |e|
            @logger.error(log_progname_websocket) { "onerror: #{e.inspect}" }
          end
        end

        # ======================================
        # 3. Periodic tick for stats logging etc
        # ======================================
        EventMachine::PeriodicTimer.new(log_tick) do
          @logger.info(log_progname_stats) { @global_stats.inspect }
        end

      end

    end

  end
end
