console.log('Starting');

var page = require('webpage').create();

page.onConsoleMessage = function(s) {
  console.log(s);
};

page.onResourceRequested = function (request) {
  console.log('Request ' + JSON.stringify(request, undefined, 2));
};

// injectJs
// <script src="../../bower_components/mock-socket/dist/mock-socket.js"></script>

page.onLoadFinished = function() {
  console.log('loaded');
  page.evaluate(function() {
    console.log('evaluate');

    WebSocket.connectDelay = 100;

    var onLiveMessage = function(msg, el) {
      console.log('onLiveMessage', JSON.stringify(msg));
    };

    RWB.init({
      url: 'ws://localhost:9919',
      debug: true,
      onLiveMessage: onLiveMessage
    });

    RWB.register('gid://TestApp/TestModel/12345', function() {
      console.log('CONNECTED');
      console.log(JSON.stringify(RWB.websocket));
      RWB.websocket.generateMessage({ foo: 'bar' });
    });

  });

  setTimeout(function() {
    phantom.exit();
  }, 3000);
};

page.open('test/js/blank.html');
