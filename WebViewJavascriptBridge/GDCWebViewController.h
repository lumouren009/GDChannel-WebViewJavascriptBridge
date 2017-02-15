//
// Created by Larry Tin on 16/2/24.
//

#import <Foundation/Foundation.h>
#import "GDDPresenter.h"

typedef enum : NSUInteger {
  GDCMoreInfoButtonTypeShare = 1,
  GDCMoreInfoButtonTypeAction
} GDCMoreInfoButtonType;

@interface GDCMoreInfoButtonAppearance : NSObject
@property (nonatomic, assign) GDCMoreInfoButtonType type;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) UIColor *color; //optional
@end

@interface GDCWebViewController : UIViewController <GDDView, GDDPresenter>
@property(weak, nonatomic) IBOutlet UIWebView *webView;
@property (nullable, nonatomic, assign) id <UIWebViewDelegate> delegate;

- (void)openUrl:(NSString *)url;
// 更多按钮
- (void)addMoreInfoButtonWithAppearance:(GDCMoreInfoButtonAppearance *)appearance handler:(void(^)())handler;
@end
