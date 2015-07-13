require File.join(File.dirname(__FILE__), 'lib', 'redis_websocket_bridge', 'version')

Gem::Specification.new do |s|
  s.name = 'redis_websocket_bridge'
  s.version = RedisWebsocketBridge::VERSION
  s.license = 'MIT'
  s.platform = Gem::Platform::RUBY
  s.author = 'Doug Hudson'
  s.email = ['doug.hudson@roosterjuicesoftware.com']
  s.homepage = 'https://github.com/crudson/redis_websocket_bridge'
  s.summary = 'Fast broadcasting of messages from any ruby object to websocket clients (via redis)'
  s.description = 'EventMachine based websocket server that broadcasts redis channel messages to any number of subscribers. Easy integration with any ruby object via module. Provides a rails engine (via railtie) and compiled js and css assets for shortest path integration.'

  s.files = Dir.glob('lib/**/*') +
    Dir.glob('app/**/*') +
    Dir.glob('test/{test_client.rb,example.html,test_model.rb,test_model_with_global_id.rb}')
  s.executables = ['redis_websocket_bridge']
  s.require_paths = ['lib']

  s.add_runtime_dependency 'em-websocket', '~>0.5'
  s.add_runtime_dependency 'em-hiredis', '~>0.3'

  s.add_development_dependency 'minitest', '~>5.6'
  s.add_development_dependency 'faye-websocket', '~>0.9'
  s.add_development_dependency 'globalid', '~>0.3'
#  s.add_development_dependency 'poltergeist'
end
