require_relative 'lib/redis_websocket_bridge/version'

Gem::Specification.new do |s|
  s.name = 'redis_websocket_bridge'
  s.version = RedisWebsocketBridge::VERSION
  s.platform = Gem::Platform::RUBY
  s.author = 'Doug Hudson'
  s.email = ['doug.hudson@roosterjuicesoftware.com']
  s.homepage = ''
  s.summary = 'Fast broadcasting of messages from any ruby object to websocket clients (via redis)'
  s.description = 'EventMachine based websocket server that broadcasts redis channel messages to any number of subscribers. Easy integration with any ruby object via module. Provides a rails engine (via railtie) and compiled js and css assets for shortest path integration.'

  s.files = Dir.glob('lib/**')
  s.executables = ['redis_websocket_bridge']
  s.require_paths = ['lib']

  s.add_runtime_dependency 'em-websocket'
  s.add_runtime_dependency 'em-hiredis'

  s.add_development_dependency 'minitest'
  s.add_development_dependency 'faye-websocket'
  s.add_development_dependency 'globalid'
end
