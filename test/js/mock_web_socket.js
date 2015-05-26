function MockWebSocket(url) {
  this.readyState = this.CLOSED;
  this.fakeConnect();
};
MockWebSocket.CONNECTING = 0;
MockWebSocket.OPEN = 1;
MockWebSocket.CLOSING = 2;
MockWebSocket.CLOSED = 3;
MockWebSocket.connectDelay = 500; // millisecond wait before we "connect"
MockWebSocket.prototype.fakeConnect = function() {
  var _this = this;
  setTimeout(function() {
    _this.readyState = 1;
    _this.onopen();
  }, MockWebSocket.connectDelay);
};
MockWebSocket.prototype.send = function(s) {
  console.log('send ' + s);
};
MockWebSocket.prototype.generateMessage = function(m) {
  this.onmessage({ data: JSON.stringify({ msg: m }) });
}
window.WebSocket = MockWebSocket;

console.log('window.WebSocket now mocked');
