//
// Created by Larry Tin on 16/2/24.
//

#import "GDCWebViewController.h"
#import "WebViewJavascriptBridge.h"
#import "NSObject+GDChannel.h"
#import "Aspects.h"
#import "NJKWebViewProgress.h"
#import "NJKWebViewProgressView.h"
#import "GDDViewControllerTransition.h"
#import "UIViewController+GDDataDrivenView.h"

@interface GDCWebViewController () <UIWebViewDelegate, NJKWebViewProgressDelegate>
@property(weak, nonatomic) IBOutlet NJKWebViewProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIView *tapToReloadView;
@end

@implementation GDCWebViewController {
  WebViewJavascriptBridge *_bridge;
  UIBarButtonItem *_backButtonItem;
  UIBarButtonItem *_closeButtonItem;
  id <AspectToken> _aspectHook;

  NJKWebViewProgress *_progressProxy;
  NSURL *_url;
  BOOL _isTopLevelNavigation;
  
}

#pragma mark - View lifecycle
- (instancetype)init {
  self = [super initWithNibName:NSStringFromClass(GDCWebViewController.class) bundle:nil];
  if (self) {
    super.viewOption.setHidesBottomBarWhenPushed(YES).setNavBar(GDPBBool_True);
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  _progressView.progressBarView.backgroundColor = [UIColor colorWithRed:251.f/255.f green:146.f/255.f blue:54.f/255.f alpha:1];
  _progressProxy = [[NJKWebViewProgress alloc] init];
  _progressProxy.webViewProxyDelegate = self;
  _progressProxy.progressDelegate = self;
  NSDictionary *views = @{@"progressView" : self.progressView, @"topLayoutGuide" : self.topLayoutGuide};
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[topLayoutGuide]-0-[progressView]" options:0 metrics:nil views:views]];

  _bridge = [WebViewJavascriptBridge bridgeForWebView:self.webView withBus:self.bus];
  [_bridge setWebViewDelegate:_progressProxy];
  self.navigationItem.hidesBackButton = YES;
  [self.navigationItem setLeftBarButtonItems:@[self.backButtonItem] animated:NO];

  _webView.scalesPageToFit = YES;
  _webView.allowsInlineMediaPlayback = YES; //允许使用H5内置播放器
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
  // 临时避免连续push两个GDCWebViewController实例后, 手势返回导致导航栏显示异常
  self.navigationController.interactivePopGestureRecognizer.enabled = NO;
  
  __weak GDCWebViewController *weakSelf = self;
  _aspectHook = [self.navigationController aspect_hookSelector:@selector(navigationBar:shouldPopItem:) withOptions:AspectPositionInstead usingBlock:^(id <AspectInfo> info) {
      NSInvocation *invocation = info.originalInvocation;
      UINavigationController *instance = info.instance;
      BOOL toRtn;
      if ([instance.topViewController isKindOfClass:GDCWebViewController.class]) {
        GDCWebViewController *webViewController = (GDCWebViewController *) instance.topViewController;
        if (webViewController.webView.canGoBack) {
          [webViewController.webView goBack];
          [weakSelf updateNavBarItems];
          // make sure the back indicator view alpha back to 1
          instance.navigationBar.subviews.lastObject.alpha = 1;
          toRtn = NO;
          [invocation setReturnValue:&toRtn];
          return;
        }
      }
      GDDViewControllerTransition.new.toUp();
  }                                                      error:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  self.navigationController.interactivePopGestureRecognizer.enabled = YES;
  [_aspectHook remove];
  _aspectHook = nil;
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
  return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - public methods
- (void)openUrl:(NSString *)url {
  [self view];
  if ([url hasPrefix:@"/"]) {
    NSString *htmlStr = [NSString stringWithContentsOfFile:url encoding:NSUTF8StringEncoding error:nil];
    NSURL *baseUrl = [NSURL fileURLWithPath:url.stringByDeletingLastPathComponent];
    [self.webView loadHTMLString:htmlStr baseURL:baseUrl];
  } else {
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
  }
}



- (void)updateNavBarItems {
  NSMutableArray *leftBarButtonItems = self.navigationItem.leftBarButtonItems.mutableCopy ? : [NSMutableArray array];
  if (self.webView.canGoBack) {
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    if (![leftBarButtonItems containsObject:self.closeButtonItem]) {
      [leftBarButtonItems addObject:self.closeButtonItem];
      [self.navigationItem setLeftBarButtonItems:leftBarButtonItems animated:NO];
    }
  } else {
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    if ([self.navigationItem.leftBarButtonItems containsObject:self.closeButtonItem]) {
      [leftBarButtonItems removeObject:self.closeButtonItem];
      [self.navigationItem setLeftBarButtonItems:leftBarButtonItems animated:NO];
    }
  }
}

- (UIBarButtonItem *)closeButtonItem {
  if (!_closeButtonItem) {
    _closeButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(handleClose:)];
  }
  return _closeButtonItem;
}

- (UIBarButtonItem *)backButtonItem {
  if (!_backButtonItem) {
    UIImage *backImg = [UIImage imageNamed:@"yuyue_ic_arrow_nor"];
    UIButton *backButton  =[UIButton buttonWithType:UIButtonTypeCustom];
    [backButton setImage:backImg forState:UIControlStateNormal];
    backButton.frame = CGRectMake(0, 0, backImg.size.width, backImg.size.height);
    backButton.imageEdgeInsets = UIEdgeInsetsMake(0, -5.5, 0, 5.5); // 由于image不贴边，所以调整image的位置
    [backButton addTarget:self action:@selector(handleBack:) forControlEvents:UIControlEventTouchUpInside];
    _backButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
  }
  return _backButtonItem;
}

- (void)handleBack:(UIBarButtonItem *)sender {
  if (self.webView.canGoBack) {
    [self.webView goBack];
    [self updateNavBarItems];
    // make sure the back indicator view alpha back to 1
//    self.navigationController.navigationBar.subviews.lastObject.alpha = 1;
  } else {
    [self handleClose:sender];
  }
}

- (void)handleClose:(UIBarButtonItem *)sender {
  GDDViewControllerTransition.new.toUp();
}


#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
  _isTopLevelNavigation = [request.mainDocumentURL isEqual:request.URL];
  if (_isTopLevelNavigation) {
    _url = request.URL;
  }
  if ([self.delegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
    return [self.delegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
  }
  return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  if ([self.delegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
    [self.delegate webViewDidStartLoad:webView];
  }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

//  if (!_isTopLevelNavigation) {
//    return;
//  }
  NSString *title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"];
  if (title.length > 10) {
    title = [[title substringToIndex:9] stringByAppendingString:@"…"];
  }
  self.title = title;
  if ([self.delegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
    [self.delegate webViewDidFinishLoad:webView];
  }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
  NSLog(@"%s error: %@", __PRETTY_FUNCTION__, error);
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

  if (webView.request.URL.absoluteString.length != 0 || !_isTopLevelNavigation) {
    // ignore these failures: 1 jump links from opened page (not the first open); 2 ajax request
    return;
  }
  self.tapToReloadView.hidden = NO;
  if ([self.delegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
    [self.delegate webView:webView didFailLoadWithError:error];
  }
}

- (IBAction)tapToReload:(UITapGestureRecognizer *)gestureRecognizer {
  self.tapToReloadView.hidden = YES;
  [self.webView loadRequest:[NSURLRequest requestWithURL:_url]];
}

#pragma mark - NJKWebViewProgressDelegate

- (void)webViewProgress:(NJKWebViewProgress *)webViewProgress updateProgress:(float)progress {
  [self.progressView setProgress:progress animated:YES];
}

#pragma mark - Appearance
+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size {
  CGRect rect = CGRectMake(0.0f, 0.0f, size.width, size.height);
  
  UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
  [color setFill];
  UIRectFill(rect);
  
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  return image;
}


@end
