//
//  FooterTabBar.m
//  kwbook
//
//  Created by 熊 改 on 13-11-28.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import "FooterTabBar.h"
#import "globalm.h"
#import "ImageMgr.h"
#import "CacheMgr.h"
#import "AudioPlayerManager.h"
#import "BookInfoList.h"
#import "IObserverAudioPlayState.h"
#import "MessageManager.h"


#define NUM_OF_TABS     5
#define TAG_TIPS_BASE   2000

enum AudioPlayControlState
{
    E_AUDIO_PLAY_CONTROL_NONE,
    E_AUDIO_PLAY_CONTROL_BUFFERING,
    E_AUDIO_PLAY_CONTROL_PLAYING,
    E_AUDIO_PLAY_CONTROL_PAUSE,
    E_AUDIO_PLAY_CONTROL_STOP,
    E_AUDIO_PLAY_CONTROL_FINISH,
    E_AUDIO_PLAY_CONTROL_BOOK_CHANGE
};

@interface FooterTabBar ()
{
    BOOL        _isFootHidden;
    unsigned    _selectIndex;
    int         _tipsIndexs[4];
}
@property (nonatomic , strong) NSArray *arrayBtns;
@property (nonatomic , strong) UIButton *centerBtn;
@property (nonatomic , strong) UIImageView *bookImageView;
@property (nonatomic , strong) UIView   *btnView;
@property (nonatomic , strong) UIActivityIndicatorView *bufferingView;

-(UIButton *)addCenterButtonWithSuperView:(UIView *)superView atRect:(CGRect)rect;
- (UIButton*)addBtnWithFrame:(CGRect)frame imageName:(NSString*)strImg;
-(void)onBtnClick:(id)sender;
@end


@implementation FooterTabBar

-(id)initWithSuperView:(UIView *)superView
{
    CGRect footerRect = BottomRect(superView.bounds,FOOTER_TABBAR_BTN_HEIGHT,0);
    self = [super initWithFrame:footerRect];
    if (self) {
        
        GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
        _tipsIndexs[0] = _tipsIndexs[1] = _tipsIndexs[2] = _tipsIndexs[3] = 0;
        _isFootHidden = NO;
        _selectIndex = -1;
        [superView addSubview:self];
        CGRect rect1,rect2,rect3,rect4,rect5;
        rect1 = CGRectMake(0, 0, FOOTER_TABBAR_BTN_WIDTH, FOOTER_TABBAR_BTN_HEIGHT);
        rect2 = CGRectMake(FOOTER_TABBAR_BTN_WIDTH, 0, FOOTER_TABBAR_BTN_WIDTH_2, FOOTER_TABBAR_BTN_HEIGHT);
        rect3 = CGRectMake(0, 0, FOOTER_TABBAR_CENTERBTN_WIDTH, FOOTER_TABBAR_CENTERBTN_HEIGHT);
        rect4 = CGRectMake(FOOTER_TABBAR_BTN_WIDTH +FOOTER_TABBAR_BTN_WIDTH_2, 0,
                           FOOTER_TABBAR_BTN_WIDTH_2, FOOTER_TABBAR_BTN_HEIGHT);
        rect5 = CGRectMake(FOOTER_TABBAR_BTN_WIDTH *3 + FOOTER_TABBAR_CENTERBTN_WIDTH, 0,
                           FOOTER_TABBAR_BTN_WIDTH, FOOTER_TABBAR_BTN_HEIGHT);
        
        UIButton *btn1 = [self addBtnWithFrame:rect1 imageName:@"FooterBtnRecommend"];
        UIButton *btn2 = [self addBtnWithFrame:rect2 imageName:@"FooterBtnCategory"];
        UIButton *btn4 = [self addBtnWithFrame:rect4 imageName:@"FooterBtnDownload"];
        UIButton *btn5 = [self addBtnWithFrame:rect5 imageName:@"FooterBtnMine"];
        
        UIButton *btn3 = [self addCenterButtonWithSuperView:superView atRect:rect3];
        [self setCenterBtn:btn3];
        _arrayBtns = @[btn1,btn2,btn3,btn4,btn5];
        [self setStatus:(AudioPlayControlState)CAudioPlayerManager::getInstance()->getCurPlayState()];
        [self startLoadImage];
        
        //[self.bufferingView startAnimating];
    }
    return self;
}
- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
}
-(UIButton *)addCenterButtonWithSuperView:(UIView *)superView atRect:(CGRect)rect
{
    self.btnView = ({
        UIView *btnView= [[UIView alloc] initWithFrame:rect];
        [btnView setCenter:CGPointMake(superView.center.x, superView.bounds.size.height-FOOTER_TABBAR_CENTERBTN_HEIGHT/2)];
        btnView;
    });
    
    CGRect bookImageRect = CGRectMake(4.5, 4.5, rect.size.width - 9, rect.size.height - 9);
    CGRect btnRect       = CGRectMake(0, 0, rect.size.width, rect.size.height);
    
    self.bookImageView = ({
        UIImageView *bookImageView = [[UIImageView alloc] initWithFrame:bookImageRect];
        [bookImageView setImage:CImageMgr::GetImageEx("DefaultCenterBtn.png")];
        bookImageView;
    });
    [self.btnView addSubview:self.bookImageView];
    
    self.bufferingView = ({
        UIActivityIndicatorView *bufferingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [bufferingView setCenter:CGPointMake(FOOTER_TABBAR_CENTERBTN_WIDTH/2, FOOTER_TABBAR_CENTERBTN_HEIGHT/2)];
        bufferingView;
    });
    [self.btnView addSubview:self.bufferingView];
    
    UIButton *btnCenter = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnCenter setFrame:btnRect];
    //[btnCenter setCenter:CGPointMake(superView.center.x, superView.bounds.size.height-FOOTER_TABBAR_CENTERBTN_HEIGHT/2)];
    btnCenter.adjustsImageWhenHighlighted = NO;
    [btnCenter setBackgroundImage:CImageMgr::GetImageEx("FooterBtnPlay.png") forState:UIControlStateNormal];
    [btnCenter addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.btnView addSubview:btnCenter];
    
    [superView addSubview:self.btnView];
    
    return btnCenter;
}
- (UIButton*)addBtnWithFrame:(CGRect)frame imageName:(NSString*)strImg
{
    UIButton* pButton=[UIButton buttonWithType:UIButtonTypeCustom];
    [pButton setFrame:frame];
    [self addSubview:pButton];
    pButton.adjustsImageWhenHighlighted=FALSE;
    [pButton setImage:CImageMgr::GetImageEx([[NSString stringWithFormat:@"%@.png",strImg] UTF8String]) forState:UIControlStateNormal];
    [pButton setImage:CImageMgr::GetImageEx([[NSString stringWithFormat:@"%@Down.png",strImg] UTF8String]) forState:UIControlStateHighlighted];
//    [pButton setImage:CImageMgr::GetImageEx([[NSString stringWithFormat:@"%@Down.png",strImg] UTF8String]) forState:UIControlStateSelected];
    [pButton setImage:CImageMgr::GetImageEx([[NSString stringWithFormat:@"%@Down.png",strImg] UTF8String]) forState:UIControlStateDisabled];
    [pButton addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:pButton];
    return pButton;
}
-(void)addTipsAtIndex:(NSUInteger)index
{
    if (index >=NUM_OF_TABS-1 || _tipsIndexs[index]) {
        return;
    }
    UIImageView *tipView = [[UIImageView alloc] initWithImage:CImageMgr::GetImageEx("RedDotTips.png")];
    CGPoint center = CGPointMake(60, 5);
    if (index == 1) {
        center.x +=FOOTER_TABBAR_BTN_WIDTH;
    }
    else if(index == 2){
        center.x += FOOTER_TABBAR_BTN_WIDTH_2*2;
    }
    else if(index == 3){
        center.x += FOOTER_TABBAR_BTN_WIDTH + FOOTER_TABBAR_BTN_WIDTH_2 *2;
    }
    [tipView setCenter:center];
    [tipView setTag:TAG_TIPS_BASE+index];
    [self addSubview:tipView];
    _tipsIndexs[index] = 1;
}
-(void)removeTipsAtIndex:(NSUInteger)index
{
    if (index >=NUM_OF_TABS-1 || _tipsIndexs[index]==0) {
        return;
    }
    UIImageView *tipsView = (UIImageView *)[self viewWithTag:TAG_TIPS_BASE+index];
    if (tipsView) {
        [tipsView removeFromSuperview];
        tipsView = nil;
    }
    _tipsIndexs[index] = 0;
}
-(void)onBtnClick:(id)sender
{
    UIButton *button = (UIButton *)sender;
    if (button == self.centerBtn) {
        [self.delegate didFooterTabBarSelected:2];
        return;
    }
    for (int i=0; i<NUM_OF_TABS; ++i) {
        UIButton *btn = self.arrayBtns[i];
        if (button == btn) {
            _selectIndex = i;
            [btn setEnabled:NO];
            [self.delegate didFooterTabBarSelected:i];
        }
        else{
            [btn setEnabled:YES];
        }
    }
}

-(void)setSelectedIndex:(NSUInteger)selectedIndex
{
    [self onBtnClick:self.arrayBtns[selectedIndex]];
}
-(void)showFoot
{
    if (!_isFootHidden) {
        return;
    }
    [UIView animateWithDuration:0.5 animations:^{
        [self setFrame:MoveDownRect(self.frame, FOOTER_TABBAR_CENTERBTN_HEIGHT)];
        [self.btnView setFrame:MoveDownRect(self.btnView.frame, FOOTER_TABBAR_CENTERBTN_HEIGHT)];
    } completion:^(BOOL finished) {
        _isFootHidden = NO;
    }];
}
-(void)hideFoot
{
    if (_isFootHidden || _selectIndex>1) {
        return;
    }
    [UIView animateWithDuration:0.5 animations:^{
        [self setFrame:MoveUpRect(self.frame, FOOTER_TABBAR_CENTERBTN_HEIGHT)];
        [self.btnView setFrame:MoveUpRect(self.btnView.frame, FOOTER_TABBAR_CENTERBTN_HEIGHT)];
    } completion:^(BOOL finished) {
        _isFootHidden = YES;
    }];
}

-(void)startLoadImage
{
    CChapterInfo* chapter_info = CPlayBookList::getInstance()->getCurChapter();
    if (!chapter_info) {
        [self.bookImageView setImage:CImageMgr::GetImageEx("DefaultCenterBtn.png")];
        return;
    }
    std::string bookId = chapter_info->m_strBookId;
    CBookInfo *bookInfo = CBookInfoList::getInstance()->getBookInfo(bookId);
    
    if (!bookInfo || 0 == bookInfo->m_strImgUrl.size()) {
        [self.bookImageView setImage:CImageMgr::GetImageEx("DefaultCenterBtn.png")];
        return;
    }
    NSString *imageURL = [NSString stringWithUTF8String:bookInfo->m_strImgUrl.c_str()];
    
    __block void* imageData = NULL;
    __block unsigned length = 0;;
    __block BOOL outOfDate;
    if (CCacheMgr::GetInstance()->Read([imageURL UTF8String], imageData, length, outOfDate)) {
        NSData *cacheImageData=[[NSData alloc] initWithBytesNoCopy:imageData length:length freeWhenDone:YES];
        if (cacheImageData) {
            UIImage *image = [[UIImage alloc] initWithData:cacheImageData];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.bookImageView setImage:image];
            });
        }
        else{
            UIImage *image = CImageMgr::GetImageEx("DefaultCenterBtn.png");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.bookImageView setImage:image];;
            });
        }
    }
    else{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageURL]];
            if (imageData) {
                UIImage *image = [[UIImage alloc] initWithData:imageData];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.bookImageView setImage:image];
                    CCacheMgr::GetInstance()->Cache(T_DAY, 3, [imageURL UTF8String], [imageData bytes], [imageData length]);
                });
            }
            else{
                UIImage *image = CImageMgr::GetImageEx("DefaultCenterBtn.png");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.bookImageView setImage:image];;
                });
            }
        });
    }
    
}
-(void)setStatus:(AudioPlayControlState)status
{
    UIButton *centerBtn = self.centerBtn;
    //[centerBtn setImageEdgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
    
    switch (status) {
        case E_AUDIO_PLAY_CONTROL_PLAYING:
            if (self.bufferingView.isAnimating) {
                [self.bufferingView stopAnimating];
            }
            break;
        case E_AUDIO_PLAY_CONTROL_PAUSE:
            if (self.bufferingView.isAnimating) {
                [self.bufferingView stopAnimating];
            }
            break;
        case E_AUDIO_PLAY_CONTROL_BUFFERING:
            [centerBtn setImage:nil forState:UIControlStateNormal];
            if (!self.bufferingView.isAnimating) {
                [self.bufferingView startAnimating];
            }
            break;
        case E_AUDIO_PLAY_CONTROL_NONE:
            if (self.bufferingView.isAnimating) {
                [self.bufferingView stopAnimating];
            }
            [self startLoadImage];
            break;
        case E_AUDIO_PLAY_CONTROL_FINISH:
            if (self.bufferingView.isAnimating) {
                [self.bufferingView stopAnimating];
            }
            break;
        case E_AUDIO_PLAY_CONTROL_STOP:
            if (self.bufferingView.isAnimating) {
                [self.bufferingView stopAnimating];
            }
            break;
        case E_AUDIO_PLAY_CONTROL_BOOK_CHANGE:
            [self startLoadImage];
            break;
        default:
            break;
    }
}
-(void)IObserverAudioPlayStateChanged:(AudioPlayState)enumStatus
{
    [self setStatus:(AudioPlayControlState)enumStatus];
}
@end
