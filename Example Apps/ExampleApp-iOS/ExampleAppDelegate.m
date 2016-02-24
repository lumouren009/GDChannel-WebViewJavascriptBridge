#import "ExampleAppDelegate.h"
#import "ExampleUIWebViewController.h"
#import "ExampleWKWebViewController.h"
#import "GDCWebViewController.h"

@implementation ExampleAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    // 1. Create the UIWebView example
//    ExampleUIWebViewController* UIWebViewExampleController = [[ExampleUIWebViewController alloc] init];
//    UIWebViewExampleController.tabBarItem.title             = @"UIWebView";
//    [tabBarController addChildViewController:UIWebViewExampleController];

    // 3. Create the  WKWebView example for devices >= iOS 8
//    if([WKWebView class]) {
//        ExampleWKWebViewController* WKWebViewExampleController = [[ExampleWKWebViewController alloc] init];
//        WKWebViewExampleController.tabBarItem.title             = @"WKWebView";
//        [tabBarController addChildViewController:WKWebViewExampleController];
//    }

    GDCWebViewController* webViewController = [[GDCWebViewController alloc] init];
    [webViewController openUrl:@"https://github.com/goodow"];
    webViewController.tabBarItem.title             = @"GDCWebViewController";
    webViewController.hidesBottomBarWhenPushed = YES;
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:[[UIViewController alloc] init]];
    [navigationController pushViewController:webViewController animated:YES];
    [tabBarController addChildViewController:navigationController];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = tabBarController;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
