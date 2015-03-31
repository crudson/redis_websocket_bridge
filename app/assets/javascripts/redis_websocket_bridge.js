/*
  Minimal client-side integration:
  1) Include this .js
  2) Call RWB.init({ addToId: 'element-id' });
  3) Call RWB.register('channel_name');

  Now whenever a message is published to the channel through any means, it will be pushed here.
 */

var RWB = {
  options: {
    url: 'ws://' + window.location.hostname + ':9919',

    onLiveMessage: null, // callback when message received, passing (msg, el), el = null unless append|prependToId

    elementFactory: function(msg) { return RWB.elementFactory(msg) }, // convert msg to DOM element
    addToId: null, // DOM element with id to auto prepend/append messages to, null to not auto add
                   // This is the only property that needs to be set to get UI integration without writing any other javascript.
    addPosition: 'prepend', // prepend|append

    cssClassAttribute: 'type', // add msg.<cssClassAttribute> as div class if adding automatically

    autoRefresh: true, // invoke refresh() callback when a message is received with { refresh: true }
    refresh: function() { return window.location.origin; }, // function to get new location from if autoRefresh = true
    refreshDelay: 5, // seconds

    notifications: true, // show a notification for "major" events
    notificationIcon: '/images/logo_small.png',
    requestNotificationPermission: true, // automatically take care of negotiating notification permission with user
    notificationPermissionHandler: function() { return RWB.notificationPermissionFactory(); }, // add markup, handle clicks etc to allow user to allow notifications. The default is to add a fixed 

    sounds: true, // play a sound for "major" events
    soundEl: 'rwb-sound', // attach this to body to play sound
    soundPath: '/assets/msg.ogg',

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

  register: function(channels) {
    console.log('RWB.register()');

    channels = [].concat(channels);

    if (!RWB.websocket || RWB.websocket.readyState == WebSocket.CLOSED) {
      RWB.websocket = new WebSocket(RWB.options.url);

      RWB.websocket.onmessage = function(e) {
        if (RWB.options.debug) {
          console.log(e.data);
        }

        var data = $.parseJSON(e.data);
        RWB.addLiveMessage(data);

        if (data.refresh) {
          if (RWB.options.autoRefresh) {
            RWB.websocket.close();

            var secs = RWB.options.refreshDelay;
            var tick = function() {
              RWB.addLiveMessage({ msg: 'reloading in ' + secs + 's' });
              if (--secs > -1) {
                window.setTimeout(tick, 1000);
              } else {
                window.location = window.location.origin + '/searches/';
              }
            };
            tick();
          }
        }
      };

      RWB.websocket.onerror = function(e) {
        RWB.addLiveMessage({ msg: 'ws error:' + e, type: 'error' });
      };

      RWB.websocket.onopen = function() {
        for (var i = 0; i < channels.length; i++) {
          RWB.addLiveMessage({ msg: 'wsb registering gid=' + channels[i] });
          RWB.websocket.send(JSON.stringify({ cmd: 'register', gid: channels[i] }));
        }
      };
    }
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
      if (RWB.options.addPosition == 'append') {
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
          audioEl.setAttribute('src', '/sounds/msg.ogg');
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
