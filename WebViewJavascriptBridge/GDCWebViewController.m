//
// Created by Larry Tin on 16/2/24.
//

#import "GDCWebViewController.h"
#import "WebViewJavascriptBridge.h"
#import "NSObject+GDChannel.h"
#import "Aspects.h"

@interface GDCWebViewController () <UIWebViewDelegate>
@property WebViewJavascriptBridge *bridge;
@property(weak, nonatomic) IBOutlet UIWebView *webView;
@end

@implementation GDCWebViewController {
  UIBarButtonItem *_closeButtonItem;
  id <AspectToken> _aspectHook;
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  _bridge = [WebViewJavascriptBridge bridgeForWebView:self.webView withBus:self.bus];
  [_bridge setWebViewDelegate:self];

  self.navigationItem.leftItemsSupplementBackButton = YES;
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  _aspectHook = [self.navigationController aspect_hookSelector:@selector(navigationBar:shouldPopItem:) withOptions:AspectPositionInstead usingBlock:^(id <AspectInfo> info) {
      NSInvocation *invocation = info.originalInvocation;
      UINavigationController *instance = info.instance;
      BOOL toRtn;
      if ([instance.topViewController isKindOfClass:GDCWebViewController.class]) {
        GDCWebViewController *webViewController = instance.topViewController;
        if ([webViewController.webView canGoBack]) {
          [webViewController.webView goBack];
          toRtn = NO;
          [invocation setReturnValue:&toRtn];
          return;
        }
      }
      [invocation invoke];
      [invocation getReturnValue:&toRtn];
      [invocation setReturnValue:&toRtn];
  }                                                      error:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  [_aspectHook remove];
  _aspectHook = nil;
}


- (void)openUrl:(NSString *)url {
  [self view];
  [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
}

- (void)handleMessage:(id <GDCMessage>)message {
  NSDictionary *payload = message.payload;
  NSString *url = payload[@"url"];
  if (url) {
    [self openUrl:url];
  }
}

- (void)updateNavBarItems {
  if ([self.webView canGoBack]) {
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    [self.navigationItem setLeftBarButtonItems:@[self.closeButtonItem] animated:NO];
  } else {
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    [self.navigationItem setLeftBarButtonItems:nil];
  }
}

- (UIBarButtonItem *)closeButtonItem {
  if (!_closeButtonItem) {
    _closeButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(handleClose:)];
  }
  return _closeButtonItem;
}

- (void)handleClose:(UIBarButtonItem *)sender {
  [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView {
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  [self updateNavBarItems];

}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  NSString *title = [self.bridge _evaluateJavascript:@"document.title"];
  if (title.length > 10) {
    title = [[title substringToIndex:9] stringByAppendingString:@"…"];
  }
  self.navigationItem.title = title;
  [self updateNavBarItems];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  [self updateNavBarItems];

}

@end