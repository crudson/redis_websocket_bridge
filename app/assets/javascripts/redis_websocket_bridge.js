/*
  Minimal client-side integration:
  1) Include this .js
  2) Call RWB.init({ addToId: 'element-id' });
  3) Call RWB.register('channel_name');

  Now whenever a message is published to the channel through any means, it will be pushed here.
 */

console.log('RWB load');
var RWB = {
  options: {
    // URL of websocket server
    url: 'ws://' + window.location.hostname + ':9919',

    // callback when message received, passing (msg, el), el = null unless append|prependToId
    onLiveMessage: null,

    // convert msg to DOM element
    elementFactory: function(msg) { return RWB.elementFactory(msg) },

    // DOM element with id to auto prepend/append messages to, null to not auto add
    // This is the only property that needs to be set to get UI integration without writing any other javascript.
    addToId: null,

    // prepend|append
    addPosition: 'prepend',

    // add msg.<cssClassAttribute> as div class if adding automatically
    cssClassAttribute: 'type',

    // invoke refresh() callback when a message is received with { refresh: true }
    autoRefresh: true,

    // function to get new location from if autoRefresh = true
    refreshLocation: function() { return window.location; },

    // seconds
    refreshDelay: 5,

    // show a notification for "major" events
    notifications: true,

    // asset to display as notification icon
    notificationIcon: '/assets/rwb-rm-logo.png',

    // automatically take care of negotiating notification permission with user
    //  notificationPermissionRequester: function() { return RWB.notificationPermissionRequestor(); },
    // add markup, handle clicks etc to allow user to allow notifications. The default is to add a fixed 
    requestNotificationPermission: true,

    // play a sound for "major" events
    sounds: true,

    // attach this to body to play sound
    soundEl: 'rwb-sound',

    // sound asset to play
    soundPath: '/assets/msg.ogg',

    // extra messages printed to console
    debug: true
  },

  websocket: null,

  init: function(options) {
    console.log('RWB.init()');
    for (o in options) {
      RWB.options[o] = options[o];
    }

    if (RWB.options.notifications && RWB.options.requestNotificationPermission) {
      if (window.Notification && Notification.permission !== "granted") {
        Notification.requestPermission(function (status) {
          if (Notification.permission !== status) {
            Notification.permission = status;
          }
        });
      }
    }

  },

  connect: function(cb) {
    if (!RWB.websocket || RWB.websocket.readyState === WebSocket.CLOSED) {
      RWB.websocket = new WebSocket(RWB.options.url);

      RWB.websocket.onmessage = function(e) {
        if (RWB.options.debug) {
          console.log(e.data);
        }

        var data = JSON.parse(e.data);
        RWB.addLiveMessage(data);

        if (data.refresh && RWB.options.autoRefresh) {
          RWB.doRefresh();
        }
      };

      RWB.websocket.onerror = function(e) {
        RWB.addLiveMessage({ msg: 'ws error:' + e, type: 'error' });
      };

      RWB.websocket.onopen = function() {
        if (cb) {
          cb();
        }
      };
    } else {
      if (cb) {
        cb();
      }
    }
  },

  disconnect: function() {
    if (RWB.options.debug) {
      console.log('disconnected');
    }

    RWB.websocket.close();

    RWB.addLiveMessage({ msg: 'disconnected', type: 'disconnect' });
  },

  /*
    register channel(s), connecting websocket if necessary.
    callback cb when done (in case we need to asynchronously ensure the websocket is connected).
  */
  register: function(channels, cb) {
    RWB.connect(function() {
      channels = [].concat(channels);
      for (var i = 0; i < channels.length; i++) {
        if (RWB.options.debug) {
          console.log('registering ' + channels[i]);
        }
        RWB.addLiveMessage({ msg: 'rwb registering channel=' + channels[i] });
        RWB.websocket.send(JSON.stringify({ cmd: 'register', pub_id: channels[i] }));
      }

      if (cb) {
        cb();
      }
    });
  },

  unregister: function(channel) {
  },

  doRefresh: function() {
    RWB.websocket.close();

    var secs = RWB.options.refreshDelay;
    var tick = function() {
      RWB.addLiveMessage({ msg: 'reloading in ' + secs + 's' });
      if (--secs > -1) {
        window.setTimeout(tick, 1000);
      } else {
        window.location = RWB.options.refreshLocation();
      }
    };
    tick();
  },

  elementFactory: function(msg) {
    var el = document.createElement('div');
    el.className = 'rwb';
    if (RWB.options.cssClassAttribute && msg.hasOwnProperty(RWB.options.cssClassAttribute)) {
      el.className = el.className + ' ' + msg[RWB.options.cssClassAttribute];
    }
    var elT = document.createElement('div');
    elT.className = 'rwb-t';
    elT.textContent = msg.t;
    el.appendChild(elT);
    var elM = document.createElement('div');
    elM.className = 'rwb-m';
    elM.textContent = msg.msg;
    el.appendChild(elM);
    return el;
  },

  addLiveMessage: function(msg) {
    var el = null;

    if (RWB.options.addToId) {
      var parent = document.getElementById(RWB.options.addToId);
      el = RWB.options.elementFactory(msg);
      if (RWB.options.addPosition === 'append') {
        parent.appendChild(el);
      } else {
        parent.insertBefore(el, parent.firstChild);
      }
    }

    if (msg.major) {
      el.classList.add('rwb-major');

      if (RWB.options.sounds) {
        var audioEl = document.getElementById(RWB.options.soundEl);
        if (! audioEl) {
          audioEl = document.createElement('audio');
          audioEl.setAttribute('src', RWB.options.soundPath);
          document.body.appendChild(audioEl);
        }
        audioEl.play();
      }

      if (RWB.options.notifications) {
        var notificationOps = {
          body: msg.msg,
          tag: msg.publish_id,
          icon: RWB.options.notificationIcon
        };
        var notification = new Notification('RWB message', notificationOps);
      }

    }

    if (RWB.options.onLiveMessage) {
      RWB.options.onLiveMessage(msg, el);
    }
  }
};
