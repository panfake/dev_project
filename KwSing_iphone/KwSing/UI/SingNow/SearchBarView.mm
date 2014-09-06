//
//  SearchBarView.mm
//  KWPlayer
//
//  Created by FelixLee on 11-8-15.
//  Copyright 2011年 Kuwo Beijing Co., Ltd. All rights reserved.
//

#import "SearchBarView.h"
#include "globalm.h"
#include "SegmentControl.h"
#include "ImageMgr.h"

@implementation SearchBackgroundView
- (id) init {
    self = [super init];
    if (self) {
        self.backgroundColor = UIColorFromRGBValue(0xf5f3f3);
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGRect rc = self.bounds;
    UIColor* color = [UIColor grayColor];
    CGContextMoveToPoint(context, 0, CGRectGetMaxY(rc));
    CGContextSetStrokeColorWithColor(context, [color CGColor]);
    CGContextAddLineToPoint(context, CGRectGetMaxX(rc), CGRectGetMaxY(rc));
    CGContextClosePath(context);
    CGContextStrokePath(context);    
    CGContextRestoreGState(context);
}

@end

@implementation SearchBarView

@synthesize backgroundView = _backgroundView;
@synthesize btnSearch = _btnSearch;
@synthesize btnVoiceSrh = _btnVoiceSrh;
@synthesize btnCancel = _btnCancel;
@synthesize editing = _editing;

- (UIView*) getSubViewOfClass:(NSString*)str {
    NSArray* views = self.subviews;
    if (NSOrderedAscending != [[[UIDevice currentDevice] systemVersion] compare:@"7.0"]) {
        views = [self.subviews[0] valueForKey:@"subviews"];
    }
	
	for (UIView* view in views) {
		if ([view isKindOfClass:NSClassFromString(str)]) {
			return view;
		}
	}
	return nil;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        //_bIOS7 = (NSOrderedSame == [[[UIDevice currentDevice] systemVersion] compare:@"7.0"]);
        
		self.tintColor = [UIColor clearColor];
		self.placeholder = @"歌曲名/歌手名/简拼";
		self.keyboardType = UIKeyboardTypeDefault;
        
//        if (_bIOS7) {
//            return self;
//        }
		UITextField* searchField = (UITextField*)[self getSubViewOfClass:@"UISearchBarTextField"];
		if(searchField) {
            //UIView* marginView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)] autorelease];
            //searchField.leftView = marginView;
            searchField.leftViewMode = UITextFieldViewModeAlways;
			searchField.returnKeyType = UIReturnKeySearch;
			searchField.enablesReturnKeyAutomatically = NO;
			searchField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            //searchField.background = CImageMgr::GetImageEx("searchbarTextField_14.png");
		}
       
        UIView* bgView = [self getSubViewOfClass:@"UISearchBarBackground"];
        _backgroundView = [[UIView alloc] initWithFrame:bgView.bounds];
         _backgroundView.backgroundColor = UIColorFromRGBValue(0x0a63a7);
       
        [bgView addSubview:_backgroundView];
    }
    return self;
}

- (void)dealloc
{
    //if (!_bIOS7) {
    [_backgroundView release];
    //}
    
    [_btnSearch release];
	[_btnVoiceSrh release];
    [_btnCancel release];
    [super dealloc];
}

- (void) addSearchButtonWithTarget:(id)target action:(SEL)action {
//    if (_bIOS7) {
//        return;
//    }
    
    UIButton* button = [UIButton buttonWithTitle:nil 
                                     imageNormal:CImageMgr::GetImageEx("searchbarBtn.png")
                                imageHighlighted:CImageMgr::GetImageEx("searchbarBtnDown.png")
                                          target:target
                                          action:action];
    [self addSubview:button];
    self.btnSearch = button;
}

- (void) addSearchCancelButtonWithTarget:(id)target action:(SEL)action {
//    if (_bIOS7) {
//        [super setShowsCancelButton:YES];
//        return;
//    }
    
    UIButton* button = [UIButton buttonWithTitle:@"" 
                                     imageNormal:CImageMgr::GetImageEx("seachbarCancel.png")
                                imageHighlighted:CImageMgr::GetImageEx("searchbarCancelDown.png")
                                          target:target
                                          action:action];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14];
    [self addSubview:button];
    self.btnCancel = button;
    [self showSearchCancelButton:false];
}

- (void) showSearchCancelButton:(BOOL)show {
//    if (_bIOS7) {
//        return;
//    }
    
    if (show) {
        _btnVoiceSrh.hidden = YES;
        _btnCancel.hidden = NO;
		[UIView beginAnimations:@"search_cancel_animation_show" context:nil];
        [UIView setAnimationDuration:0.5f];
        _btnCancel.alpha = 0;
        _btnCancel.alpha = 1;
		[UIView commitAnimations];
    }
    else {
		[UIView beginAnimations:@"search_cancel_animation_hide" context:nil];
        [UIView setAnimationDuration:0.3f];
        _btnCancel.alpha = 1;
        _btnCancel.alpha = 0;
		[UIView commitAnimations];        
        _btnVoiceSrh.hidden = NO;
        _btnCancel.hidden = YES;
    }
    [self setNeedsLayout];
}

- (void) setEditing:(BOOL)edit {
//    if (_bIOS7) {
//        return;
//    }
    
    if (_editing == edit)
        return;
    _editing = edit;
    [self showSearchCancelButton:_editing];
}


#pragma mark -
#pragma mark UI

- (void) layoutSubviews {
	[super layoutSubviews];
    
//    if (_bIOS7) {
//        return;
//    }
    
	CGRect bounds = self.bounds;
	CGFloat width = bounds.size.width;
    
    self.backgroundView.frame = bounds;
	
#define MARGIN_HORIZONTAL	11
#define MARGIN_VERTICAL 	7
#define MARGIN_BETWEEN		8

#define SEARCH_FRAME_HEIGHT	27
#define CANCEL_BUTTON_HEIGHT SEARCH_FRAME_HEIGHT
#define CANCEL_BUTTON_WIDTH	46
    
#define VOICE_BUTTON_HEIGHT  SEARCH_FRAME_HEIGHT
#define VOICE_BUTTON_WIDTH  40
    
//#define VERTICAL_OFFSET     0
	
    CGRect rcCancel = CGRectMake(width - CANCEL_BUTTON_WIDTH - MARGIN_HORIZONTAL, MARGIN_VERTICAL,
                                 CANCEL_BUTTON_WIDTH, CANCEL_BUTTON_HEIGHT);
//    OffsetRectY(&rcCancel, VERTICAL_OFFSET);
    CGFloat wRightBtn = 0;
    if (_btnCancel && !_btnCancel.hidden) {
        _btnCancel.frame = rcCancel;
        wRightBtn = CANCEL_BUTTON_WIDTH;
    }
    
	if (_btnVoiceSrh && !_btnVoiceSrh.hidden) {
        CGRect rcVoiceBtn = CGRectMake(width - VOICE_BUTTON_WIDTH - MARGIN_HORIZONTAL, MARGIN_VERTICAL,
									   VOICE_BUTTON_WIDTH, VOICE_BUTTON_HEIGHT);
//        OffsetRectY(&rcVoiceBtn, VERTICAL_OFFSET);
		_btnVoiceSrh.frame = rcVoiceBtn;
		wRightBtn = VOICE_BUTTON_WIDTH;    
    }
	
	UITextField* textField = (UITextField*)[self getSubViewOfClass:@"UISearchBarTextField"];
	ASSERT(textField);
	//CGRect textFrame = textField.frame;
	CGRect rcTextField = CGRectMake(MARGIN_HORIZONTAL, MARGIN_VERTICAL,
									bounds.size.width - wRightBtn - MARGIN_BETWEEN - MARGIN_HORIZONTAL*2,
									SEARCH_FRAME_HEIGHT);
//    OffsetRectY(&rcTextField, VERTICAL_OFFSET);
    CGRect rcButton = _btnSearch.frame;
    rcButton = RightRect(rcTextField, CGRectGetWidth(rcButton), 0);
    _btnSearch.frame = rcButton;
    DeflateRect(&rcTextField, 0, 0, CGRectGetWidth(rcButton), 0);
    textField.frame = rcTextField;
}

@end