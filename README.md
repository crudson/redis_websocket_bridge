# Redis Websocket Bridge

Asynchronous realtime messaging from ruby models to websocket clients.

Perfect for long running or asynchronous task progress notification.

## Components
- module to provide transparent publishing of messages from plain models to redis pubsub channels
- EventMachine subscriber to messages published to redis pubsub channels from models
- EventMachine based websocket server to deliver messages to websocket clients
- javascript asset to easily connect UI to server, register for messages on certain models and receive published messages


## Usage

### Server

The server is EventMachine based and can be run through a shell script or rake task. Running it could be added to any process management framework like Foreman.

```bash
./bin/redis_websocket_bridge

Usage: redis_websocket_bridge [options]
    -v, --verbose
        --port port
    -t, --logtick log tick
    -p, --prefix log prefix
```

The server will listen for any model messages that are published, accept websocket connections and deliver any message published to clients that have asked for them.

Every `logtick` seconds statistics will be printed to the console regarding clients, number of messages sent etc.


### Application

Add to `gem 'redis_websocket_bridge'` to `Gemfile`.

Add the railtie to rails (if using rails) to `config/application.rb`
```ruby
require 'redis_websocket_bridge/railtie'
```
This adds an engine to the application so that gem assets are available.

Include `RedisWebsocketBridge::Publishable` module in models.

```ruby
class SomeModel
  include RedisWebsocketBridge::Publishable
end
```

Messages can now be broadcast by simply calling `publish` on the model with a message. There are other options to customize the payload (see below).

Including this module will add a `publish_id` method to the model, which is how the instance will be identified when passing through a redis pubsub channel and how websocket clients will refer to it.

The value of `publish_id` which will differ depending on what is available on the class. If the class including this module has an `id` method (`ActiveRecord` etc will automatically give this) the `publish_id` will be `ClassName/id`. If the class includes GlobalID with `include GlobalID::Identification`, this will be used as the `publish_id`. This is the recommended way to identify Rails4 models being passed to `active_job` and is a good scheme so is supported. Note that module include order therefore matters; to use GlobalID as publish_id, it must be included first.

If there is no `id` method and GlobalID is not included in the model, the fallback is to use `ClassName/object_id`, which is probably not desired, as a model should be consistently referable across instances.

To broadcast a message simply call:
```ruby
model.publish "Status changed to Ready"
```

Any websocket client that has registered for messages for this model will be notified immediately.

Messages are serialized as JSON in the form:
```json
{
  t: time of message,
  msg: the message string,
  pub_id: model publish_id
}
```
But messages can be customized in any way when calling `publish` on the model.

The publish method is:
```ruby
def publish(msg, no_publish: false, attributes: [], merge: {})
```
- `no_publish` - set to true to not actually publish the message, but callbacks will still be invoked, so this can be used for (for example) logging of the message
- `attributes` - single or array of model attributes that will be automatically added to the message payload.
e.g.
```ruby
model.publish("All records have been processed", attributes: [:updated_at, :status])
```
will result in the message:
```json
{
  t: <current time>,
  msg: "All records have been processed",
  pub_id: "ModelClass/id",
  updated_at: <updated_at>,
  status: <status>
}
```
- `merge` - merge a hash as-is into the payload
e.g.
```ruby
model.publish("Email has been sent", merge: { send_duration: 7, inbox_size: user.inbox.size, pending_emails: emails.pending.count })
```
could result in the message:
```json
{
  t: <current time>,
  msg: "Email has been sent",
  pub_id: "ModelClass/id",
  send_duration: 7,
  inbox_size: 21,
  pending_emails: 5
}
```


Note that publish IDs are additionally (but transparently) namespaced when passing through redis (with a `rwb://` prefix). This is to keep them separate from any other messaging that redis may be doing and the limit what our server is subscribing to to only relevant messages. This prefix is stripped before delivering messages to clients, so only is important if one wishes to generate messages from other sources (which will work fine) or subscribe to these messages outside of the framework.


### Web client

Integration into a web client is easy, highly configurable but can be achieved with minimal setup.

Include the asset.
```
<%= javascript_include_tag 'redis_websocket_bridge' %>
<%= stylesheet_link_tag 'redis_websocket_bridge' %>
```
The stylesheet is optional, and only necessary if minimal out of the box automatic displaying of messages in a page is desired.

Initialize the client and register to receive messages for models:
```javascript
RWB.init({
  addToId: 'publish-messages'
});
RWB.register('SomeClass/id');
```
All websocket connection management will be handled automatically and (in this example) messages will be prepended to the element with id `publish-messages`.

`register()` can accept a single publish ID or an array of them.

The default behavior is to prepend messages to a DOM element with ID `addToId` where each message is represented by:
```html
<div class="rwb">
  <div class="rwb-t">Time</div>
  <div class="rwb-m">Message</div>
</div>
```

There are many options to configure the behavior in the browser, all of which are optional (see `app/assets/javascripts/redis_websocket_bridge.js`), including:

- `url` - the URL of the server (defaults to port 9919 on the host of the current page)

- `onLiveMessage` - a callback function to call whenever a message is received

- `elementFactory` - a function that can convert an incoming message to a DOM element
- `addToId` - a DOM element that messages are added to, or `null` to have no automatic adding of elements. This is the only property that needs to be set to get UI integration without writing any other javascript.
- `addPosition` - either `prepend` or `append`

- `cssClassAttribute` - add CSS class for a message attribute. For example if each message contains a `status` attribute, the value of this can be added to each message div.

- `autoRefresh` - can reload the page (or load another) automatically when a message is received with `{ refresh: true }`
- `refresh` - function invoked with a message to get the new location (defaults to `window.location.origin`)
- `refreshDelay` - seconds to count down when auto refreshing

- `notifications` - whether to display native desktop notifications for "major" messages
- `notificationIcon` - icon to show in native notifications
- `requestNotificationPermission` - whether to automatically negotiate requesting notification permissions with the user

- `sounds` - whether to play a sound for "major" events
- `soundEl` - ID of element to add to page body to play sounds
- `soundPath` - URL of sound to play, defaults to provided asset at `/sounds/msg.ogg`

- `debug` - whether extra messages details are logged to the console
