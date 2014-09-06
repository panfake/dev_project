//
//  FooterTabBar.h
//  kwbook
//
//  Created by 熊 改 on 13-11-28.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KBViewController.h"

#define FOOTER_TABBAR_HEIGHT            49
#define FOOTER_TABBAR_BTN_WIDTH         64
#define FOOTER_TABBAR_BTN_WIDTH_2       96
#define FOOTER_TABBAR_BTN_HEIGHT        49
#define FOOTER_TABBAR_CENTERBTN_WIDTH   64
#define FOOTER_TABBAR_CENTERBTN_HEIGHT  63.5

@protocol FooterTabBarDelegate
- (void)didFooterTabBarSelected:(unsigned)index;
@end



@interface FooterTabBar : UIView<FootDelegate>

@property (nonatomic , weak) id<FooterTabBarDelegate> delegate;
-(id)initWithSuperView:(UIView *)superView;
-(void)setSelectedIndex:(NSUInteger)selectedIndex;
-(void)addTipsAtIndex:(NSUInteger)index;
-(void)removeTipsAtIndex:(NSUInteger)index;
@end
