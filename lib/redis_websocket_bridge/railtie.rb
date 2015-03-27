module RedisWebsocketBridge
  module Rails
    class Engine < ::Rails::Engine
      puts 'RedisWebsocketBridge railtie loaded'

      initializer 'redis_websocket_bridge.assets.precompile' do |app|
        puts 'RedisWebsocketBridge assets precompile'
        app.config.assets.precompile += %w(redis_websocket_bridge.js redis_websocket_bridge.css)
      end
    end
  end
end
