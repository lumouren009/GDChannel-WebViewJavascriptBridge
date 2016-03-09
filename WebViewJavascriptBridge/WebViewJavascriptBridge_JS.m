// This file contains the source for the Javascript side of the
// WebViewJavascriptBridge. It is plaintext, but converted to an NSString
// via some preprocessor tricks.
//
// Previous implementations of WebViewJavascriptBridge loaded the javascript source
// from a resource. This worked fine for app developers, but library developers who
// included the bridge into their library, awkwardly had to ask consumers of their
// library to include the resource, violating their encapsulation. By including the
// Javascript as a string resource, the encapsulation of the library is maintained.

#import "WebViewJavascriptBridge_JS.h"

NSString * GDCJavascriptBus_js() {
	#define __wvjb_js_func__(x) #x

	// BEGIN preprocessorJSCode
	static NSString * preprocessorJSCode = @__wvjb_js_func__(
;(function() {

	if (window.GDCWebViewJavascriptBus) {
//		alert("GDCWebViewJavascriptBus return");
		return;
	}

	var realtime = realtime || {};
	realtime.channel = realtime.channel || {};
	var Bus = realtime.channel.Bus = function() {
		var self = this;
		// attributes
		this.state = realtime.channel.Bus.CONNECTING;
		this.topicPrefix = 'JAVASCRIPT_TOPIC_PREFIX';
		this.handlers = {};
		this.replyHandlers = {};

		// default event handlers
		this.onerror = function (err) {
			try {
				console.error(err);
			} catch (e) {
				// dev tools are disabled so we cannot use console on IE
			}
		};
		this.onopen = null;

		this.send = function(topic, payload, options, replyHandler) {
			sendOrPub(true, false, topic, payload, options, replyHandler);
		};
		this.sendLocal = function(topic, payload, options, replyHandler) {
			sendOrPub(true, true, topic, payload, options, replyHandler);
		};
		this.publish = function(topic, payload, options) {
			sendOrPub(false, false, topic, payload, options, null);
		};
		this.publishLocal = function(topic, payload, options) {
			sendOrPub(false, true, topic, payload, options, null);
		};
		this.subscribe = function(topic, handler) {
			return doSubscribe(false, topic, handler);
		};
		this.subscribeLocal = function(topic, handler) {
			return doSubscribe(true, topic, handler);
		};

		var sendMessageQueue = [];
		this._fetchQueue = function() {
			var messageQueueString = JSON.stringify(sendMessageQueue);
			sendMessageQueue = [];
			return messageQueueString;
		};
		this._handleMessageFromObjC = function(messageJSON) {
			setTimeout(function _timeoutDispatchMessageFromObjC() {
				var message = JSON.parse(messageJSON);
				// define a reply function on the message itself
				var replyTopic = message["replyTopic"];
				if (replyTopic) {
					Object.defineProperty(message, 'reply', {
							value: function (payload, replyHandler) {
								if (message["local"]) {
									self.sendLocal(replyTopic, payload, replyHandler);
								} else {
									self.send(replyTopic, payload, replyHandler);
								}
							}
					});
				}

				var topic = message["topic"];
				if (self.handlers[topic]) {
					// iterate all registered handlers
					var handlers = self.handlers[topic];
					for (var i = 0; i < handlers.length; i++) {
						handlers[i](message);
					}
				} else if (self.replyHandlers[topic]) {
					// Might be a reply message
					var handler = self.replyHandlers[topic];
					delete self.replyHandlers[topic];
					var error = message["error"];
					handler({"failed": error ? ture : false, "cause": error, "result": message});
				} else {
					if (json.type === 'err') {
						self.onerror(message);
					} else {
						try {
							console.warn('No handler found for message: ', message);
						} catch (e) {
							// dev tools are disabled so we cannot use console on IE
						}
					}
				}
			});
		};

		function sendOrPub(send, local, topic, payload, options, replyHandler) {
			checkOpen();
			if (typeof options === 'function') {
				replyHandler = options;
				options = null;
			}

			var msg = {};
			msg["type"] = send ? "send" : "publish";
			msg["topic"] = topic;
			if (send) {
				msg["send"] = true;
			}
			if (local) {
				msg["local"] = true;
			}
			if (payload) {
				msg["payload"] = payload;
			}
			if (options) {
				msg["options"] = options;
			}
			if (send && replyHandler) {
				var replyTopic = makeUUID(topic);
				msg["replyTopic"] = replyTopic;
				self.replyHandlers[replyTopic] = replyHandler;
			}
			_doSend(msg);
		}

		function doSubscribe(local, topic, handler) {
			checkOpen();
			// ensure it is an array
			if (!self.handlers[topic]) {
				self.handlers[topic] = [];
				// First handler for this address so we should register the connection
				var msg = {};
				msg["type"] = "subscribe";
				msg["topic"] = topic;
				if (local) {
					msg["local"] = true;
				}
				_doSend(msg);
			}
			self.handlers[topic].push(handler);

			var unsubscribe = function() {
				checkOpen();
				var handlers = self.handlers[topic];
				if (handlers) {
					var idx = handlers.indexOf(handler);
					if (idx != -1) {
						handlers.splice(idx, 1)
					}
					if (handlers.length == 0) {
						// No more local handlers so we should unregister the connection
						var msg = {};
						msg["type"] = "unsubscribe";
						msg["topic"] = topic;
						if (local) {
							msg["local"] = true;
						}
						_doSend(msg);
						delete self.handlers[topic];
					}
				}
			};
			return {unsubscribe: unsubscribe};
		}
		var messagingIframe = document.createElement('iframe');
		messagingIframe.style.display = 'none';
		messagingIframe.src = 'wvjbscheme://__WVJB_QUEUE_MESSAGE__';

		function _doSend(message, responseCallback) {
			sendMessageQueue.push(message);
			if (!messagingIframe.parentNode) {
				document.documentElement.appendChild(messagingIframe);
			} else {
				messagingIframe.src = messagingIframe.src;
			}
		}

		// are we ready?
		function checkOpen() {
			if (self.state != realtime.channel.Bus.OPEN) {
				throw new Error('GDCWebViewJavascriptBus: INVALID_STATE_ERR');
			}
		}
		function makeUUID(topic) {
			var id = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (a, b) {
				return b = Math.random() * 16, (a == 'y' ? b & 3 | 8 : b | 0).toString(16);
			});
			return "reply/" + id + "/" + topic;
		}

	};

  Bus.CONNECTING = 0;
  Bus.OPEN = 1;
  Bus.CLOSING = 2;
  Bus.CLOSED = 3;
	window.bus = window.GDCWebViewJavascriptBus = new realtime.channel.Bus();
  window.bus.state = Bus.OPEN;


	// 兼容旧接口
	var bridge = {};
	bridge.on = function(topic, callback) {
		return bus.subscribeLocal(bus.topicPrefix + topic, function(message) {
			callback(message.payload);
		});
	};
	bridge.invoke = function(topic, payload, callback) {
		bus.sendLocal(bus.topicPrefix + topic, payload, function(asyncResult) {
			if (asyncResult.failed) {
				callback({"errCode": asyncResult.cause.code, "errMsg": asyncResult.cause, "result": null});
			} else {
				var message = asyncResult.result;
				callback({"errCode": 0, "errMsg": null, "result": message.payload});
			}
		});
	};
	window.TenvideoJSBridge = bridge;
	var readyEventExt = document.createEvent('Events');
	readyEventExt.initEvent('onTenvideoJSBridgeReady');
	readyEventExt.bridge = bridge;
	document.dispatchEvent(readyEventExt);


})();
	); // END preprocessorJSCode

	#undef __wvjb_js_func__
	return preprocessorJSCode;
};