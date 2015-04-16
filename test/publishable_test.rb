require 'minitest/autorun'
require 'global_id'

require_relative 'test_model'

class PublishableTest < Minitest::Test
  def setup
    @test_model = TestModel.new
  end

  def test_configure_yields_hash
    RedisWebsocketBridge::Publishable.configure do |config|
      assert_instance_of Hash, config
    end
  end

  def test_configure
    begin
      # be nice, reset it when we're done
      orig_port = -1
      RedisWebsocketBridge::Publishable.configure do |config|
        orig_port = config[:port]
        config[:port] = 1111
      end
      assert_equal 1111, RedisWebsocketBridge::Publishable.config[:port]
    ensure
      RedisWebsocketBridge::Publishable.configure do |config|
        config[:port] = orig_port
      end
      assert_equal orig_port, RedisWebsocketBridge::Publishable.config[:port]
    end
  end

  # test that reconnect gives a new Redis instance
  def test_reconnect
    redis_1 = RedisWebsocketBridge::Publishable.get_redis
    refute_equal redis_1, RedisWebsocketBridge::Publishable.reconnect
  end

  def test_before_publish_callback
    msg = @test_model.publish 'test'
    # our test model sets foo
    assert_equal msg[:foo], 12345
  end

  def test_publish_sets_msg
    msg = @test_model.publish 'test'
    assert_equal msg[:msg], 'test'
  end

  def test_publish_sets_time
    msg = @test_model.publish 'test'
    refute_nil msg[:t]
    assert_instance_of Time, msg[:t]
  end

  def test_publish_sets_pub_id
    msg = @test_model.publish 'test'
    assert_equal @test_model.publish_id, msg[:pub_id]
  end

  def test_publish_no_publish
    skip 'need to async test'
  end

  def test_publish_single_attributes
    @test_model.some_attribute = 'xyz'
    msg = @test_model.publish 'abcde', attributes: :some_attribute
    assert_equal 'xyz', msg[:some_attribute]
  end

  def test_publish_array_attributes
    @test_model.some_attribute = 'xyz'
    msg = @test_model.publish 'abcde', attributes: [:some_attribute]
    assert_equal 'xyz', msg[:some_attribute]
  end

  def test_merge
    to_merge = { a: 1, b: 'two', c: true }
    msg = @test_model.publish 'abcde', merge: to_merge
    to_merge.each_pair do |key, val|
      assert_equal val, msg[key]
    end
  end

  def test_publish_id_default
    new_class = Class.new do
      include RedisWebsocketBridge::Publishable
    end
    self.class.const_set :TestClass, new_class
    c = new_class.new
    assert_includes c.methods, :publish_id
    assert_equal "#{new_class.name}/#{c.object_id}", c.publish_id
  end

  def test_publish_id_with_id
    new_class = Class.new do
      attr_accessor :id
      include RedisWebsocketBridge::Publishable
    end
    self.class.const_set :TestClass1, new_class
    c = new_class.new
    c.id = '123'
    assert_includes c.methods, :publish_id
    assert_equal "#{new_class.name}/#{c.id}", c.publish_id
  end

  def test_publish_id_with_global_id
    GlobalID.app = 'Foo'
    new_class = Class.new do
      include GlobalID::Identification
      include RedisWebsocketBridge::Publishable
      attr_accessor :id
    end
    self.class.const_set :TestClass2, new_class
    c = new_class.new
    c.id = '123'
    assert_includes c.methods, :publish_id
    assert_equal c.to_global_id.to_s, c.publish_id
  end
end
