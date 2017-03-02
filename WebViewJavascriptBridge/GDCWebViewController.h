//
// Created by Larry Tin on 16/2/24.
//

#import <UIKit/UIKit.h>

@interface GDCWebViewController : UIViewController
@property(weak, nonatomic) IBOutlet UIWebView *webView;
@property (nullable, nonatomic, assign) id <UIWebViewDelegate> delegate;

- (void)openUrl:(NSString *)url;

@end
