//
//  PlayControlViewController.m
//  kwbook
//
//  Created by 熊 改 on 13-12-5.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import "PlayControlViewController.h"
#import "globalm.h"
#import "ImageMgr.h"
#import "PlayBookList.h"
#import "AudioPlayerManager.h"
#import "IObserverAudioPlayState.h"
#import "IObserverNetBufferringState.h"
#import "CollectBookList.h"
#import "LocalBookRequest.h"
#import "MessageManager.h"
#import "KBBookDetailViewController.h"
#import "LocalBookRequest.h"
#import "BookInfoList.h"
#import "KBAppDelegate.h"
#import "iToast.h"
#import <CoreText/CoreText.h>
#include "BookManagement.h"
#import "UMengLog.h"
#import "KwUMengElement.h"
#import "KBSetTimming.h"

#include "KwConfig.h"
#include "KwConfigElements.h"


#define TAG_BTN_DETAIL      71
#define TAG_BTN_COLLECT     72
#define TAG_BTN_DOWNLOAD    73
#define TAG_BTN_LAST        74
#define TAG_BTN_PLAY        75
#define TAG_BTN_NEXT        76
#define TAG_BTN_TIMER       77
#define TAG_BTN_EPISODE     78

#define TAG_LABEL_TIMER     79
#define TAG_LABEL_EPISODE   80

#define TAG_ALERT_PRE       81
#define TAG_ALERT_CUR       82
#define TAG_ALERT_NEXT      83

#define TAG_ALERT_DOWNLOAD  84
#define TAG_ALERT_CUR_RESUME 85

const CGFloat pickerCellHeight = 180;

typedef NS_ENUM(NSInteger, TIME_TYPE){
    TIME_TYPE_NONE = 0,
    TIME_TYPE_TIMER,
    TIME_TYPE_EPISODE
};

@interface PlayControlViewController ()<IObserverAudioPlayState,UIPickerViewDataSource,UIPickerViewDelegate,UIAlertViewDelegate>
{
    NSTimer     *_closeTimer;
    NSTimer     *_refreshTimer;
    BOOL        _hasCollected;
    BOOL        _hasDownLoad;
    BOOL        _hasPickerView;
    BOOL        _isFromTheSameBook;
}
@property (nonatomic , strong) UIView       *contentView;
@property (nonatomic , strong) UILabel      *nameLabel;
@property (nonatomic , strong) UILabel      *playTimeLabel;
@property (nonatomic , strong) UILabel      *totalTimeLabel;
@property (nonatomic , strong) UISlider     *playSlider;
@property (nonatomic , strong) UIImageView  *bufferProgressView;
@property (nonatomic , strong) UIToolbar    *toolBar;
@property (nonatomic , assign) TIME_TYPE    timeType;       //用来指示当前准备编辑的定时类型，而不是当前的定时类型，在点击相应的按钮发生改变

@property (nonatomic , strong) UIPickerView     *timePicker;
@property (nonatomic , strong) UIPickerView     *episodePicker;
@property (nonatomic , strong) NSArray          *timeData;
@property (nonatomic , strong) NSArray          *timeDataText;
@property (nonatomic , strong) NSArray          *timeDataLabelText;
@property (nonatomic , strong) NSArray          *episodeData;
@property (nonatomic , strong) NSArray          *episodeDataText;
@property (nonatomic , strong) NSArray          *episodeDataLabelText;
@end

@implementation PlayControlViewController


const float kProgressWidth = 230;
const float kTimeToClose   = 2.0f;
const float kTimeToRefresh = 1.0f;
const float kAnimationDuration = 0.4f;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _hasPickerView = NO;
        _timeType = TIME_TYPE_NONE;
        _timeData = @[@0,@10,@20,@30,@40,@50,@60,@90,@120];
        _timeDataText = @[@"未定时",@"10分钟",@"20分钟",@"30分钟",@"40分钟",@"50分钟",@"60分钟",@"90分钟",@"120分钟"];
        _timeDataLabelText = @[@"未定时",@"10分钟后停止",@"20分钟后停止",@"30分钟后停止",@"40分钟后停止",@"50分钟后停止",@"60分钟后停止",@"90分钟后停止",@"120分钟后停止"];
        _episodeData = @[@0,@1,@2,@3,@4,@5,@6,@7,@8,@9,@10];
        _episodeDataText = @[@"未定时",@"1集",@"2集",@"3集",@"4集",@"5集",@"6集",@"7集",@"8集",@"9集",@"10集"];
        _episodeDataLabelText = @[@"未定时",@"1集播完后停止",@"2集播完后停止",@"3集播完后停止",@"4集播完后停止",@"5集播完后停止",@"6集播完后停止",@"7集播完后停止",@"8集播完后停止",@"9集播完后停止",@"10集播完后停止"];
        GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
        
        _isFromTheSameBook = NO;
        UIViewController *topVC = [ROOT_NAVI_CONTROLLER topViewController];
        if ([topVC isKindOfClass:[KBBookDetailViewController class]]) {
            std::string theBookId = [(KBBookDetailViewController *)topVC theBookId];
            CChapterInfo *chapInfo = CPlayBookList::getInstance()->getCurChapter();
            if (chapInfo && theBookId == chapInfo->m_strBookId) {
                _isFromTheSameBook = YES;
                NSLog(@"the same");
            }
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [[self view] setBackgroundColor:[UIColor clearColor]];
    
    self.contentView = ({
        UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(128, 536, 64, 64)];
        [contentView.layer setCornerRadius:10.0];
        [contentView setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.95]];
        
//        for (int i = 1; i<6; ++i) {
//            UIImageView *lineBreakView = [[UIImageView alloc] initWithImage:CImageMgr::GetImageEx("LineBreakImage.png")];
//            [lineBreakView setFrame:CGRectMake(0, 59*i, 300, 1)];
//            [contentView addSubview:lineBreakView];
//        }
        
        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 280, 59)];
        self.nameLabel.numberOfLines = 0;
        [self.nameLabel setBackgroundColor:[UIColor clearColor]];
        [self.nameLabel setTextColor:[UIColor whiteColor]];
        [self.nameLabel setTextAlignment:NSTextAlignmentCenter];
        [self.nameLabel setFont:[UIFont systemFontOfSize:17.0]];
        [contentView addSubview:self.nameLabel];
        
        UIButton *detailBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [detailBtn setImage:CImageMgr::GetImageEx("DetailBtn.png") forState:UIControlStateNormal];
        [detailBtn setImage:CImageMgr::GetImageEx("DetailBtnDown.png") forState:UIControlStateHighlighted];
        [detailBtn setFrame:CGRectMake(246, 252, 42, 37.5)];
        [detailBtn setTag:TAG_BTN_DETAIL];
        [detailBtn addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [contentView addSubview:detailBtn];
        
        UIButton *collectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [collectBtn setImage:CImageMgr::GetImageEx("CollectionBtn.png") forState:UIControlStateNormal];
        [collectBtn setImage:CImageMgr::GetImageEx("CollectionBtnDown.png") forState:UIControlStateSelected];
        [collectBtn setFrame:CGRectMake(72.5, 60, 35, 42.5)];
        [collectBtn addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [collectBtn setTag:TAG_BTN_COLLECT];
        [contentView addSubview:collectBtn];
        
        UIButton *downloadBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [downloadBtn setImage:CImageMgr::GetImageEx("DownloadBtn.png") forState:UIControlStateNormal];
        //[downloadBtn setImage:CImageMgr::GetImageEx("DownloadBtnDown.png") forState:UIControlStateSelected];
        [downloadBtn setFrame:MoveRightRect(collectBtn.frame, 114)];
        [downloadBtn addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [downloadBtn setTag:TAG_BTN_DOWNLOAD];
        [contentView addSubview:downloadBtn];
        
        float gap = 0;
        NSString *vString = [[UIDevice currentDevice] systemVersion];
        float version = [[[UIDevice currentDevice] systemVersion] floatValue];
        if (version < 7.0) {
            gap = 3;
        }
        else if([vString isEqualToString:@"7.0.2"] || [vString isEqualToString:@"7.0.1"] || [vString isEqualToString:@"7.0"]){
            gap = 8;
        }
        self.playTimeLabel = ({
            UILabel *playTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 122+gap, 33, 9)];
            [playTimeLabel setBackgroundColor:[UIColor clearColor]];
            [playTimeLabel setTextColor:[UIColor whiteColor]];
            [playTimeLabel setFont:[UIFont systemFontOfSize:9.0]];
            [playTimeLabel setText:@"00:00"];
            playTimeLabel;
        });
        [contentView addSubview:self.playTimeLabel];
        
        self.totalTimeLabel = ({
            UILabel *totalTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(270, 122+gap, 33, 9)];
            [totalTimeLabel setBackgroundColor:[UIColor clearColor]];
            [totalTimeLabel setTextColor:[UIColor whiteColor]];
            [totalTimeLabel setFont:[UIFont systemFontOfSize:9.0]];
            [totalTimeLabel setText:@"00:00"];
            totalTimeLabel;
        });
        [contentView addSubview:self.totalTimeLabel];
        
        
        self.bufferProgressView = ({
            UIImageView *bufferProgressView = [[UIImageView alloc] initWithFrame:CGRectMake(35, 122+gap, 0, 7)];
            [bufferProgressView setImage:CImageMgr::GetImageEx("PlayProgress_7.png")];
            bufferProgressView;
        });
        [contentView addSubview:self.bufferProgressView];
        
        
        self.playSlider = [[UISlider alloc] initWithFrame:CGRectMake(33, 117, 234, 18)];
        UIImage *minImage = CImageMgr::GetImageEx("PlaySliderMin_7.png");
        UIImage *maxImage = CImageMgr::GetImageEx("PlaySliderMax_7.png");
        [self.playSlider setMaximumTrackImage:maxImage forState:UIControlStateNormal];
        [self.playSlider setMinimumTrackImage:minImage forState:UIControlStateNormal];
        [self.playSlider setThumbImage:CImageMgr::GetImageEx("PlayThumb.png") forState:UIControlStateNormal];
        [self.playSlider addTarget:self action:@selector(onSliderChanged:) forControlEvents:UIControlEventTouchUpInside];
        
        [contentView addSubview:self.playSlider];
        
        UIButton *lastBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [lastBtn setImage:CImageMgr::GetImageEx("LastBtn.png") forState:UIControlStateNormal];
        [lastBtn setImage:CImageMgr::GetImageEx("LastBtnDown.png") forState:UIControlStateHighlighted];
        [lastBtn setFrame:CGRectMake(57, 155, 35.5, 35)];
        [lastBtn addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [lastBtn setTag:TAG_BTN_LAST];
        [contentView addSubview:lastBtn];
        
        UIButton *playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [playBtn setImage:CImageMgr::GetImageEx("PlayBtn.png") forState:UIControlStateNormal];
        [playBtn setImage:CImageMgr::GetImageEx("PauseBtn.png") forState:UIControlStateSelected];
        [playBtn setFrame:CGRectMake(126.5, 150, 47.5, 47)];
        [playBtn addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [playBtn setTag:TAG_BTN_PLAY];
        [contentView addSubview:playBtn];
        
        UIButton *nextBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [nextBtn setImage:CImageMgr::GetImageEx("NextBtn.png") forState:UIControlStateNormal];
        [nextBtn setImage:CImageMgr::GetImageEx("NextBtnDown.png") forState:UIControlStateHighlighted];
        [nextBtn setFrame:CGRectMake(213, 155, 35.5, 35)];
        [nextBtn addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [nextBtn setTag:TAG_BTN_NEXT];
        [contentView addSubview:nextBtn];
        
        UIButton *timeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [timeBtn setImage:CImageMgr::GetImageEx("TimerBtn.png") forState:UIControlStateNormal];
        [timeBtn setImage:CImageMgr::GetImageEx("TimerBtnDown.png") forState:UIControlStateHighlighted];
        [timeBtn setImage:CImageMgr::GetImageEx("TimerBtnDown.png") forState:UIControlStateSelected];
        [timeBtn setFrame:CGRectMake(72.5, 210, 30, 30)];
        [timeBtn addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [timeBtn setTag:TAG_BTN_TIMER];
        [contentView addSubview:timeBtn];
        
        UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 240, 90, 15)];
        [timeLabel setBackgroundColor:[UIColor clearColor]];
        [timeLabel setTextColor:UIColorFromRGBValue(0xffea3b)];
        [timeLabel setTextAlignment:NSTextAlignmentCenter];
        [timeLabel setTag:TAG_LABEL_TIMER];
        [timeLabel setFont:[UIFont systemFontOfSize:12]];
        [contentView addSubview:timeLabel];
        
        UIButton *episodeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [episodeBtn setImage:CImageMgr::GetImageEx("EpisodeBtn.png") forState:UIControlStateNormal];
        [episodeBtn setImage:CImageMgr::GetImageEx("EpisodeBtnDown.png") forState:UIControlStateHighlighted];
        [episodeBtn setImage:CImageMgr::GetImageEx("EpisodeBtnDown.png") forState:UIControlStateSelected];
        [episodeBtn setFrame:MoveRightRect(timeBtn.frame, 114)];
        [episodeBtn addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [episodeBtn setTag:TAG_BTN_EPISODE];
        [contentView addSubview:episodeBtn];
        
        UILabel *episodeLabel = [[UILabel alloc] initWithFrame:MoveRightRect(timeLabel.frame, 112)];
        [episodeLabel setBackgroundColor:[UIColor clearColor]];
        [episodeLabel setTextColor:UIColorFromRGBValue(0xffea3b)];
        [episodeLabel setFont:[UIFont systemFontOfSize:12]];
        [episodeLabel setTextAlignment:NSTextAlignmentCenter];
        [episodeLabel setTag:TAG_LABEL_EPISODE];
        [contentView addSubview:episodeLabel];
        
        contentView;
    });
    [[self view] addSubview:self.contentView];
    
    float width  = self.view.bounds.size.width;
    float height = self.view.bounds.size.height;
    self.timePicker = ({
        UIPickerView *timePickerView = [[UIPickerView alloc] init];
        [timePickerView setDelegate:self];
        [timePickerView setDataSource:self];
        [timePickerView setShowsSelectionIndicator:YES];
        [timePickerView setFrame:CGRectMake(0, 0, 320, pickerCellHeight)];
        [timePickerView setBackgroundColor:[UIColor whiteColor]];
        timePickerView;
    });
    self.episodePicker =({
        UIPickerView *timePickerView = [[UIPickerView alloc] init];
        [timePickerView setDelegate:self];
        [timePickerView setDataSource:self];
        [timePickerView setShowsSelectionIndicator:YES];
        [timePickerView setFrame:CGRectMake(0, 0, 320, pickerCellHeight)];
        [timePickerView setBackgroundColor:[UIColor whiteColor]];
        timePickerView;
    });
    self.toolBar = ({
        UIToolbar *toolBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0,height, width, 44)];
        UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStyleBordered target:self action:@selector(onCancel:)];
        UIBarButtonItem *fixItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        [fixItem setWidth:210];
        UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithTitle:@"确定" style:UIBarButtonItemStyleBordered target:self action:@selector(onDone:)];
        [toolBar setItems:@[leftItem,fixItem,rightItem]];
        toolBar;
    });
    
    [self showAnimation];
    [self initializeControls];
    [self refreshTimerAndEpisode];
    [self setTimer];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#pragma mark - setter
//-(void)setTimeType:(TIME_TYPE)timeType
//{
//    _timeType = timeType;
//    
//    UIButton *timeBtn = (UIButton *)[self.contentView viewWithTag:TAG_BTN_TIMER];
//    UIButton *episodeBtn = (UIButton *)[self.contentView viewWithTag:TAG_BTN_EPISODE];
//    
//    switch (_timeType) {
//        case TIME_TYPE_NONE:
//        {
//            [timeBtn setSelected:NO];
//            [episodeBtn setSelected:NO];
//        }
//            break;
//        case TIME_TYPE_TIMER:
//        {
//            [timeBtn setSelected:YES];
//            [episodeBtn setSelected:NO];
//        }
//            break;
//        case TIME_TYPE_EPISODE:
//        {
//            [timeBtn setSelected:NO];
//            [episodeBtn setSelected:YES];
//        }
//            break;
//        default:
//            break;
//    }
//}

#pragma mark
#pragma mark quick methosd

-(NSString *)getStringFromSeconds:(float)seconds
{
    unsigned mins = seconds/60;
    unsigned secs = (int)seconds%60;
    return [NSString stringWithFormat:@"%02d:%02d",mins,secs];
}
-(void)setAllButtonsEnable:(BOOL)enabled
{
    for (UIButton *btn in self.contentView.subviews) {
        if ([btn isKindOfClass:[UIButton class]]) {
            [btn setEnabled:enabled];
        }
    }
}
- (CGSize)getTextDrawSize:(NSString*) str_text{
    
    if(isIOS7()){
        NSMutableAttributedString* str_attr = nil;
        str_attr = [[NSMutableAttributedString alloc] initWithString:str_text];
        NSRange range = NSMakeRange(0, str_attr.length);
        [str_attr addAttribute:(NSString *)kCTFontAttributeName value:(id)CFBridgingRelease(CTFontCreateWithName((CFStringRef)[UIFont systemFontOfSize:17].fontName, 17, NULL)) range:range];
        
        NSDictionary* dic = [str_attr attributesAtIndex:0 effectiveRange:&range];
        return [str_text boundingRectWithSize:CGSizeMake(280, 59) options:NSStringDrawingUsesFontLeading | NSStringDrawingUsesLineFragmentOrigin attributes:dic context:nil].size;
    }else {
        return [str_text sizeWithFont:[UIFont systemFontOfSize:17] constrainedToSize:CGSizeMake(280, 59) lineBreakMode:NSLineBreakByWordWrapping];
    }
}
#pragma mark - show and hide content view
-(void)showAnimation
{
    float height = [UIScreen mainScreen].bounds.size.height;
    int gap = 0;
    if (height>480) {
        gap = 39;
    }
    self.contentView.frame = CGRectMake(128, height - 32, 64, 64);
    self.contentView.alpha = 0;
    [UIView animateWithDuration:kAnimationDuration animations:^{
        self.contentView.frame = CGRectMake(10, height/2 - 188 + gap, 300, 300);
        self.contentView.alpha = 1;
    } completion:^(BOOL finished) {
    }];
}
-(void)hideAnimation
{
    float height = [UIScreen mainScreen].bounds.size.height;
    int gap = 0;
    if (height>480) {
        gap = 39;
    }
    self.contentView.frame = CGRectMake(10, height/2 - 188 + gap, 300, 300);
    [UIView animateWithDuration:kAnimationDuration animations:^{
        self.contentView.frame = CGRectMake(128, height - 32, 64, 64);
        self.contentView.alpha = 0;
    } completion:^(BOOL finished) {
        GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
        [self willMoveToParentViewController:nil];
        [self removeFromParentViewController];
        [self.view removeFromSuperview];
        if (_refreshTimer.isValid) {
            [_refreshTimer invalidate];
        }
    }];
}
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    if (_hasPickerView) {
        UIPickerView *pickerView = nil;
        if (self.timeType == TIME_TYPE_TIMER) {
            pickerView = self.timePicker;
        }
        else{
            pickerView = self.episodePicker;
        }
        CGPoint location = [touch locationInView:pickerView];
        if (location.y < -44) {
            [self refreshTimerAndEpisode];
            [self hidePickerView];
        }
    }
    else{
        CGPoint location = [touch locationInView:self.contentView];
        if (location.x < 0 || location.y < 0 ||
            location.x > self.contentView.frame.size.width ||
            location.y > self.contentView.frame.size.height) {
            [self hideAnimation];
        }
    }
}
#pragma mark - show and hide time and episode picker
-(void)showPickerView
{
    
    UIPickerView *pickerView = nil;
    if (self.timeType == TIME_TYPE_TIMER) {
        pickerView = self.timePicker;
    }
    else{
        pickerView = self.episodePicker;
    }
    
    CGRect startFrame = pickerView.frame;
    CGRect endFrame = startFrame;
    
    // the start position is below the bottom of the visible frame
    startFrame.origin.y = self.view.frame.size.height - 44;
    
    // the end position is slid up by the height of the view
    endFrame.origin.y = startFrame.origin.y - endFrame.size.height+ 44;
    
    pickerView.frame = startFrame;
    
    CGRect toolBarStartFrame = self.toolBar.frame;
    CGRect tooBarEndFrame = self.toolBar.frame;
    
    toolBarStartFrame.origin.y = self.view.frame.size.height;
    tooBarEndFrame.origin.y = toolBarStartFrame.origin.y - endFrame.size.height-44;
    
    [self.view addSubview:pickerView];
    [self.view addSubview:self.toolBar];
    
    CGRect contentViewEndFrame = self.contentView.frame;
    contentViewEndFrame.origin.y-=110;
    
    [UIView animateWithDuration:0.25 animations: ^{
        pickerView.frame = endFrame;
        self.toolBar.frame = tooBarEndFrame;
        [self.contentView setFrame:contentViewEndFrame];
        //[self.contentView setHidden:YES];
    }
    completion:^(BOOL finished) {
        _hasPickerView = YES;
    }];
}
-(void)hidePickerView
{
    UIPickerView *pickerView = nil;
    if (self.timeType == TIME_TYPE_TIMER) {
        pickerView = self.timePicker;
    }
    else{
        pickerView = self.episodePicker;
    }
    
    CGRect startFrame = pickerView.frame;
    CGRect endFrame = startFrame;
    
    endFrame.origin.y = startFrame.origin.y + endFrame.size.height + 44;
    
    CGRect toolBarStartFrame = self.toolBar.frame;
    CGRect tooBarEndFrame = self.toolBar.frame;
    
    tooBarEndFrame.origin.y = toolBarStartFrame.origin.y + endFrame.size.height;
    
    CGRect contentViewEndFrame = self.contentView.frame;
    contentViewEndFrame.origin.y+=110;
    
    [UIView animateWithDuration:0.25 animations: ^{
        pickerView.frame = endFrame;
        self.toolBar.frame = tooBarEndFrame;
        [self.contentView setFrame:contentViewEndFrame];
        //[self.contentView setHidden:NO];
    }
    completion:^(BOOL finished) {
        [pickerView removeFromSuperview];
        [self.toolBar removeFromSuperview];
        _hasPickerView = NO;
    }];
}

#pragma mark - change controls
/*
 三种情况会导致control的改变
 1,viewdidload之后的初始化
 2，play时候的进度以及缓冲的
 3，一首作品播放完毕进入下一首
 其中1和3都调用initializeControl，2调用refreshProgress
 initializeControl负责作品信息相关的内容的更改
 refreshProgress只负责进度相关的改变
 */
-(void)initializeControls
{
    CChapterInfo *chapInfo = CPlayBookList::getInstance()->getCurChapter();

    if (chapInfo != NULL) {
        _hasCollected = CCollectBookList::GetInstance()->GetCurBook([[NSString stringWithUTF8String:chapInfo->m_strBookId.c_str()] intValue]) != NULL;
        _hasDownLoad = CBookManagement::GetInstance()->GetChapterInfo(chapInfo->m_strBookId, chapInfo->m_unRid) != NULL;
        
        UIButton *collectBtn  = (UIButton *)[self.contentView viewWithTag:TAG_BTN_COLLECT];
        UIButton *downloadBtn = (UIButton *)[self.contentView viewWithTag:TAG_BTN_DOWNLOAD];
        UIButton *playBtn = (UIButton *)[self.contentView viewWithTag:TAG_BTN_PLAY];
        NSString *title = [NSString stringWithUTF8String:CPlayBookList::getInstance()->getCurChapter()->m_strName.c_str()];
        CGSize size = [self getTextDrawSize:title];
        CGRect beforeFrame = self.nameLabel.frame;
        beforeFrame.size.height = size.height;
        [self.nameLabel setFrame:beforeFrame];
        [self.nameLabel setText:[NSString stringWithUTF8String:CPlayBookList::getInstance()->getCurChapter()->m_strName.c_str()]];
        [self.totalTimeLabel setText:[self getStringFromSeconds:CAudioPlayerManager::getInstance()->duration()]];
        
        [collectBtn setSelected:_hasCollected];
        if (_hasDownLoad) {
            [downloadBtn setImage:CImageMgr::GetImageEx("DownloadBtnDown.png") forState:UIControlStateDisabled];
            [downloadBtn setEnabled:NO];//不能取消下载
        }
        else{
            [downloadBtn setEnabled:YES];
        }
        
        if (CAudioPlayerManager::getInstance()->getCurPlayState() == E_AUDIO_PLAY_PLAYING) {
            [playBtn setSelected:YES];
        }
        else{
            [playBtn setSelected:NO];
        }
        [self refreshProgress];
    }
    else{
        [self setAllButtonsEnable:NO];
    }
}
-(void)refreshTimerAndEpisode
{
    UIButton *timeBtn = (UIButton *)[self.contentView viewWithTag:TAG_BTN_TIMER];
    UIButton *episodeBtn = (UIButton *)[self.contentView viewWithTag:TAG_BTN_EPISODE];
    UILabel  *timeLabel = (UILabel *)[self.contentView viewWithTag:TAG_LABEL_TIMER];
    UILabel  *episodeLabel = (UILabel *)[self.contentView viewWithTag:TAG_LABEL_EPISODE];
    
    if ([[KBSetTimming sharedInstance] isTimingSet]) {
        int timeLeft = [[KBSetTimming sharedInstance] getLeftTime];
        if (timeLeft > 0) {
            [timeBtn setSelected:YES];
            [episodeBtn setSelected:NO];
            [timeLabel setTextColor:UIColorFromRGBValue(0x0089d0)];
            [episodeLabel setTextColor:[UIColor whiteColor]];
            [timeLabel setText:[NSString stringWithFormat:@"%d分钟后停止",timeLeft]];
            [episodeLabel setText:@"定集停止"];
        }
        else{
            [timeBtn setSelected:NO];
            [timeLabel setTextColor:[UIColor whiteColor]];
            [timeLabel setText:@"定时停止"];
        }
    }
    else{
        if (CAudioPlayerManager::getInstance()->isChapterTimerSet()) {
            int chapterLeft =CAudioPlayerManager::getInstance()->chapterLeft();
            if (chapterLeft > 0) {
                [timeBtn setSelected:NO];
                [episodeBtn setSelected:YES];
                [timeLabel setTextColor:[UIColor whiteColor]];
                [timeLabel setText:@"定时停止"];
                [episodeLabel setTextColor:UIColorFromRGBValue(0x0089d0)];
                [episodeLabel setText:[NSString stringWithFormat:@"%d集播完停止",chapterLeft]];
            }
            else{
                [episodeBtn setSelected:NO];
                [episodeLabel setTextColor:[UIColor whiteColor]];
                [episodeLabel setText:@"定集停止"];
            }
        }
        else{
            [timeBtn setSelected:NO];
            [episodeBtn setSelected:NO];
            [timeLabel setTextColor:[UIColor whiteColor]];
            [episodeLabel setTextColor:[UIColor whiteColor]];
            [timeLabel setText:@"定时停止"];
            [episodeLabel setText:@"定集停止"];
        }
    }
}
-(void)refreshProgress
{
    
    float bufferRadio = CAudioPlayerManager::getInstance()->bufferRation();
    float width = bufferRadio * kProgressWidth;
    CGRect rect = self.bufferProgressView.frame;
    if (((int)width) != ((int)rect.size.width)) {
        rect.size.width = width;
        [self.bufferProgressView setFrame:rect];
    }
    [self.playTimeLabel setText:[self getStringFromSeconds:CAudioPlayerManager::getInstance()->currentTime()]];
        
    float currentTime = CAudioPlayerManager::getInstance()->currentTime();
    float totalTime   = CAudioPlayerManager::getInstance()->duration();
    if (totalTime != 0) {
        float fPercent = currentTime / totalTime;
        [self.playSlider setValue:fPercent animated:YES];
    }
}

#pragma mark
#pragma mark action methods

-(void)onBtnClick:(id)sender
{
    bool b_flow_protect = false;
    KwConfig::GetConfigureInstance()->GetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, b_flow_protect);
    
    if (_hasPickerView) {
        [self refreshTimerAndEpisode];
        [self hidePickerView];
        return;
    }
    
    [self resetTimer];
    UIButton *button = sender;
    
    switch (button.tag) {
        case TAG_BTN_DETAIL:
        {
            UMengLog(KB_PLAY_CONTROL, "detail");
            [self hideAnimation];
            if(!_isFromTheSameBook){
                std::string bookId  = CPlayBookList::getInstance()->getCurChapter()->m_strBookId;
                CBookInfo *bookInfo = CBookInfoList::getInstance()->getBookInfo(bookId);
                KBBookDetailViewController *detailViewController = [[KBBookDetailViewController alloc] initWithBookInfo:bookInfo];
                [ROOT_NAVI_CONTROLLER pushAddButtonViewController:detailViewController animated:YES];
            }
            break;
        }
        case TAG_BTN_COLLECT:
        {
            UMengLog(KB_PLAY_CONTROL, "collect");
            std::string bookId  = CPlayBookList::getInstance()->getCurChapter()->m_strBookId;
            CBookInfo *bookInfo = CBookInfoList::getInstance()->getBookInfo(bookId);
            if (bookInfo) {
                _hasCollected = !_hasCollected;
                [button setSelected:_hasCollected];
                if (_hasCollected) {
                    CCollectBookList::GetInstance()->AddBookInfo((CRecentBookInfo *)bookInfo);
                    [iToast defaultShow:@"已收藏"];
                }
                else{
                    CCollectBookList::GetInstance()->DeleteBookInfo([[NSString stringWithFormat:@"%s",bookId.c_str()] intValue]);
                    [iToast defaultShow:@"取消收藏"];
                }
            }
            break;
        }
        case TAG_BTN_DOWNLOAD:
        {
            UMengLog(KB_PLAY_CONTROL, "download");
            if (CHttpRequest::GetNetWorkStatus() == NETSTATUS_NONE) {
                [iToast defaultShow:@"网络似乎断开了，请检查连接"];
                return;
            }
            
            bool b_flow_protect = false;
            KwConfig::GetConfigureInstance()->GetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, b_flow_protect);
            if(b_flow_protect && NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus()){
                UIAlertView* alert_view = [[UIAlertView alloc] initWithTitle:nil message:@"现在下载会自动关闭流量保护模式，下载会消耗流量" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"现在下载", nil];
                [alert_view setTag:TAG_ALERT_DOWNLOAD];
                [alert_view show];
            } else {
                CChapterInfo *chapInfo = CPlayBookList::getInstance()->getCurChapter();
                CLocalBookRequest::GetInstance()->StartDownTask(chapInfo);
                [iToast defaultShow:@"已加入下载列表"];
                _hasDownLoad = !_hasDownLoad;
                if (_hasDownLoad) {
                    UIButton* button = (UIButton*)[self.view viewWithTag:TAG_BTN_DOWNLOAD];
                    [button setImage:CImageMgr::GetImageEx("DownloadBtnDown.png") forState:UIControlStateDisabled];
                    [button setEnabled:NO];//不能取消下载
                }
            }
            
            break;
        }
        case TAG_BTN_LAST:
        {
            UMengLog(KB_PLAY_CONTROL, "pre");
            
            CChapterInfo* pre_chapter = CPlayBookList::getInstance()->getPreChapter();
            if (b_flow_protect && (NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus() && pre_chapter && !CPlayBookList::getInstance()->iSLocalChapter(pre_chapter))) {
                UIAlertView* alert_view = [[UIAlertView alloc] initWithTitle:nil message:@"继续播放会自动关闭流量保护模式，播放会消耗流量" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"继续播放", nil];
                [alert_view setTag:TAG_ALERT_PRE];
                [alert_view show];
            }else if(NULL != pre_chapter){
                CAudioPlayerManager::getInstance()->playPreChapter();
            }
            
            
            break;
        }
        case TAG_BTN_PLAY:
        {
            UMengLog(KB_PLAY_CONTROL, "play");
            if (CAudioPlayerManager::getInstance()->getCurPlayState() == E_AUDIO_PLAY_PLAYING) {
                CAudioPlayerManager::getInstance()->pause();
                [button setSelected:NO];
            }
            else if (CAudioPlayerManager::getInstance()->getCurPlayState() == E_AUDIO_PLAY_PAUSE){
                CChapterInfo* cur_chapter = CPlayBookList::getInstance()->getCurChapter();
                if (b_flow_protect && (NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus() && cur_chapter && !CPlayBookList::getInstance()->iSLocalChapter(cur_chapter))) {
                    UIAlertView* alert_view = [[UIAlertView alloc] initWithTitle:nil message:@"继续播放会自动关闭流量保护模式，播放会消耗流量" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"继续播放", nil];
                    [alert_view setTag:TAG_ALERT_CUR_RESUME];
                    [alert_view show];
                }else {
                    CAudioPlayerManager::getInstance()->resume();
                    [button setSelected:YES];
                }
            }
            else{
                CChapterInfo* cur_chapter = CPlayBookList::getInstance()->getCurChapter();
                if (b_flow_protect && (NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus() && cur_chapter && !CPlayBookList::getInstance()->iSLocalChapter(cur_chapter))) {
                    UIAlertView* alert_view = [[UIAlertView alloc] initWithTitle:nil message:@"继续播放会自动关闭流量保护模式，播放会消耗流量" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"继续播放", nil];
                    [alert_view setTag:TAG_ALERT_CUR];
                    [alert_view show];
                }else {
                    CAudioPlayerManager::getInstance()->play();
                    [button setSelected:YES];
                }
            }
            break;
        }
        case TAG_BTN_NEXT:
        {
            UMengLog(KB_PLAY_CONTROL, "next");
            CChapterInfo* next_chapter = CPlayBookList::getInstance()->getNextChapter();
            if (b_flow_protect && (NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus() && next_chapter && !CPlayBookList::getInstance()->iSLocalChapter(next_chapter))) {
                UIAlertView* alert_view = [[UIAlertView alloc] initWithTitle:nil message:@"继续播放会自动关闭流量保护模式，播放会消耗流量" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"继续播放", nil];
                [alert_view setTag:TAG_ALERT_NEXT];
                [alert_view show];
            }else {
                CAudioPlayerManager::getInstance()->playNextChapter();
            }
            break;
        }
        case TAG_BTN_TIMER:
        {
            [self setTimeType:TIME_TYPE_TIMER];
            [self showPickerView];
            break;
        }
        case TAG_BTN_EPISODE:
        {
            [self setTimeType:TIME_TYPE_EPISODE];
            [self showPickerView];
            break;
        }
        default:
            break;
    }
}
-(void)onSliderChanged:(id)sender
{
    UMengLog(KB_PLAY_CONTROL, "seek");
    [self resetTimer];
    UISlider *slider = sender;
    float fPercent = slider.value;
    float totalTime = CAudioPlayerManager::getInstance()->duration();
    float seekTime = totalTime * fPercent;
    CAudioPlayerManager::getInstance()->seek(seekTime);
}
-(void)onDone:(id)sender
{
    if (_timeType == TIME_TYPE_TIMER) {
        int row = [self.timePicker selectedRowInComponent:0];
        if (row >= 0 && row < self.timeData.count) {
            [[KBSetTimming sharedInstance] setTimming:[[self.timeData objectAtIndex:row] integerValue]];
            CAudioPlayerManager::getInstance()->setChapterTimming(0);
        }
    }
    else if (_timeType == TIME_TYPE_EPISODE){
        int row = [self.episodePicker selectedRowInComponent:0];
        if (row >= 0 && row < self.episodeData.count) {
            [[KBSetTimming sharedInstance] setTimming:0];
            CAudioPlayerManager::getInstance()->setChapterTimming([self.episodeData[row] integerValue]);
        }
    }
    [self refreshTimerAndEpisode];
    [self hidePickerView];
}
-(void)onCancel:(id)sender
{
    [self refreshTimerAndEpisode];
    [self hidePickerView];
}
#pragma mark
#pragma mark timer methods

-(void)setTimer
{
    //_closeTimer = [NSTimer scheduledTimerWithTimeInterval:kTimeToClose target:self selector:@selector(onCloseTimer) userInfo:nil repeats:YES];
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:kTimeToRefresh target:self selector:@selector(refreshProgress) userInfo:nil repeats:YES];
    [_refreshTimer fire];
}
-(void)onCloseTimer
{
    [self hideAnimation];
}
-(void)resetTimer
{
    if (_closeTimer) {
        [_closeTimer invalidate];
        [self setTimer];
    }
}
#pragma mark - picker view data source

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if (self.timeType == TIME_TYPE_TIMER) {
        return self.timeDataText.count;
    }
    else if (self.timeType == TIME_TYPE_EPISODE){
        return self.episodeDataText.count;
    }
    else{
        return 0;
    }
}
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    if (self.timeType == TIME_TYPE_TIMER) {
        return self.timeDataText[row];
    }
    else if (self.timeType == TIME_TYPE_EPISODE){
        return self.episodeDataText[row];
    }
    else{
        return nil;
    }
}
#pragma mark - picker view delegate
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    UIButton *timeBtn = (UIButton *)[self.contentView viewWithTag:TAG_BTN_TIMER];
    UIButton *episodeBtn = (UIButton *)[self.contentView viewWithTag:TAG_BTN_EPISODE];
    UILabel  *timeLabel = (UILabel *)[self.contentView viewWithTag:TAG_LABEL_TIMER];
    UILabel  *episodeLabel = (UILabel *)[self.contentView viewWithTag:TAG_LABEL_EPISODE];
    
    if (pickerView == self.timePicker) {
        if (row > 0) {
            [timeBtn setSelected:YES];
            [episodeBtn setSelected:NO];
            [timeLabel setTextColor:UIColorFromRGBValue(0x0089d0)];
            [timeLabel setText:[self.timeDataLabelText objectAtIndex:row]];
            [episodeLabel setTextColor:[UIColor whiteColor]];
            [episodeLabel setText:@"定集停止"];
        }
        else{
            [timeBtn setSelected:NO];
            [timeLabel setTextColor:[UIColor whiteColor]];
            [timeLabel setText:@"定时停止"];
        }
    }
    else{
        if (row > 0) {
            [timeBtn setSelected:NO];
            [episodeBtn setSelected:YES];
            [timeLabel setTextColor:[UIColor whiteColor]];
            [timeLabel setText:@"定时停止"];
            [episodeLabel setTextColor:UIColorFromRGBValue(0x0089d0)];
            [episodeLabel setText:[self.episodeDataLabelText objectAtIndex:row]];
        }
        else{
            [episodeBtn setSelected:NO];
            [episodeLabel setTextColor:[UIColor whiteColor]];
            [episodeLabel setText:@"定集停止"];
        }
    }
}
#pragma mark
#pragma mark observer methosd

-(void)IObserverAudioPlayStateChanged:(AudioPlayState)enumStatus
{
//    if (enumStatus != E_AUDIO_PLAY_NONE) {
//        [self setAllButtonsEnable:YES];
//    }
    UIButton *playBtn = (UIButton *)[self.contentView viewWithTag:TAG_BTN_PLAY];
    if (enumStatus == E_AUDIO_PLAY_PLAYING) {
        [self initializeControls];
        [playBtn setSelected:YES];
    }
    else{
        [playBtn setSelected:NO];
    }
}
-(void)IObserverTimmingLeft:(int)nMinLeft
{
    [self refreshTimerAndEpisode];
}
-(void)IObserverChapterLeft:(int)nChapterLeft
{
    [self refreshTimerAndEpisode];
}

#pragma mark alert view delegate

-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
    if (1 == buttonIndex) {
        KwConfig::GetConfigureInstance()->SetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, false);
        
        switch (alertView.tag) {
            case TAG_ALERT_PRE:
            {
                CAudioPlayerManager::getInstance()->playPreChapter();
                break;
            }
                
            case TAG_ALERT_CUR:
            {
                CAudioPlayerManager::getInstance()->play();
                break;
            }
                
            case TAG_ALERT_NEXT:
            {
                CAudioPlayerManager::getInstance()->playNextChapter();
                break;
            }
            case TAG_ALERT_CUR_RESUME:
            {
                CAudioPlayerManager::getInstance()->resume();
                break;
            }
                
            case TAG_ALERT_DOWNLOAD:
            {
                CChapterInfo *chapInfo = CPlayBookList::getInstance()->getCurChapter();
                CLocalBookRequest::GetInstance()->StartDownTask(chapInfo);
                [iToast defaultShow:@"已加入下载列表"];
                _hasDownLoad = !_hasDownLoad;
                if (_hasDownLoad) {
                    UIButton* button = (UIButton*)[self.view viewWithTag:TAG_BTN_DOWNLOAD];
                    [button setImage:CImageMgr::GetImageEx("DownloadBtnDown.png") forState:UIControlStateDisabled];
                    [button setEnabled:NO];//不能取消下载
                }
                
                break;
            }
                
            default:
                break;
        }
        SYN_NOTIFY(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect::FlowProtectStatusChange, false);
    }
}

@end
