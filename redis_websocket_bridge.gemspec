require_relative 'lib/redis_websocket_bridge/version'

Gem::Specification.new do |s|
  s.name = 'redis_websocket_bridge'
  s.version = RedisWebsocketBridge::VERSION
  s.platform = Gem::Platform::RUBY
  s.author = 'D Hudson'
  s.email = ['doug.hudson@roosterjuicesoftware.com']
  s.homepage = ''
  s.summary = 'Broadcast redis channel messages to websocket clients'
  s.description = 'EventMachine based websocket server that broadcasts redis channel messages to any number of subscribers'

  s.files = Dir.glob('lib/**')
  s.executables = ['redis_websocket_bridge']
  s.require_paths = ['lib']

  s.add_runtime_dependency 'em-websocket'
  s.add_runtime_dependency 'em-hiredis'
end
