//
// Created by Larry Tin on 16/2/24.
//

#import <Foundation/Foundation.h>


@interface GDCWebViewController : UIViewController

@property (nullable, nonatomic, assign) id <UIWebViewDelegate> delegate;

- (void)openUrl:(NSString *)url;

@end