//
//  KBViewController.h
//  kwbook
//
//  Created by 熊 改 on 13-11-28.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol FootDelegate <NSObject>

-(void)showFoot;
-(void)hideFoot;
@end

@interface KBViewController : UIViewController
@property (nonatomic , weak) id<FootDelegate> footDelegate;
@property (nonatomic , assign) CGRect  tipsRect;

-(id)initWithFrame:(CGRect)rect;
- (void)showLoadingPage:(BOOL)bShow descript:(NSString*)strDescript;
-(void)showNoNetWorkPage;
-(void)removeNoNetPage;
-(void)showLoadFailPage;
-(void)removeLoadFailPage;
-(void)onTap;               //sub class should rewrite this method
@end
