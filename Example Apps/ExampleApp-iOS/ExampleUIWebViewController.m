//
//  ExampleUIWebViewController.m
//  ExampleApp-iOS
//
//  Created by Marcus Westin on 1/13/14.
//  Copyright (c) 2014 Marcus Westin. All rights reserved.
//

#import "ExampleUIWebViewController.h"
#import "WebViewJavascriptBridge.h"
#import "GDCBusProvider.h"

@interface ExampleUIWebViewController ()
@property WebViewJavascriptBridge* bridge;
@property id<GDCBus> bus;
@end

@implementation ExampleUIWebViewController

- (void)viewWillAppear:(BOOL)animated {
    if (_bridge) { return; }
    
    UIWebView* webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:webView];
    
    [WebViewJavascriptBridge enableLogging];

    _bus = GDCBusProvider.instance;
    _bridge = [WebViewJavascriptBridge bridgeForWebView:webView withBus:_bus];
    
    [self.bus subscribeLocal:@"testObjcCallback" handler:^(id <GDCMessage> message) {
        NSLog(@"testObjcCallback called: %@", message);
        [message reply:@"Response from testObjcCallback" options:nil replyHandler:^(id <GDCAsyncResult> asyncResult) {
            NSLog(@"xx");
        }];
    }];

    [self renderButtons:webView];
    [self loadExamplePage:webView];

    // 收不到
    [self.bus publishLocal:@"testJavascriptHandler" payload:@{@"foo" : @"before ready"} options:nil];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSLog(@"webViewDidStartLoad");
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSLog(@"webViewDidFinishLoad");
}

- (void)renderButtons:(UIWebView*)webView {
    UIFont* font = [UIFont fontWithName:@"HelveticaNeue" size:12.0];
    
    UIButton *callbackButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [callbackButton setTitle:@"Call handler" forState:UIControlStateNormal];
    [callbackButton addTarget:self action:@selector(callHandler:) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:callbackButton aboveSubview:webView];
    callbackButton.frame = CGRectMake(10, 400, 100, 35);
    callbackButton.titleLabel.font = font;
    
    UIButton* reloadButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [reloadButton setTitle:@"Reload webview" forState:UIControlStateNormal];
    [reloadButton addTarget:webView action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:reloadButton aboveSubview:webView];
    reloadButton.frame = CGRectMake(110, 400, 100, 35);
    reloadButton.titleLabel.font = font;
}

- (void)callHandler:(id)sender {
    [self.bus sendLocal:@"testJavascriptHandler" payload:@{ @"greetingFromObjC": @"Hi there, JS!" } options:nil replyHandler:^(id <GDCAsyncResult> asyncResult) {
        NSLog(@"testJavascriptHandler responded: %@", asyncResult.result);
    }];
}

- (void)loadExamplePage:(UIWebView*)webView {
    NSString* htmlPath = [[NSBundle mainBundle] pathForResource:@"ExampleApp" ofType:@"html"];
    NSString* appHtml = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    NSURL *baseURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    [webView loadHTMLString:appHtml baseURL:baseURL];
//    WebViewJavascriptBridgeBase *base = [self.bridge valueForKey:@"_base"];
//    [base injectJavascriptFile];

//    NSString *url = [NSString stringWithFormat:@"http://m.v.qq.com/app/live/registry/index.html"];
//    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
}
@end
