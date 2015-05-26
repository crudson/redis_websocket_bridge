require 'rubygems'
require 'bundler/setup'

require 'em-websocket'
require 'em-hiredis'

require 'json'
require 'logger'

module RedisWebsocketBridge
  WSStats = Struct.new(:received, :sent, :channels, :opened_at)

  class Server

    def initialize(port: 9919, log_level: 'info', log_tick: 60 * 5, log_prefix: 'rwb')
      @port = port

      @log_prefix = log_prefix
      @logger = Logger.new STDOUT
      @logger.level = Logger.const_get log_level.upcase
      @logger.info("#{@log_prefix}.main") { "#{self} VERSION=#{VERSION}" }
      @logger.debug("#{@log_prefix}.main") { "port=#{port}" }
      @logger.debug("#{@log_prefix}.main") { "log level=#{@logger.level}" }
      @logger.debug("#{@log_prefix}.main") { "log tick (seconds)=#{log_tick}" }

      @log_tick = log_tick
      case
      when @log_tick <= 0
        @logger.fatal("#{@log_prefix}.main") { "invalid log_tick (#{@log_tick})" }
        exit 1
      when @log_tick < 60
        @logger.warn("#{@log_prefix}.main") { "log_tick is small (#{@log_tick})" }
      end

      # keys are redis channel names (minus the rwb:// prefix), typically equal to
      # object.to_global_id.to_s
      # values are arrays of websocket connections to be notified
      @clients = {} # Hash.new { |h, k| h[k] = [] }

      vars = %i(total_clients redis_received ws_received ws_sent)
      @global_stats = Struct.new('RWBStats', *vars).new(*([0] * vars.length))
    end

    def on_hiredis_pmessage(key, channel, msg)
      pub_id = channel.sub(/\Arwb:\/\//, '')
      @logger.debug("#{@log_prefix}.redis") { "pmessage key=#{key} channel=#{channel} pub_id=#{pub_id} msg=#{msg}" }
      @global_stats.redis_received += 1
      if @clients.key? pub_id
        @clients[pub_id].each do |ws|
          @global_stats.ws_sent += 1
          ws.stats.sent += 1
          ws.send msg
        end
      end
    end

    def on_websocket_connect(ws)
      @global_stats.total_clients += 1
      @logger.info("#{@log_prefix}.ws") { "new WebSocket client ##{@total_clients}: #{ws.inspect}" }

      ws.instance_eval do
        @stats = WSStats.new(0, 0, [], Time.new)

        def stats
          @stats
        end
      end

      ws.onopen do
        @logger.debug("#{@log_prefix}.ws") { "onopen" }
        ws.stats.opened_at = Time.new
        ws.send({ t: Time.now, msg: 'Connected' }.to_json)
      end

      # Handle incoming messages on a websocket
      # All we do here is register which redis channel messages should be bridged to this websocket.
      ws.onmessage do |msg|
        ws.stats.received += 1
        @global_stats.ws_received += 1
        @logger.debug("#{@log_prefix}.ws") { "onmessage:#{msg.inspect}" }

        data = JSON.parse msg
        case data['cmd']
        when 'register'
          progress_pub_sub_channel = data['pub_id']
          @logger.info("#{@log_prefix}.ws") { "Received subscription for pub_id=#{progress_pub_sub_channel}" }
          @clients[progress_pub_sub_channel] ||= Set.new
          @clients[progress_pub_sub_channel] << ws
          # @logger.info(log_progname_websocket) {
          #   "there are now #{@lients.reduce(0) { |acc, cur| acc += cur.length }} clients across #{@clients.length} patterns"
          # }
        end
      end

      ws.onclose do
        @logger.debug("#{@log_prefix}.ws") { "closing connection stats=#{ws.stats.inspect}" }
        @clients.each_pair do |key, clients|
          if clients.include? ws
            clients.delete ws
          end
        end
        @clients.delete_if { |key, value| value.empty? }
      end

      ws.onerror do |e|
        @logger.error("#{@log_prefix}.ws") { "onerror: #{e.inspect}" }
      end
    end

    def on_log_tick
      # TODO: option to only print stats if unchanged since last log
      @logger.info("#{@log_prefix}.stats") { @global_stats.inspect }
      # @logger.debug("#{@log_prefix}.stats") { @clients.keys.inspect }
    end

    # Kicks off server loop and reactor components.
    # Does not return until server stopped.
    def run!
      %w(INT TERM).each do |signal|
        Signal.trap(signal) do
          EventMachine.stop
        end
      end

      EventMachine.run do
        # 1 redis subscriber
        redis = EM::Hiredis.connect
        pubsub = redis.pubsub
        pattern = "rwb://*"
        @logger.info(@log_progname_redis) { "subscribing to redis channels with pattern:#{pattern}" }
        pubsub.psubscribe(pattern)
        pubsub.on(:pmessage, &method(:on_hiredis_pmessage))

        # 2. Websocket server
        EventMachine::WebSocket.start(host: "0.0.0.0", port: @port, &method(:on_websocket_connect))

        # 3. Periodic tick for stats logging etc
        EventMachine::PeriodicTimer.new(@log_tick, &method(:on_log_tick))
      end
    end

  end
end
