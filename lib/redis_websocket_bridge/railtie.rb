module RedisWebsocketBridge
  module Rails
    class Engine < ::Rails::Engine
      initializer 'redis_websocket_bridge.assets.precompile' do |app|
        app.config.assets.precompile += %w(redis_websocket_bridge.js redis_websocket_bridge.css rwb-rm-logo.png msg.ogg err.ogg)
      end
    end
  end
end
