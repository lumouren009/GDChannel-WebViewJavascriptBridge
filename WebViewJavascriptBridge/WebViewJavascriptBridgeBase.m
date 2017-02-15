//
//  WebViewJavascriptBridgeBase.m
//
//  Created by @LokiMeyburg on 10/15/14.
//  Copyright (c) 2014 @LokiMeyburg. All rights reserved.
//

#import "WebViewJavascriptBridgeBase.h"
#import "WebViewJavascriptBridge_JS.h"
#import "GDCBus.h"
#import "GDCMessageImpl.h"
#import "GDCBusProvider.h"

@implementation WebViewJavascriptBridgeBase {
    id _webViewDelegate;
    long _uniqueId;
    NSMutableDictionary *_consumers;
}

static bool logging = false;
static int logMaxLength = 500;

+ (void)enableLogging { logging = true; }
+ (void)setLogMaxLength:(int)length { logMaxLength = length;}

-(id)init {
    self = [super init];
    self.startupMessageQueue = [NSMutableArray array];
    _uniqueId = 0;
    _consumers = [NSMutableDictionary dictionary];
    return(self);
}

- (void)dealloc {
    self.startupMessageQueue = nil;
    for (NSString *topic in _consumers) {
        id<GDCMessageConsumer> consumer = _consumers[topic];
        [consumer unsubscribe];
    }
}

- (void)reset {
    self.startupMessageQueue = [NSMutableArray array];
    _uniqueId = 0;
    _consumers = [NSMutableDictionary dictionary];
}

- (void)flushMessageQueue:(NSString *)messageQueueString {
    if (messageQueueString == nil || messageQueueString.length == 0) {
        NSLog(@"GDCWebViewJavascriptBus: WARNING: ObjC got nil while fetching the message queue JSON from webview. This can happen if the WebViewJavascriptBridge JS is not currently present in the webview, e.g if the webview just loaded a new page.");
        return;
    }

    id messages = [self _deserializeMessageJSON:messageQueueString];
    for (WVJBMessage* message in messages) {
        if (![message isKindOfClass:[WVJBMessage class]]) {
            NSLog(@"GDCWebViewJavascriptBus: WARNING: Invalid %@ received: %@", [message class], message);
            continue;
        }
        [self _log:@"RCVD" json:message];

        __weak WebViewJavascriptBridgeBase *weakSelf = self;
        NSString *type = message[@"type"];
        NSString *topic = message[@"topic"];
        BOOL local = [message[@"local"] boolValue];
        if ([@"send" isEqualToString:type]) {
            GDCAsyncResultBlock replyHandler = nil;
            if (message[@"replyTopic"]) {
                replyHandler = ^(id <GDCAsyncResult> asyncResult) {
                    GDCMessageImpl *msg = asyncResult.result;
                    msg.topic = message[@"replyTopic"];
                    [weakSelf _queueMessage:[msg toJsonWithTopic:YES]];
                };
            }
            if (local) {
                [self.bus sendLocal:topic payload:message[@"payload"] options:message[@"options"] replyHandler:replyHandler];
            } else {
                [self.bus send:topic payload:message[@"payload"] options:message[@"options"] replyHandler:replyHandler];
            }
        } else if ([@"publish" isEqualToString:type]) {
            if (local) {
                [self.bus publishLocal:topic payload:message[@"payload"] options:message[@"options"]];
            } else {
                [self.bus publish:topic payload:message[@"payload"] options:message[@"options"]];
            }
        } else if ([@"subscribe" isEqualToString:type]) {
            void (^handler)(id <GDCMessage>) = ^(id <GDCMessage> message) {
                GDCMessageImpl *msg = message;
                [weakSelf _queueMessage:[msg toJsonWithTopic:YES]];
            };
            if (local) {
                _consumers[topic] = [self.bus subscribeLocal:topic handler:handler];
            } else {
                _consumers[topic] = [self.bus subscribe:topic handler:handler];
            }
        } else if ([@"unsubscribe" isEqualToString:type]) {
            id<GDCMessageConsumer> consumer = _consumers[topic];
            [consumer unsubscribe];
            [_consumers removeObjectForKey:topic];
        }
    }
}

- (void)injectJavascriptFile {
    NSString *js = GDCJavascriptBus_js();
    js = [js stringByReplacingOccurrencesOfString:@"JAVASCRIPT_TOPIC_PREFIX" withString:[NSString stringWithFormat:@"/%@/", kJsBridgeTopicPrefix]];
    js = [js stringByReplacingOccurrencesOfString:@"JAVASCRIPT_CID" withString:GDCBusProvider.clientId];
    [self _evaluateJavascript:js];
    if (self.startupMessageQueue) {
        NSArray* queue = self.startupMessageQueue;
        self.startupMessageQueue = nil;
        for (id queuedMessage in queue) {
            [self _dispatchMessage:queuedMessage];
        }
    }
}

-(BOOL)isCorrectProcotocolScheme:(NSURL*)url {
    if([[url scheme] isEqualToString:kCustomProtocolScheme]){
        return YES;
    } else {
        return NO;
    }
}

-(BOOL)isQueueMessageURL:(NSURL*)url {
    if([[url host] isEqualToString:kQueueHasMessage]){
        return YES;
    } else {
        return NO;
    }
}

-(BOOL)isBridgeLoadedURL:(NSURL*)url {
    return ([[url scheme] isEqualToString:kCustomProtocolScheme] && [[url host] isEqualToString:kBridgeLoaded]);
}

-(void)logUnkownMessage:(NSURL*)url {
    NSLog(@"WebViewJavascriptBridge: WARNING: Received unknown WebViewJavascriptBridge command %@://%@", kCustomProtocolScheme, [url path]);
}

-(NSString *)webViewJavascriptCheckCommand {
    return @"typeof GDCWebViewJavascriptBus == \'object\';";
}

-(NSString *)webViewJavascriptFetchQueyCommand {
    return @"GDCWebViewJavascriptBus._fetchQueue();";
}

// Private
// -------------------------------------------

- (void) _evaluateJavascript:(NSString *)javascriptCommand {
    [self.delegate _evaluateJavascript:javascriptCommand];
}

- (void)_queueMessage:(WVJBMessage*)message {
    if (self.startupMessageQueue) {
        [self.startupMessageQueue addObject:message];
    } else {
        [self _dispatchMessage:message];
    }
}

- (void)_dispatchMessage:(WVJBMessage*)message {
    NSString *messageJSON = [self _serializeMessage:message pretty:NO];
    [self _log:@"SEND" json:messageJSON];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\f" withString:@"\\f"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];

    NSString* javascriptCommand = [NSString stringWithFormat:@"GDCWebViewJavascriptBus._handleMessageFromObjC('%@');", messageJSON];
    if ([[NSThread currentThread] isMainThread]) {
        [self _evaluateJavascript:javascriptCommand];

    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self _evaluateJavascript:javascriptCommand];
        });
    }
}

- (NSString *)_serializeMessage:(id)message pretty:(BOOL)pretty{
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:message options:(NSJSONWritingOptions)(pretty ? NSJSONWritingPrettyPrinted : 0) error:nil] encoding:NSUTF8StringEncoding];
}

- (NSArray*)_deserializeMessageJSON:(NSString *)messageJSON {
    return [NSJSONSerialization JSONObjectWithData:[messageJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
}

- (void)_log:(NSString *)action json:(id)json {
    if (!logging) { return; }
    if (![json isKindOfClass:[NSString class]]) {
        json = [self _serializeMessage:json pretty:YES];
    }
    if ([json length] > logMaxLength) {
        NSLog(@"WVJB %@: %@ [...]", action, [json substringToIndex:logMaxLength]);
    } else {
        NSLog(@"WVJB %@: %@", action, json);
    }
}

@end
