//
//  KBBookDetailViewController.m
//  kwbook
//
//  Created by 单 永杰 on 13-12-9.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import "KBBookDetailViewController.h"
#include "globalm.h"
#include "ImageMgr.h"
#include "CollectBookList.h"
#include "CacheMgr.h"
#include "ChapterInfo.h"
#include "PlayBookList.h"
#include "LocalBookRequest.h"
#include <vector>
#import <CoreText/CoreText.h>
#include "KwTools.h"
#include "MessageManager.h"
#include <string>
#include <zlib.h>
#import "GDataXMLNode.h"
#include "PlayBookList.h"
#include "AudioPlayerManager.h"
#include "RecentBookList.h"
#include "KBAppDelegate.h"
#include "BookInfoList.h"

#import "iToast.h"
#include "KwUMengElement.h"
#include "UMengLog.h"
#include "BookManagement.h"
#include "IObserverDownTaskStatus.h"
#import "HttpRequest.h"
#import "KBUrls.h"
#import "KuwoConstants.h"
#import "UIImageView+LBBlurredImage.h"

#include "KwConfig.h"
#include "KwConfigElements.h"
#include "IObserverFlowProtect.h"

#import "KBAlertView.h"


#define TAG_BTN_PLAYLIST           100
#define TAG_BTN_QUICK_DOWNLOAD     102

#define TAG_BTN_BACK      103
#define TAG_BTN_CARE      104
#define TAG_BTN_DETAIL    105
#define TAG_BTN_PLAY      106

#define TAG_TAB_PLAYLIST  107
#define TAG_TAB_DOWNLIST  108
#define TAG_TAB_QUICKDOWN 109

#define TAG_BTN_DOWNLOAD  110
#define TAG_LAB_DOWN_STATUS 111

#define TAG_BTN_QUICKDOWN_FIRST  115
#define TAG_BTN_QUICKDOWN_SECOND 116
#define TAG_BTN_QUICKDOWN_THIRD  117
#define TAG_BTN_DOWNALL          118

#define TAG_CHAPTER_TITLE   119
#define TAG_CHAPTER_ARTIST  120

#define TAG_SUMMARY_LABEL   121

#define TAG_LAB_PROMPT      122

#define TAG_BTN_PROMPT      123

#define TAG_ALERT_FLOW_PROTECT_PLAY 124
#define TAG_ALERT_FLOW_PROTECT_QUICK_DOWNLOAD 125
#define TAG_ALERT_FLOW_PROTECT_DOWNLOAD 126

#define TAG_ALERT_QUICK_DOWN_CONFIRM   127


#define COLOR_FONT_BLUE 0x028bd0
#define COLOR_FONT_GRAY 0x515151

#define CACHEOUTTIME    (30*24*60*60) // 30天
#define ZLIB_REF_LEN 4

std::string STR_PLAY_SOURCE_TYPE[] = {
    "new_reco",
    "hot_reco",
    "rank_reco",
    "category",
    "search",
    "download",
    "collect",
    "history"
};

static bool s_b_btn_back = false;

static KwTools::CLock s_chapter_list_lock;

@interface KBBookDetailViewController ()<UITableViewDataSource, UITableViewDelegate, IObserverAudioPlayState, IObserverDownTaskStatus, UIAlertViewDelegate>{
    CBookInfo m_bookInfo;
    NSMutableArray* array_chapter_info;
    BOOL m_bIntroductionOpend;
    std::vector<CChapterInfo*> m_vecChapterList;
    int m_nChapterDownTitleSize;
    
    float _lastOffset;
    BOOL _isDraging;
    BOOL _isScrolling;
    PLAY_SOURCE_TYPE m_ePlaySource_type;
    BOOL m_bSendUmengLog;
    
    BOOL m_bAllDownClicked;
    
    UIButton* m_curDownBtn;
    
    NSIndexPath* m_curIndexPath;
}

@property (nonatomic, strong) UIImageView* backView;
@property (nonatomic, strong) UITableView* tableViewPlay;
@property (nonatomic, strong) UITableView* tableViewDownload;
@property (nonatomic, strong) UITableView* tableViewQuickDownload;
@property (nonatomic, strong) UIView*      topBar;
@property (nonatomic, strong) UIImageView* book_image;
@property (nonatomic, strong) UIView*      view_book_intro;

@property (nonatomic, strong) UIView*      tab_bar_view;
@property (nonatomic, strong) UITableView* table_chapter_list;
@property (nonatomic, strong) UITableView* table_quickdown_list;
@property (nonatomic, strong) UIImageView* open_flag_view;
@property (nonatomic, strong) UIView*      activity_view;
@property (nonatomic, strong) UIView*      activity_background_view;
@property (nonatomic, strong) UIActivityIndicatorView* indicator_view;

@property (nonatomic, strong) UIView*      prompt_view;

@end

@implementation KBBookDetailViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _lastOffset = 0.0f;
        _isDraging = NO;
        m_bAllDownClicked = false;
        s_b_btn_back = false;
        m_curDownBtn = nil;
    }
    return self;
}

-(id)initWithBookInfo : (CBookInfo*)book_info{
    self = [super init];
    
    m_bookInfo = *book_info;
    CBookInfoList::getInstance()->addBook(book_info);
    m_vecChapterList.clear();
    
//    [self getChapterList];
    
    GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
    GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus);
    
    return self;
}
-(std::string)theBookId;
{
    return m_bookInfo.m_strBookId;
}
-(void)setPlaySource : (PLAY_SOURCE_TYPE)e_source_type{
    m_ePlaySource_type = e_source_type;
    m_bSendUmengLog = false;
}

-(void)dealloc{
    for (std::vector<CChapterInfo*>::iterator iter = m_vecChapterList.begin(); iter != m_vecChapterList.end(); ++iter) {
        delete *iter;
        *iter = NULL;
    }
    m_vecChapterList.clear();
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
//    m_bookInfo.m_unCount = 99;
//    m_bookInfo.m_unType = 2;
    CLocalBookRequest::GetInstance();
    
    float gap = 0.0;
    if (isIOS7()) {
        gap = 20;
    }
    float width  = self.view.bounds.size.width;
    
    [self.view setBackgroundColor:UIColorFromRGBValue(0xf0ebe3)];
    self.topBar = ({
        UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 134+gap)];
        
//        [topBar setBackgroundColor:UIColorFromRGBValue(0xf9f6ef)];
        _backView = [[UIImageView alloc] initWithFrame:topBar.bounds];
        
        UIView* template_view = [[UIView alloc] initWithFrame:topBar.bounds];
        [template_view setBackgroundColor:[UIColor blackColor]];
        template_view.alpha = 0.15;

        [topBar addSubview:_backView];
        
        [topBar addSubview:template_view];
        
        UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [backBtn setImage:CImageMgr::GetImageEx("TopBackBtn.png") forState:UIControlStateNormal];
        [backBtn setFrame:CGRectMake(0, gap, 44, 44)];
        [backBtn setTag:TAG_BTN_BACK];
        [backBtn addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [topBar addSubview:backBtn];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(30, gap, 250, 44)];

        [titleLabel setText:[NSString stringWithUTF8String:m_bookInfo.m_strBookTitle.c_str()]];
        [titleLabel setShadowColor:[UIColor colorWithWhite:0.0 alpha:0.2]];
        [titleLabel setShadowOffset:CGSizeMake(1.0f, 1.0f)];
        [titleLabel setBackgroundColor:[UIColor clearColor]];
        [titleLabel setTextAlignment:NSTextAlignmentCenter];
        [titleLabel setTextColor:[UIColor whiteColor]];
        [titleLabel setFont:[UIFont systemFontOfSize:20.0]];
        [topBar addSubview:titleLabel];
        
        UIButton *careBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        
        if (CCollectBookList::GetInstance()->GetCurBook([[NSString stringWithFormat:@"%s", m_bookInfo.m_strBookId.c_str()] intValue])) {
            [careBtn setImage:CImageMgr::GetImageEx("BookDetailCared.png") forState:UIControlStateNormal];
        }else {
            [careBtn setImage:CImageMgr::GetImageEx("BookDetailUnCared.png") forState:UIControlStateNormal];
        }
        
        [careBtn setFrame:CGRectMake(281, gap + 7, 29, 27.5)];
        [careBtn setTag:TAG_BTN_CARE];
        [careBtn addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [topBar addSubview:careBtn];
        
        UIImageView* background_view = [[UIImageView alloc] initWithFrame:CGRectMake(12.5, gap + 56.5, 69, 69)];
        [background_view setImage:CImageMgr::GetImageEx("BookPicBack.png")];
        _book_image = [[UIImageView alloc] initWithFrame:CGRectMake(4.5, 4.5, 60, 60)];
        [_book_image setImage:CImageMgr::GetImageEx("DefaultBookImageSmall.png")];
        [background_view addSubview:_book_image];
        
        [self startLoadImage:[NSString stringWithUTF8String:m_bookInfo.m_strImgUrl.c_str()]];
        [topBar addSubview:background_view];
        
        UILabel* label_artist = [[UILabel alloc] initWithFrame:CGRectMake(90, gap + 58, 200, 16)];
        [label_artist setBackgroundColor:[UIColor clearColor]];
        [label_artist setTextColor:[UIColor whiteColor]];
        [label_artist setShadowColor:[UIColor colorWithWhite:0.0 alpha:0.2]];
        [label_artist setShadowOffset:CGSizeMake(1.0f, 1.0f)];
        [label_artist setFont:[UIFont systemFontOfSize:14]];
        [label_artist setText:[NSString stringWithFormat:@"播讲人: %@", [NSString stringWithUTF8String:m_bookInfo.m_strArtist.c_str()]]];
        [topBar addSubview:label_artist];
        
        UILabel* label_listen_cnt = [[UILabel alloc] initWithFrame:CGRectMake(90, gap + 98, 200, 16)];
        [label_listen_cnt setBackgroundColor:[UIColor clearColor]];
        [label_listen_cnt setTextColor:[UIColor whiteColor]];
        [label_listen_cnt setShadowColor:[UIColor colorWithWhite:0.0 alpha:0.2]];
        [label_listen_cnt setShadowOffset:CGSizeMake(1.0f, 1.0f)];
        [label_listen_cnt setFont:[UIFont systemFontOfSize:14]];
        [label_listen_cnt setText:[NSString stringWithFormat:@"人气: %d人在听", m_bookInfo.m_unListenCnt]];
        [topBar addSubview:label_listen_cnt];
        
        UILabel* label_chapter_cnt = [[UILabel alloc] initWithFrame:CGRectMake(90, gap + 78, 200, 16)];
        [label_chapter_cnt setBackgroundColor:[UIColor clearColor]];
        [label_chapter_cnt setTextColor:[UIColor whiteColor]];
        [label_chapter_cnt setShadowColor:[UIColor colorWithWhite:0.0 alpha:0.2]];
        [label_chapter_cnt setShadowOffset:CGSizeMake(1.0f, 1.0f)];
        [label_chapter_cnt setFont:[UIFont systemFontOfSize:14]];
        [label_chapter_cnt setText:[NSString stringWithFormat:@"章节: 共%d回", m_bookInfo.m_unCount]];
        [topBar addSubview:label_chapter_cnt];
        
        UIButton* btn_play = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn_play setFrame:CGRectMake(277, gap + 83, 34, 34)];
        [btn_play setImage:CImageMgr::GetImageEx("BookDetailPlayUp.png") forState:UIControlStateNormal];
        [btn_play setImage:CImageMgr::GetImageEx("BookDetailPlayDown.png") forState:UIControlStateHighlighted];
        [btn_play setBackgroundColor:[UIColor clearColor]];
        [btn_play setTag:TAG_BTN_PLAY];
        [btn_play addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [topBar addSubview:btn_play];
        
        topBar;
    });
    
    [[self view] addSubview:self.topBar];
    
    m_bIntroductionOpend = NO;
    
    _view_book_intro = [[UIView alloc] initWithFrame:CGRectMake(11, _topBar.frame.size.height + 10, 300, 35)];
    
    [_view_book_intro setBackgroundColor:[UIColor clearColor]];
    
    [self resizeBookIntroduction];
    
    [self.view addSubview:_view_book_intro];

    _tab_bar_view = [[UIView alloc] initWithFrame:CGRectMake(0, _view_book_intro.frame.origin.y + _view_book_intro.frame.size.height + 5, 320, 44)];
    UIImageView* background_image = [[UIImageView alloc] initWithImage:CImageMgr::GetImageEx("BookDetailTabBar.png")];
    background_image.frame = CGRectMake(0, 0, 320, 44);
    [_tab_bar_view addSubview:background_image];
    
    _open_flag_view = [[UIImageView alloc] initWithImage:CImageMgr::GetImageEx("BookDetailClick.png")];
    _open_flag_view.frame = CGRectMake(66, 38, 14, 6);
    [_tab_bar_view addSubview:_open_flag_view];
    
    UIButton* btn_play_tab = [UIButton buttonWithType:UIButtonTypeCustom];
    btn_play_tab.frame = CGRectMake(1, 1, 158, 43);
    [btn_play_tab setTag:TAG_BTN_PLAYLIST];
    [btn_play_tab addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [btn_play_tab setBackgroundColor:[UIColor clearColor]];
    [btn_play_tab setTitle:@"播放" forState:UIControlStateNormal];
    [btn_play_tab setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
    [_tab_bar_view addSubview:btn_play_tab];
    
    
    UIButton* btn_quickdown_tab = [UIButton buttonWithType:UIButtonTypeCustom];
    btn_quickdown_tab.frame = CGRectMake(161, 1, 158, 43);
    [btn_quickdown_tab setTag:TAG_BTN_QUICK_DOWNLOAD];
    [btn_quickdown_tab addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [btn_quickdown_tab setBackgroundColor:[UIColor clearColor]];
    [btn_quickdown_tab setTitle:@"批量下载" forState:UIControlStateNormal];
    [btn_quickdown_tab setTitleColor:UIColorFromRGBValue(COLOR_FONT_GRAY) forState:UIControlStateNormal];
    [_tab_bar_view addSubview:btn_quickdown_tab];
    
    [self.view addSubview:_tab_bar_view];
    
    _table_chapter_list = [[UITableView alloc] initWithFrame:CGRectMake(0, _tab_bar_view.frame.origin.y + 45, 320, self.view.frame.size.height - _tab_bar_view.frame.origin.y - 45) style:UITableViewStylePlain];
    [_table_chapter_list setBackgroundColor:[UIColor clearColor]];
    [_table_chapter_list setTag:TAG_TAB_PLAYLIST];
    _table_chapter_list.allowsSelection = YES;
    [_table_chapter_list setDataSource:self];
    [_table_chapter_list setDelegate:self];
//    [self.view addSubview:_table_chapter_list];
    
    _table_quickdown_list = [[UITableView alloc] initWithFrame:CGRectMake(0, _tab_bar_view.frame.origin.y + 45, 320, self.view.frame.size.height - _tab_bar_view.frame.origin.y - 45) style:UITableViewStylePlain];
    [_table_quickdown_list setBackgroundColor:[UIColor clearColor]];
    [_table_quickdown_list setTag:TAG_TAB_QUICKDOWN];
    _table_quickdown_list.allowsSelection = NO;
    [_table_quickdown_list setHidden:YES];
    [_table_quickdown_list setDataSource:self];
    [_table_quickdown_list setDelegate:self];
    _table_quickdown_list.separatorStyle = UITableViewCellSeparatorStyleNone;
//    [self.view addSubview:_table_quickdown_list];
    [self.view addSubview:_table_chapter_list];
    [self.view addSubview:_table_quickdown_list];
    
    _activity_view = [[UIView alloc] initWithFrame:_table_chapter_list.frame];
    [_activity_view setBackgroundColor:[UIColor clearColor]];
    _activity_background_view = [[UIView alloc] initWithFrame:CGRectMake((_activity_view.frame.size.width - 86) / 2, 0, 86, 86)];
    [_activity_background_view setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.5]];
    _activity_background_view.layer.cornerRadius = 10;
    _activity_background_view.layer.masksToBounds = YES;
    [_activity_view addSubview:_activity_background_view];
    _indicator_view = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyleWhiteLarge)];
    _indicator_view.frame = CGRectMake(26, 16, 34, 34);
    [_activity_background_view addSubview:_indicator_view];
    [_activity_view setHidden:YES];
    [self.view addSubview:_activity_view];
    UILabel* label_promp = [[UILabel alloc] initWithFrame:CGRectMake(0, 50, 86, 30)];
    [label_promp setBackgroundColor:[UIColor clearColor]];
    [label_promp setFont:[UIFont systemFontOfSize:13]];
    [label_promp setTextColor:[UIColor whiteColor]];
    [label_promp setTextAlignment:NSTextAlignmentCenter];
    [label_promp setText:@"正在加载"];
    [label_promp setTag:TAG_LAB_PROMPT];
    [_activity_background_view addSubview:label_promp];
    
    [_activity_view setFrame:_table_chapter_list.frame];
    
    _prompt_view = [[UIView alloc] initWithFrame:_table_chapter_list.frame];
    [_prompt_view setBackgroundColor:[UIColor clearColor]];
    UILabel* label_prompt_info = [[UILabel alloc] initWithFrame:CGRectMake(60, 55, 200, 20)];
    [label_prompt_info setBackgroundColor:[UIColor clearColor]];
    [label_prompt_info setTextColor:defaultGrayColor()];
    [label_prompt_info setText:@"章节加载失败，点击重试"];
    [_prompt_view addSubview:label_prompt_info];
    UIButton* btn_prompt = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn_prompt setFrame:CGRectMake(0, 0, _table_chapter_list.frame.size.width, _table_chapter_list.frame.size.height)];
    [btn_prompt setBackgroundColor:[UIColor clearColor]];
    [btn_prompt addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [btn_prompt setTag:TAG_BTN_PROMPT];
    [_prompt_view addSubview:btn_prompt];
    [self.view addSubview:_prompt_view];
    [_prompt_view setHidden:YES];
    
    [_indicator_view startAnimating];
    [_activity_view setHidden:NO];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([self getChapterList]) {
            if (s_b_btn_back) {
                return ;
            }
            dispatch_sync(dispatch_get_main_queue(), ^{
                [_table_quickdown_list reloadData];
                [_table_chapter_list reloadData];
                
                [_indicator_view stopAnimating];
                [_activity_view setHidden:YES];
                
                UILabel* label = (UILabel*)[_activity_view viewWithTag:TAG_LAB_PROMPT];
                if (label) {
                    [label setText:@"正在缓冲"];
                }
                
                if (CPlayBookList::getInstance()->getCurChapter() && CPlayBookList::getInstance()->getCurChapter()->m_strBookId == m_bookInfo.m_strBookId) {
                    int n_total = m_vecChapterList.size();
                    int n_cur_chapter = -1;
                    for (int n_itr = 0; n_itr < n_total; ++n_itr) {
                        if (CPlayBookList::getInstance()->getCurChapter()->m_unRid == m_vecChapterList[n_itr]->m_unRid) {
                            n_cur_chapter = n_itr;
                            break;
                        }
                    }
                    if (-1 != n_cur_chapter) {
                        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:n_cur_chapter inSection:0];
                        [_table_chapter_list scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
                        [_table_chapter_list reloadData];
                    }
                }
            });
        }
    });
    [self sendStatisticData];
}
-(void)sendStatisticData
{
    KS_BLOCK_DECLARE{
        std::string titleEncode = KwTools::Encoding::UrlEncode(m_bookInfo.m_strBookTitle);
        NSString *strURL = [NSString stringWithFormat:@"%@srcver=storylog&type=add&id=%s&sid=%@&v=%s&src=ios&title=%s&uid=%s&frm=%s",BASE_URL,m_bookInfo.m_strBookId.c_str(),@"",KWSING_VERSION_STRING,titleEncode.c_str(),GetUserUUID(),STR_PLAY_SOURCE_TYPE[m_ePlaySource_type].c_str()];
        std::string stringURL = [strURL UTF8String];
        std::string stringOut;
        CHttpRequest::QuickSyncGet(stringURL, stringOut);
        
    }KS_BLOCK_RUN_THREAD()
}
-(void)startLoadImage : (NSString*)str_image_url
{
    __block void* imageData = NULL;
    __block unsigned length = 0;;
    __block BOOL outOfDate;
    if (CCacheMgr::GetInstance()->Read([str_image_url UTF8String], imageData, length, outOfDate)) {
        NSLog(@"load image from cache");
        NSData *cacheImageData=[[NSData alloc] initWithBytesNoCopy:imageData length:length freeWhenDone:YES];
        UIImage *image = [[UIImage alloc] initWithData:cacheImageData];
        dispatch_async(dispatch_get_main_queue(), ^{
            [_book_image setImage:image];
            [_backView setAlpha:0.0];
            [UIView animateWithDuration:1.0 animations:^{
                [_backView setImageToBlur:image blurRadius:10.f completionBlock:nil];
                [_backView setAlpha:1.0];
            }];
        });
    }
    else{
        NSLog(@"load image from web");
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:str_image_url]];
            if (imageData) {
                UIImage *image = [[UIImage alloc] initWithData:imageData];
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [_book_image setImage:image];
                    
                    [_backView setAlpha:0.0];
                    [UIView animateWithDuration:1.0 animations:^{
                        [_backView setImageToBlur:image blurRadius:10.f completionBlock:nil];
                        [_backView setAlpha:1.0];
                    }];

                    CCacheMgr::GetInstance()->Cache(T_DAY, 3, [str_image_url UTF8String], [imageData bytes], [imageData length]);
                });
            }
            else{
                if (isIOS7()) {
                    [_backView setImage:CImageMgr::GetImageEx("BookDetailBackgroundFor7.png")];
                }
                else{
                    [_backView setImage:CImageMgr::GetImageEx("BookDetailBackground.png")];
                }
            }
        });
    }
}

- (void)resizeBookIntroduction{
    
    NSString* book_intro = nil;
    if (!m_bookInfo.m_strSummary.size()) {
        book_intro = @"暂无简介";
    }else {
        book_intro = [NSString stringWithUTF8String:m_bookInfo.m_strSummary.c_str()];
    }
    
    book_intro = [book_intro stringByReplacingOccurrencesOfString:@"<br>" withString:@"\n"];
    
    for(UIView* sub_view in [_view_book_intro subviews]){
        [sub_view removeFromSuperview];
    }
    
    if (m_bIntroductionOpend) {
        UILabel* label_intro = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 35)];
        [label_intro setTag:TAG_SUMMARY_LABEL];
        [label_intro setBackgroundColor:[UIColor clearColor]];
        [label_intro setTextColor:defaultGrayColor()];
        [label_intro setFont:[UIFont systemFontOfSize:13]];
        label_intro.numberOfLines = 0;
        [label_intro setText:book_intro];
        [_view_book_intro addSubview:label_intro];
        
        CGSize cur_size = [self getTextDrawSize:book_intro];
        _view_book_intro.frame = CGRectMake(11, _topBar.frame.size.height + 10, 310, cur_size.height);
        label_intro.frame = CGRectMake(0, 0, cur_size.width, cur_size.height);
        
        UIImageView* image_open_detail = [[UIImageView alloc] initWithImage:CImageMgr::GetImageEx("BookDetailClose.png")];
        image_open_detail.frame = CGRectMake(277, label_intro.frame.size.height - 14, 18, 12.5);
        
        [image_open_detail setBackgroundColor:[UIColor clearColor]];
        [_view_book_intro addSubview:image_open_detail];
        
        UIButton* btn_open_intro = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn_open_intro setBackgroundColor:[UIColor clearColor]];
        btn_open_intro.frame = CGRectMake(0, 0, _view_book_intro.frame.size.width, _view_book_intro.frame.size.height);
        [btn_open_intro setTag:TAG_BTN_DETAIL];
        [btn_open_intro addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [_view_book_intro addSubview:btn_open_intro];
    }else {
        _view_book_intro.frame = CGRectMake(11, _topBar.frame.size.height + 10, 310, 40);
        
        UILabel* label_intro = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280, 35)];
        [label_intro setTag:TAG_SUMMARY_LABEL];
        [label_intro setBackgroundColor:[UIColor clearColor]];
        [label_intro setTextColor:defaultGrayColor()];
        [label_intro setFont:[UIFont systemFontOfSize:13]];
        label_intro.numberOfLines = 0;
        [label_intro setText:book_intro];
        [_view_book_intro addSubview:label_intro];

//        if (1 == n_line_num) {
//            btn_open_intro.frame = CGRectMake(277, 0, 18, 12.5);
//        }else {
//            btn_open_intro.frame = CGRectMake(277, 17, 18, 12.5);
//        }
        UIImageView* image_open_detail = [[UIImageView alloc] initWithImage:CImageMgr::GetImageEx("BookDetailOpen.png")];
        image_open_detail.frame = CGRectMake(280, label_intro.frame.size.height - 16, 18, 12.5);
        [_view_book_intro addSubview:image_open_detail];
        
        UIButton* btn_open_intro = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn_open_intro setBackgroundColor:[UIColor clearColor]];
        btn_open_intro.frame = CGRectMake(0, 0, _view_book_intro.frame.size.width, _view_book_intro.frame.size.height);
        [btn_open_intro setTag:TAG_BTN_DETAIL];
        [btn_open_intro addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [_view_book_intro addSubview:btn_open_intro];
        
    }
    
    if (_tab_bar_view) {
        _tab_bar_view.frame = CGRectMake(0, _view_book_intro.frame.origin.y + _view_book_intro.frame.size.height + 5, 320, 44);
    }
    
    if (_table_chapter_list) {
        _table_chapter_list.frame = CGRectMake(0, _tab_bar_view.frame.origin.y + 45, 320, self.view.frame.size.height - _tab_bar_view.frame.origin.y - 45);
    }
    if (_table_quickdown_list) {
        _table_quickdown_list.frame = CGRectMake(0, _tab_bar_view.frame.origin.y + 45, 320, self.view.frame.size.height - _tab_bar_view.frame.origin.y - 45);
    }
}

- (void)onBtnClick:(id)sender{
    UIButton* button = (UIButton*)sender;
    switch (button.tag) {
        case TAG_BTN_DETAIL:
        {
            m_bIntroductionOpend = !m_bIntroductionOpend;
            [self resizeBookIntroduction];
            break;
        }
        case TAG_BTN_BACK:
        {
            GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
            GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus);
            
            s_b_btn_back = true;
            _tableViewDownload = nil;
            _tableViewQuickDownload = nil;
            _topBar = nil;
            _book_image = nil;
            _view_book_intro = nil;
            
            _tab_bar_view = nil;
            _table_chapter_list = nil;
            _table_quickdown_list = nil;
            _open_flag_view = nil;
            _activity_view = nil;
            _indicator_view = nil;
            
            _prompt_view = nil;
            
            [self.navigationController popViewControllerAnimated:YES];
            
            break;
        }
            
        case TAG_BTN_PLAYLIST:
        {
            _open_flag_view.frame = CGRectMake(66, 38, 14, 6);
            [button setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
            
            UIButton* quick_down_btn = (UIButton*)[_tab_bar_view viewWithTag:TAG_BTN_QUICK_DOWNLOAD];
            if (quick_down_btn) {
                //                _open_flag_view.frame = CGRectMake(153, 38, 14, 6);
                [quick_down_btn setTitleColor:UIColorFromRGBValue(COLOR_FONT_GRAY) forState:UIControlStateNormal];
            }
            
            _table_chapter_list.hidden = NO;
            _table_quickdown_list.hidden = YES;
            
            break;
        }
            
        case TAG_BTN_QUICK_DOWNLOAD:
        {
            _open_flag_view.frame = CGRectMake(226, 38, 14, 6);
            [button setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
            
            UIButton* play_btn = (UIButton*)[_tab_bar_view viewWithTag:TAG_BTN_PLAYLIST];
            if (play_btn) {
                //                _open_flag_view.frame = CGRectMake(153, 38, 14, 6);
                [play_btn setTitleColor:UIColorFromRGBValue(COLOR_FONT_GRAY) forState:UIControlStateNormal];
            }
            
            _table_chapter_list.hidden = YES;
            _table_quickdown_list.hidden = NO;
            
            break;
        }
        case TAG_BTN_PLAY:
        {
            if (CPlayBookList::getInstance()->getCurChapter() && CPlayBookList::getInstance()->getCurChapter()->m_strBookId == m_bookInfo.m_strBookId) {
                if (E_AUDIO_PLAY_PLAYING != CAudioPlayerManager::getInstance()->getCurPlayState()) {
                    if (!m_bSendUmengLog) {
                        UMengLog(KB_PLAY_SOURCE, STR_PLAY_SOURCE_TYPE[m_ePlaySource_type]);
                        [self sendStatisticData];
                        m_bSendUmengLog = true;
                    }
                    
                    bool b_flow_protect = false;
                    KwConfig::GetConfigureInstance()->GetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, b_flow_protect);
                    
                    CChapterInfo* cur_chapter = CPlayBookList::getInstance()->getCurChapter();
                    if (b_flow_protect && (NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus() && cur_chapter && !CPlayBookList::getInstance()->iSLocalChapter(cur_chapter))) {
                        UIAlertView* alert_view = [[UIAlertView alloc] initWithTitle:nil message:@"继续播放会自动关闭流量保护模式，播放会消耗流量" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"继续播放", nil];
                        [alert_view setTag:TAG_ALERT_FLOW_PROTECT_PLAY];
                        [alert_view show];
                    }else {
                        CAudioPlayerManager::getInstance()->play();
                    }
                }
            }else {
                CRecentBookInfo* recent_book = CRecentBookList::GetInstance()->GetCurBook([[NSString stringWithUTF8String:m_bookInfo.m_strBookId.c_str()] intValue]);
                if (recent_book) {
                    bool b_flow_protect = false;
                    KwConfig::GetConfigureInstance()->GetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, b_flow_protect);
                    
                    if (b_flow_protect && (NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus() && !CLocalBookRequest::GetInstance()->IsLocalChapter(recent_book->m_unRid))) {
                        KBAlertView* alert_view = [[KBAlertView alloc] initWithTitle:nil message:@"继续播放会自动关闭流量保护模式，播放会消耗流量" cancelButtonTitle:@"取消" otherButtonTitles:@"继续播放" clickButton:^(NSInteger indexButton) {
                            if (1 == indexButton) {
                                CPlayBookList::getInstance()->resetPlayList();
                                CPlayBookList::getInstance()->addChapters(m_vecChapterList);
                                CPlayBookList::getInstance()->setCurPlayIndex(recent_book->m_unIndex);
                                CPlayBookList::getInstance()->setCurPos(recent_book->m_unPosMilSec);
                                
                                SYN_NOTIFY(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState::AudioPlayStatusChanged, E_AUDIO_BOOK_CHANGE);
                                
                                KwConfig::GetConfigureInstance()->SetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, false);
                                CAudioPlayerManager::getInstance()->play();
                                SYN_NOTIFY(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect::FlowProtectStatusChange, false);
                                
                                if (!m_bSendUmengLog) {
                                    UMengLog(KB_PLAY_SOURCE, STR_PLAY_SOURCE_TYPE[m_ePlaySource_type]);
                                    [self sendStatisticData];
                                    m_bSendUmengLog = true;
                                }
                            }
                        }];
                        [alert_view show];
                    }else if((NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus() && !CLocalBookRequest::GetInstance()->IsLocalChapter(recent_book->m_unRid))){
                        [iToast defaultShow:@"运营商网络下，注意你的流量喔"];
                        CPlayBookList::getInstance()->resetPlayList();
                        CPlayBookList::getInstance()->addChapters(m_vecChapterList);
                        CPlayBookList::getInstance()->setCurPlayIndex(recent_book->m_unIndex);
                        CPlayBookList::getInstance()->setCurPos(recent_book->m_unPosMilSec);
                        
                        SYN_NOTIFY(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState::AudioPlayStatusChanged, E_AUDIO_BOOK_CHANGE);
                        
                        CAudioPlayerManager::getInstance()->play();
                        
                        if (!m_bSendUmengLog) {
                            UMengLog(KB_PLAY_SOURCE, STR_PLAY_SOURCE_TYPE[m_ePlaySource_type]);
                            [self sendStatisticData];
                            m_bSendUmengLog = true;
                        }
                    }else {
                        CPlayBookList::getInstance()->resetPlayList();
                        CPlayBookList::getInstance()->addChapters(m_vecChapterList);
                        CPlayBookList::getInstance()->setCurPlayIndex(recent_book->m_unIndex);
                        CPlayBookList::getInstance()->setCurPos(recent_book->m_unPosMilSec);
                        
                        SYN_NOTIFY(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState::AudioPlayStatusChanged, E_AUDIO_BOOK_CHANGE);
                        
                        CAudioPlayerManager::getInstance()->play();
                        
                        if (!m_bSendUmengLog) {
                            UMengLog(KB_PLAY_SOURCE, STR_PLAY_SOURCE_TYPE[m_ePlaySource_type]);
                            [self sendStatisticData];
                            m_bSendUmengLog = true;
                        }
                    }
                }else {
                    if(0 == m_vecChapterList.size()){
                       [iToast defaultShow:@"网络似乎断开了，请检查连接"];
                        return;
                    }
                    
                    bool b_flow_protect = false;
                    KwConfig::GetConfigureInstance()->GetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, b_flow_protect);
                    
                    if (b_flow_protect && (NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus() && !CLocalBookRequest::GetInstance()->IsLocalChapter(m_vecChapterList[0]->m_unRid))) {
                        KBAlertView* alert_view = [[KBAlertView alloc] initWithTitle:nil message:@"继续播放会自动关闭流量保护模式，播放会消耗流量" cancelButtonTitle:@"取消" otherButtonTitles:@"继续播放" clickButton:^(NSInteger indexButton) {
                            if (1 == indexButton) {
                                CPlayBookList::getInstance()->resetPlayList();
                                CPlayBookList::getInstance()->addChapters(m_vecChapterList);
                                CPlayBookList::getInstance()->setCurPlayIndex(0);
                                CPlayBookList::getInstance()->setCurPos(0);
                                
                                SYN_NOTIFY(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState::AudioPlayStatusChanged, E_AUDIO_BOOK_CHANGE);
                                
                                KwConfig::GetConfigureInstance()->SetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, false);
                                CAudioPlayerManager::getInstance()->play();
                                SYN_NOTIFY(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect::FlowProtectStatusChange, false);
                                
                                if (!m_bSendUmengLog) {
                                    UMengLog(KB_PLAY_SOURCE, STR_PLAY_SOURCE_TYPE[m_ePlaySource_type]);
                                    [self sendStatisticData];
                                    m_bSendUmengLog = true;
                                }
                            }
                        }];
                        [alert_view show];
                    }else if((NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus() && !CLocalBookRequest::GetInstance()->IsLocalChapter(m_vecChapterList[0]->m_unRid))){
                        [iToast defaultShow:@"运营商网络下，注意你的流量喔"];
                        CPlayBookList::getInstance()->resetPlayList();
                        CPlayBookList::getInstance()->addChapters(m_vecChapterList);
                        CPlayBookList::getInstance()->setCurPlayIndex(0);
                        CPlayBookList::getInstance()->setCurPos(0);
                        
                        SYN_NOTIFY(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState::AudioPlayStatusChanged, E_AUDIO_BOOK_CHANGE);
                        
                        CAudioPlayerManager::getInstance()->play();
                        
                        if (!m_bSendUmengLog) {
                            UMengLog(KB_PLAY_SOURCE, STR_PLAY_SOURCE_TYPE[m_ePlaySource_type]);
                            [self sendStatisticData];
                            m_bSendUmengLog = true;
                        }
                    }else {
                        CPlayBookList::getInstance()->resetPlayList();
                        CPlayBookList::getInstance()->addChapters(m_vecChapterList);
                        CPlayBookList::getInstance()->setCurPlayIndex(0);
                        CPlayBookList::getInstance()->setCurPos(0);
                        
                        SYN_NOTIFY(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState::AudioPlayStatusChanged, E_AUDIO_BOOK_CHANGE);
                        
                        CAudioPlayerManager::getInstance()->play();
                    }
                }
            }

            break;
        }
            
        case TAG_BTN_CARE:
        {
            if (!CCollectBookList::GetInstance()->GetCurBook([[NSString stringWithUTF8String:m_bookInfo.m_strBookId.c_str()] intValue])) {
                CCollectBookInfo book_info;
                book_info.m_strBookId = m_bookInfo.m_strBookId;
                book_info.m_strBookTitle = m_bookInfo.m_strBookTitle;
                book_info.m_strArtist = m_bookInfo.m_strArtist;
                book_info.m_unCount = m_bookInfo.m_unCount;
                book_info.m_unListenCnt = m_bookInfo.m_unListenCnt;
                book_info.m_strImgUrl = m_bookInfo.m_strImgUrl;
                book_info.m_unType = m_bookInfo.m_unType;
                book_info.m_strSummary = m_bookInfo.m_strSummary;
//                book_info.m_unRid = m_vecChapterList[0].m_unRid;
                book_info.m_unIndex = 0;
                book_info.m_unPosMilSec = 0;

                CCollectBookList::GetInstance()->AddBookInfo(&book_info);
//                [button setImage:CImageMgr::GetImageEx("BookDetailCared.png") forState:UIControlStateNormal];
                [iToast defaultShow:@"已收藏"];
            }else {
                CCollectBookList::GetInstance()->DeleteBookInfo([[NSString stringWithUTF8String:m_bookInfo.m_strBookId.c_str()] intValue]);
//                [button setImage:CImageMgr::GetImageEx("BookDetailUnCared.png") forState:UIControlStateNormal];
                [iToast defaultShow:@"已取消收藏"];
            }
            
            
            break;
        }
            
        case TAG_BTN_PROMPT:
        {
            if (NETSTATUS_NONE == CHttpRequest::GetNetWorkStatus()) {
                [_prompt_view setHidden:NO];
                return;
            }else {
                [_prompt_view setHidden:YES];
            }
            
            [_indicator_view startAnimating];
            [_activity_view setHidden:NO];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self getChapterList];
                if (s_b_btn_back) {
                    return ;
                }
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [_table_quickdown_list reloadData];
                    [_table_chapter_list reloadData];
                    
                    [_indicator_view stopAnimating];
                    [_activity_view setHidden:YES];
                    
                    UILabel* label = (UILabel*)[_activity_view viewWithTag:TAG_LAB_PROMPT];
                    if (label) {
                        [label setText:@"正在缓冲"];
                    }
                    
                    if (CPlayBookList::getInstance()->getCurChapter() && CPlayBookList::getInstance()->getCurChapter()->m_strBookId == m_bookInfo.m_strBookId) {
                        int n_total = m_vecChapterList.size();
                        int n_cur_chapter = -1;
                        for (int n_itr = 0; n_itr < n_total; ++n_itr) {
                            if (CPlayBookList::getInstance()->getCurChapter()->m_unRid == m_vecChapterList[n_itr]->m_unRid) {
                                n_cur_chapter = n_itr;
                                break;
                            }
                        }
                        if (-1 != n_cur_chapter) {
                            NSIndexPath* indexPath = [NSIndexPath indexPathForRow:n_cur_chapter inSection:0];
                            [_table_chapter_list scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
                            [_table_chapter_list reloadData];
                        }
                    }
                });
            });
            break;
        }
        default:
            break;
    }
}

- (void)btnQuickDownClick:(id)sender{
    if (m_bAllDownClicked) {
        return;
    }
    if (NETSTATUS_NONE == CHttpRequest::GetNetWorkStatus()) {
        [iToast defaultShow:@"网络似乎断开了，请检查连接"];
        return;
    }
    
    m_curDownBtn = (UIButton*)sender;
    
    bool b_flow_protect = false;
    KwConfig::GetConfigureInstance()->GetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, b_flow_protect);
    if(b_flow_protect && NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus()){
        UIAlertView* alert_view = [[UIAlertView alloc] initWithTitle:nil message:@"现在下载会自动关闭流量保护模式，下载会消耗流量" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"现在下载", nil];
        [alert_view setTag:TAG_ALERT_FLOW_PROTECT_QUICK_DOWNLOAD];
        [alert_view show];
        return;
    }
    
    switch (m_curDownBtn.tag) {
        case TAG_BTN_DOWNALL:
        {
            UIAlertView* alert_down_confirm = [[UIAlertView alloc]initWithTitle:@""
                                                                                             message:@"确定要全部下载吗？"
                                                                                            delegate:self
                                                                                   cancelButtonTitle:@"取消"
                                                                                   otherButtonTitles:@"确定", nil];
            [alert_down_confirm setTag:TAG_ALERT_QUICK_DOWN_CONFIRM];
            [alert_down_confirm show];
            
            break;
        }
         
        default:
        {
            UIAlertView* alert_down_confirm = [[UIAlertView alloc]initWithTitle:@""
                                                                        message:[NSString stringWithFormat:@"确定要下载%@吗？", [m_curDownBtn titleForState:UIControlStateNormal]]
                                                                       delegate:self
                                                              cancelButtonTitle:@"取消"
                                                              otherButtonTitles:@"确定", nil];
            [alert_down_confirm setTag:TAG_ALERT_QUICK_DOWN_CONFIRM];
            [alert_down_confirm show];
            
            break;
        }
    }
    
    return;
}

-(void) btnDownloadClicked:(id)sender{
    if (m_bAllDownClicked) {
        return;
    }
    if (NETSTATUS_NONE == CHttpRequest::GetNetWorkStatus()) {
        [iToast defaultShow:@"网络似乎断开了，请检查连接"];
        return;
    }
    UIButton* button = (UIButton*)sender;
    UITableViewCell* cell = nil;
    if (NSOrderedAscending != [[[UIDevice currentDevice] systemVersion] compare:@"7.0"]) {
        cell = (UITableViewCell*)[[[(UIButton*)sender superview]superview] superview];
    }else {
        cell = (UITableViewCell*)[[(UIButton*)sender superview]superview];
    }
    
    bool b_flow_protect = false;
    KwConfig::GetConfigureInstance()->GetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, b_flow_protect);
    if (b_flow_protect && NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus()){
        m_curIndexPath = [_table_chapter_list indexPathForCell:cell];
        UIAlertView* alert_view = [[UIAlertView alloc] initWithTitle:nil message:@"现在下载会自动关闭流量保护模式，下载会消耗流量" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"现在下载", nil];
        [alert_view setTag:TAG_ALERT_FLOW_PROTECT_DOWNLOAD];
        [alert_view show];
    }else {
        CLocalBookRequest::GetInstance()->StartDownTask(m_vecChapterList[[_table_chapter_list indexPathForCell:cell].row]);
        [iToast defaultShow:@"已加入下载列表"];
        m_curIndexPath = nil;
    }
    
    return;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark
#pragma mark tableview delegate

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (tableView.tag) {
        case TAG_TAB_PLAYLIST:
            return 50;
        case TAG_TAB_QUICKDOWN:
            return 62;
        default:
            return 0;
    }
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    KwTools::CAutoLock auto_lock(&s_chapter_list_lock);
    switch (tableView.tag) {
        case TAG_TAB_PLAYLIST:
            return m_vecChapterList.size();
            
        case TAG_TAB_QUICKDOWN:
        {
            if (0 == m_vecChapterList.size()) {
                return 0;
            }
            else if (m_vecChapterList.size() <= 20) {
                return 1;
            }else {
                if (0 == ((m_vecChapterList.size() - 20) % 30)) {
                    return 2 + (m_vecChapterList.size() - 20) / 30;
                }else {
                    return 3 + (m_vecChapterList.size() - 20) / 30;
                }
            }
        }
        default:
            return 0;
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* s_str_playlist_reuse_identifier = @"playlistReuseIdentifier";
    static NSString* s_str_quickdown_reuse_identifier = @"quickdownReuseIdentifier";
    
    UITableViewCell* cell = nil;
    
    if (1000 <= m_bookInfo.m_unCount) {
        m_nChapterDownTitleSize = 13;
    }else {
        m_nChapterDownTitleSize = 18;
    }
    
    KwTools::CAutoLock auto_lock(&s_chapter_list_lock);
    
    switch (tableView.tag) {
        case TAG_TAB_PLAYLIST:
        {
            if (2 == m_bookInfo.m_unType){
                if (E_AUDIO_PLAY_PLAYING == CAudioPlayerManager::getInstance()->getCurPlayState() && NULL != CPlayBookList::getInstance()->getCurChapter() && CPlayBookList::getInstance()->getCurChapter()->m_unRid == m_vecChapterList[indexPath.row]->m_unRid) {
//                if (indexPath.row == m_nRowClicked) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    UIImageView* play_image = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, 7.5, 10)];
                    [play_image setImage:CImageMgr::GetImageEx("BookDetailChapterListPlay.png")];
                    [cell.contentView addSubview:play_image];
                    
                    UILabel* lab_title = [[UILabel alloc] initWithFrame:CGRectMake(21, 9, 275, 18)];
                    [lab_title setTextColor:UIColorFromRGBValue(COLOR_FONT_BLUE)];
                    [lab_title setFont:[UIFont systemFontOfSize:18]];
                    [lab_title setText:[NSString stringWithUTF8String:m_vecChapterList[indexPath.row]->m_strName.c_str()]];
                    [lab_title setBackgroundColor:[UIColor clearColor]];
                    [cell.contentView addSubview:lab_title];
                    
                    UILabel* artist_label = [[UILabel alloc] initWithFrame:CGRectMake(21, 30, 290, 14)];
                    [artist_label setTextColor:UIColorFromRGBValue(COLOR_FONT_BLUE)];
                    [artist_label setFont:[UIFont systemFontOfSize:10]];
                    [artist_label setText:[NSString stringWithUTF8String:m_vecChapterList[indexPath.row]->m_strArtist.c_str()]];
                    [artist_label setBackgroundColor:[UIColor clearColor]];
                    [cell.contentView addSubview:artist_label];
                    
                    CLocalTask* chapter_info = (CLocalTask*)CBookManagement::GetInstance()->GetChapterInfo(m_bookInfo.m_strBookId, m_vecChapterList[indexPath.row]->m_unRid);
                    if (!chapter_info) {
                        UIButton* btn_download = [[UIButton alloc] initWithFrame:CGRectMake(280, 6, 39, 39)];
                        [btn_download setBackgroundImage:CImageMgr::GetImageEx("BookDetailDownloadBtnUp.png") forState:UIControlStateNormal];
                        [btn_download setBackgroundImage:CImageMgr::GetImageEx("BookDetailDownloadBtnDown.png") forState:UIControlStateNormal];
                        [btn_download setTag:TAG_BTN_DOWNLOAD];
                        [btn_download addTarget:self action:@selector(btnDownloadClicked:) forControlEvents:UIControlEventTouchUpInside];
                        [cell.contentView addSubview:btn_download];
                    }else {
                        UILabel* label_down_status = [[UILabel alloc] initWithFrame:CGRectMake(280, 16, 30, 20)];
                        [label_down_status setTextAlignment:NSTextAlignmentCenter];
                        [label_down_status setTextColor:[UIColor blackColor]];
                        [label_down_status setFont:[UIFont systemFontOfSize:12]];
                        [label_down_status setTag:TAG_LAB_DOWN_STATUS];
                        [label_down_status setBackgroundColor:[UIColor clearColor]];
                        
                        if (TaskStatus_Finish == chapter_info->taskStatus) {
                            [label_down_status setText:@"已下载"];
                        }else {
                            [label_down_status setText:@"下载中"];
                        }
                        
                        [cell.contentView addSubview:label_down_status];
                    }
                    
                }else {
                    cell = [tableView dequeueReusableCellWithIdentifier:s_str_playlist_reuse_identifier];
                    if (nil == cell) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:s_str_playlist_reuse_identifier];
                        UILabel* lab_title = [[UILabel alloc] initWithFrame:CGRectMake(21, 9, 255, 18)];
                        [lab_title setTextColor:defaultBlackColor()];
                        [lab_title setFont:[UIFont systemFontOfSize:18]];
                        [lab_title setTag:TAG_CHAPTER_TITLE];
                        [lab_title setBackgroundColor:[UIColor clearColor]];
                        [cell.contentView addSubview:lab_title];
                        
                        UILabel* artist_label = [[UILabel alloc] initWithFrame:CGRectMake(21, 30, 255, 14)];
                        [artist_label setTextColor:defaultBlackColor()];
                        [artist_label setFont:[UIFont systemFontOfSize:10]];
                        [artist_label setTag:TAG_CHAPTER_ARTIST];
                        [artist_label setBackgroundColor:[UIColor clearColor]];
                        [cell.contentView addSubview:artist_label];
                        
                        UIButton* btn_download = [[UIButton alloc] initWithFrame:CGRectMake(280, 6, 39, 39)];
                        [btn_download setBackgroundImage:CImageMgr::GetImageEx("BookDetailDownloadBtnUp.png") forState:UIControlStateNormal];
                        [btn_download setBackgroundImage:CImageMgr::GetImageEx("BookDetailDownloadBtnDown.png") forState:UIControlStateNormal];
                        [btn_download setTag:TAG_BTN_DOWNLOAD];
                        [btn_download setHidden:YES];
                        [btn_download addTarget:self action:@selector(btnDownloadClicked:) forControlEvents:UIControlEventTouchUpInside];
                        [cell.contentView addSubview:btn_download];
                        
                        UILabel* label_down_status = [[UILabel alloc] initWithFrame:CGRectMake(280, 16, 30, 20)];
                        [label_down_status setTextAlignment:NSTextAlignmentCenter];
                        [label_down_status setTextColor:[UIColor blackColor]];
                        [label_down_status setFont:[UIFont systemFontOfSize:10]];
                        [label_down_status setTag:TAG_LAB_DOWN_STATUS];
                        [label_down_status setHidden:YES];
                        [label_down_status setBackgroundColor:[UIColor clearColor]];
                        [cell.contentView addSubview:label_down_status];
                    }
                    
                    CLocalTask* chapter_info = (CLocalTask*)CBookManagement::GetInstance()->GetChapterInfo(m_bookInfo.m_strBookId, m_vecChapterList[indexPath.row]->m_unRid);
                    if (!chapter_info) {
                        UIButton* button = (UIButton*)[cell.contentView viewWithTag:TAG_BTN_DOWNLOAD];
                        [button setHidden:NO];
                        
                        UILabel* label = (UILabel*)[cell.contentView viewWithTag:TAG_LAB_DOWN_STATUS];
                        [label setHidden:YES];
                    }else {
                        UIButton* button = (UIButton*)[cell.contentView viewWithTag:TAG_BTN_DOWNLOAD];
                        [button setHidden:YES];
                        
                        UILabel* label = (UILabel*)[cell.contentView viewWithTag:TAG_LAB_DOWN_STATUS];
                        [label setHidden:NO];
                        
                        if (TaskStatus_Finish == chapter_info->taskStatus) {
                            [label setText:@"已下载"];
                        }else {
                            [label setText:@"下载中"];
                        }
                    }
                    
                    UILabel* lab_title = (UILabel*)[cell.contentView viewWithTag:TAG_CHAPTER_TITLE];
                    if (lab_title) {
                        [lab_title setText:[NSString stringWithUTF8String:m_vecChapterList[indexPath.row]->m_strName.c_str()]];
                    }
                    
                    UILabel* artist_label = (UILabel*)[cell.contentView viewWithTag:TAG_CHAPTER_ARTIST];
                    if (artist_label) {
                        [artist_label setText:[NSString stringWithUTF8String:m_vecChapterList[indexPath.row]->m_strArtist.c_str()]];
                    }
                }
                
            }else if(1 == m_bookInfo.m_unType){
                if (NULL != CPlayBookList::getInstance()->getCurChapter() && CPlayBookList::getInstance()->getCurChapter()->m_unRid == m_vecChapterList[indexPath.row]->m_unRid) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    UIImageView* play_image = [[UIImageView alloc] initWithFrame:CGRectMake(10, 20, 7.5, 10)];
                    [play_image setImage:CImageMgr::GetImageEx("BookDetailChapterListPlay.png")];
                    [cell.contentView addSubview:play_image];
                    
                    UILabel* lab_title = [[UILabel alloc] initWithFrame:CGRectMake(21, 16, 255, 18)];
                    [lab_title setTextColor:UIColorFromRGBValue(COLOR_FONT_BLUE)];
                    [lab_title setFont:[UIFont systemFontOfSize:18]];
                    [lab_title setText:[NSString stringWithUTF8String:m_vecChapterList[indexPath.row]->m_strName.c_str()]];
                    [lab_title setBackgroundColor:[UIColor clearColor]];
                    [cell.contentView addSubview:lab_title];
                    
                    CLocalTask* chapter_info = (CLocalTask*)CBookManagement::GetInstance()->GetChapterInfo(m_bookInfo.m_strBookId, m_vecChapterList[indexPath.row]->m_unRid);
                    if (!chapter_info) {
                        UIButton* btn_download = [[UIButton alloc] initWithFrame:CGRectMake(280, 6, 39, 39)];
                        [btn_download setBackgroundImage:CImageMgr::GetImageEx("BookDetailDownloadBtnUp.png") forState:UIControlStateNormal];
                        [btn_download setBackgroundImage:CImageMgr::GetImageEx("BookDetailDownloadBtnDown.png") forState:UIControlStateNormal];
                        [btn_download setTag:TAG_BTN_DOWNLOAD];
                        [btn_download addTarget:self action:@selector(btnDownloadClicked:) forControlEvents:UIControlEventTouchUpInside];
                        [cell.contentView addSubview:btn_download];
                    }else {
                        UILabel* label_down_status = [[UILabel alloc] initWithFrame:CGRectMake(280, 16, 30, 20)];
                        [label_down_status setTextAlignment:NSTextAlignmentCenter];
                        [label_down_status setTextColor:[UIColor blackColor]];
                        [label_down_status setFont:[UIFont systemFontOfSize:10]];
                        [label_down_status setBackgroundColor:[UIColor clearColor]];
                        [label_down_status setTag:TAG_LAB_DOWN_STATUS];
                        
                        if (TaskStatus_Finish == chapter_info->taskStatus) {
                            [label_down_status setText:@"已下载"];
                        }else {
                            [label_down_status setText:@"下载中"];
                        }
                        
                        [cell.contentView addSubview:label_down_status];
                    }
                }else {
                    cell = [tableView dequeueReusableCellWithIdentifier:s_str_playlist_reuse_identifier];
                    if (nil == cell) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:s_str_playlist_reuse_identifier];
                        UILabel* lab_title = [[UILabel alloc] initWithFrame:CGRectMake(21, 16, 255, 18)];
                        [lab_title setTextColor:defaultBlackColor()];
                        [lab_title setFont:[UIFont systemFontOfSize:18]];
                        [lab_title setTag:TAG_CHAPTER_TITLE];
                        [lab_title setBackgroundColor:[UIColor clearColor]];
                        [cell.contentView addSubview:lab_title];
                        
                        UIButton* btn_download = [[UIButton alloc] initWithFrame:CGRectMake(280, 6, 39, 39)];
                        [btn_download setBackgroundImage:CImageMgr::GetImageEx("BookDetailDownloadBtnUp.png") forState:UIControlStateNormal];
                        [btn_download setBackgroundImage:CImageMgr::GetImageEx("BookDetailDownloadBtnDown.png") forState:UIControlStateNormal];
                        [btn_download setTag:TAG_BTN_DOWNLOAD];
                        [btn_download setHidden:YES];
                        [btn_download addTarget:self action:@selector(btnDownloadClicked:) forControlEvents:UIControlEventTouchUpInside];
                        [cell.contentView addSubview:btn_download];
                        
                        UILabel* label_down_status = [[UILabel alloc] initWithFrame:CGRectMake(280, 16, 30, 20)];
                        [label_down_status setTextAlignment:NSTextAlignmentCenter];
                        [label_down_status setTextColor:[UIColor blackColor]];
                        [label_down_status setFont:[UIFont systemFontOfSize:10]];
                        [label_down_status setTag:TAG_LAB_DOWN_STATUS];
                        [label_down_status setHidden:YES];
                        [label_down_status setBackgroundColor:[UIColor clearColor]];
                        [cell.contentView addSubview:label_down_status];
                    }
                    
                    UILabel* lab_title = (UILabel*)[cell.contentView viewWithTag:TAG_CHAPTER_TITLE];
                    if (lab_title) {
                        [lab_title setText:[NSString stringWithUTF8String:m_vecChapterList[indexPath.row]->m_strName.c_str()]];
                    }
                    
                    CLocalTask* chapter_info = (CLocalTask*)CBookManagement::GetInstance()->GetChapterInfo(m_bookInfo.m_strBookId, m_vecChapterList[indexPath.row]->m_unRid);
                    if (!chapter_info) {
                        UIButton* button = (UIButton*)[cell.contentView viewWithTag:TAG_BTN_DOWNLOAD];
                        [button setHidden:NO];
                        
                        UILabel* label = (UILabel*)[cell.contentView viewWithTag:TAG_LAB_DOWN_STATUS];
                        [label setHidden:YES];
                    }else {
                        UIButton* button = (UIButton*)[cell.contentView viewWithTag:TAG_BTN_DOWNLOAD];
                        [button setHidden:YES];
                        
                        UILabel* label = (UILabel*)[cell.contentView viewWithTag:TAG_LAB_DOWN_STATUS];
                        [label setHidden:NO];
                        
                        if (TaskStatus_Finish == chapter_info->taskStatus) {
                            [label setText:@"已下载"];
                        }else {
                            [label setText:@"下载中"];
                        }
                    }
                }
            }
            [cell setBackgroundColor:[UIColor clearColor]];
            break;
        }
            
        case TAG_TAB_QUICKDOWN:
        {
            NSLog(@"%d---%d", indexPath.row, [tableView numberOfRowsInSection:0]);
            if (0 != indexPath.row && indexPath.row == ([tableView numberOfRowsInSection:0] - 1)) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            }else {
                bool b_all_down = true;
                for (int n_itr = 0; n_itr < m_vecChapterList.size(); ++n_itr) {
                    if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                        b_all_down = false;
                        break;
                    }
                }
                
                if (0 == indexPath.row) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                    UIButton* btn_down_all = [UIButton buttonWithType:UIButtonTypeCustom];
                    btn_down_all.frame = CGRectMake(12, 11.5, 87, 44.5);
                    if (b_all_down) {
                        [btn_down_all setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                        [btn_down_all setEnabled:NO];
                    }else {
                        [btn_down_all setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                        [btn_down_all setEnabled:YES];
                    }
                    [btn_down_all setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                    
                    [btn_down_all setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                    [btn_down_all setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                    [btn_down_all setTitle:@"全部下载" forState:UIControlStateNormal];
                    [btn_down_all.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                    [btn_down_all.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                    [btn_down_all setTag:TAG_BTN_DOWNALL];
                    [btn_down_all addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                    
                    [cell.contentView addSubview:btn_down_all];
                    
                    switch (m_vecChapterList.size() / 10) {
                        case 0:
                        {
                            UIButton* btn_second = [UIButton buttonWithType:UIButtonTypeCustom];
                            btn_second.frame = CGRectMake(116.5, 11.5, 87, 44.5);
                            if (b_all_down) {
                                [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                [btn_second setEnabled:NO];
                            }else {
                                [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                [btn_second setEnabled:YES];
                            }
                            
                            [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                            
                            [btn_second setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                            [btn_second setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                            [btn_second setTitle:[NSString stringWithFormat:@"1-%lu", m_vecChapterList.size()] forState:UIControlStateNormal];
                            [btn_second.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                            [btn_second setTag:TAG_BTN_QUICKDOWN_SECOND];
                            [btn_second addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                            
                            [cell.contentView addSubview:btn_second];
                            
                            break;
                        }
                        case 1:
                        {
                            UIButton* btn_second = [UIButton buttonWithType:UIButtonTypeCustom];
                            btn_second.frame = CGRectMake(116.5, 11.5, 87, 44.5);
                            bool b_second_all_down = true;
                            for(int n_itr = 0; n_itr < 10; ++n_itr){
                                if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                    b_second_all_down = false;
                                    break;
                                }
                            }
                            if (b_second_all_down) {
                                [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                [btn_second setEnabled:NO];
                            }else {
                                [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                [btn_second setEnabled:YES];
                            }
                            
                            [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                            
                            [btn_second setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                            [btn_second setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                            [btn_second setTitle:@"1-10" forState:UIControlStateNormal];
                            [btn_second.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                            [btn_second setTag:TAG_BTN_QUICKDOWN_SECOND];
                            [btn_second addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                            
                            [cell.contentView addSubview:btn_second];
                            
                            if (0 != (m_vecChapterList.size() - 10) % 10) {
                                UIButton* btn_third = [UIButton buttonWithType:UIButtonTypeCustom];
                                btn_third.frame = CGRectMake(221, 11.5, 87, 44.5);
                                bool b_third_all_down = true;
                                for(int n_itr = 10; n_itr < m_vecChapterList.size(); ++n_itr){
                                    if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                        b_third_all_down = false;
                                        break;
                                    }
                                }
                                if (b_third_all_down) {
                                    [btn_third setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                    [btn_third setEnabled:NO];
                                }else {
                                    [btn_third setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                    [btn_third setEnabled:YES];
                                }
                                
                                [btn_third setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                                
                                [btn_third setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                                [btn_third setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                                [btn_third setTitle:[NSString stringWithFormat:@"11-%lu", m_vecChapterList.size()] forState:UIControlStateNormal];
                                [btn_third.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                                [btn_third setTag:TAG_BTN_QUICKDOWN_SECOND];
                                [btn_third addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                                
                                [cell.contentView addSubview:btn_third];
                            }
                            
                            
                            break;
                        }
                        default:
                        {
                            UIButton* btn_second = [UIButton buttonWithType:UIButtonTypeCustom];
                            btn_second.frame = CGRectMake(116.5, 11.5, 87, 44.5);
                            bool b_second_all_down = true;
                            int n_total = m_vecChapterList.size() < 10 ? m_vecChapterList.size() : 10;
                            for(int n_itr = 0; n_itr < n_total; ++n_itr){
                                if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                    b_second_all_down = false;
                                    break;
                                }
                            }
                            if (b_second_all_down) {
                                [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                [btn_second setEnabled:NO];
                            }else {
                                [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                [btn_second setEnabled:YES];
                            }
                            
                            [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                            
                            [btn_second setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                            [btn_second setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                            [btn_second setTitle:@"1-10" forState:UIControlStateNormal];
                            [btn_second.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                            [btn_second setTag:TAG_BTN_QUICKDOWN_SECOND];
                            [btn_second addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                            
                            [cell.contentView addSubview:btn_second];
                            
                            UIButton* btn_third = [UIButton buttonWithType:UIButtonTypeCustom];
                            btn_third.frame = CGRectMake(221, 11.5, 87, 44.5);
                            bool b_third_all_down = true;
                            n_total = m_vecChapterList.size() < 20 ? m_vecChapterList.size() : 20;
                            for(int n_itr = 10; n_itr < n_total; ++n_itr){
                                if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                    b_third_all_down = false;
                                    break;
                                }
                            }
                            if (b_third_all_down) {
                                [btn_third setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                [btn_third setEnabled:NO];
                            }else {
                                [btn_third setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                [btn_third setEnabled:YES];
                            }
                            
                            [btn_third setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                            
                            [btn_third setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                            [btn_third setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                            [btn_third setTitle:@"11-20" forState:UIControlStateNormal];
                            [btn_third.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                            [btn_third setTag:TAG_BTN_QUICKDOWN_THIRD];
                            [btn_third addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                            
                            [cell.contentView addSubview:btn_third];
                            
                            break;
                        }
                    }
                }else {
                    if ((20 + 30 * indexPath.row) <= m_vecChapterList.size()) {
                        cell = [tableView dequeueReusableCellWithIdentifier:s_str_quickdown_reuse_identifier];
                        if (nil == cell) {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:s_str_quickdown_reuse_identifier];
                            
                            UIButton* btn_first = [UIButton buttonWithType:UIButtonTypeCustom];
                            btn_first.frame = CGRectMake(12, 11.5, 87, 44.5);
                            
                            [btn_first setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                            
                            [btn_first setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                            [btn_first setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                            [btn_first.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                            [btn_first setTag:TAG_BTN_QUICKDOWN_FIRST];
                            [btn_first addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                            
                            [cell.contentView addSubview:btn_first];
                            
                            UIButton* btn_second = [UIButton buttonWithType:UIButtonTypeCustom];
                            btn_second.frame = CGRectMake(116.5, 11.5, 87, 44.5);
                            
                            [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                            
                            [btn_second setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                            [btn_second setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                            [btn_second.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                            [btn_second setTag:TAG_BTN_QUICKDOWN_SECOND];
                            [btn_second addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                            
                            [cell.contentView addSubview:btn_second];
                            
                            UIButton* btn_third = [UIButton buttonWithType:UIButtonTypeCustom];
                            btn_third.frame = CGRectMake(221, 11.5, 87, 44.5);
                            
                            [btn_third setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                            
                            [btn_third setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                            [btn_third setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                            [btn_third.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                            [btn_third setTag:TAG_BTN_QUICKDOWN_THIRD];
                            [btn_third addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                            
                            [cell.contentView addSubview:btn_third];
                        }
                        
                        UIButton* btn_first = (UIButton*)[cell.contentView viewWithTag:TAG_BTN_QUICKDOWN_FIRST];
                        if (btn_first) {
                            [btn_first setTitle:[NSString stringWithFormat:@"%d-%d", 21 + 30 * (indexPath.row - 1), 30 + 30 * (indexPath.row - 1)] forState:UIControlStateNormal];
                            bool b_first_all_down = true;
                            for(int n_itr = 20 + 30 * (indexPath.row - 1); n_itr < 30 + 30 * (indexPath.row - 1); ++n_itr){
                                if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                    b_first_all_down = false;
                                    break;
                                }
                            }
                            if (b_first_all_down) {
                                [btn_first setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                [btn_first setEnabled:NO];
                            }else {
                                [btn_first setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                [btn_first setEnabled:YES];
                            }
                        }
                        
                        UIButton* btn_second = (UIButton*)[cell.contentView viewWithTag:TAG_BTN_QUICKDOWN_SECOND];
                        if (btn_second) {
                            [btn_second setTitle:[NSString stringWithFormat:@"%d-%d", 31 + 30 * (indexPath.row - 1), 40 + 30 * (indexPath.row - 1)] forState:UIControlStateNormal];
                            bool b_second_all_down = true;
                            for(int n_itr = 30 + 30 * (indexPath.row - 1); n_itr < 40 + 30 * (indexPath.row - 1); ++n_itr){
                                if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                    b_second_all_down = false;
                                    break;
                                }
                            }
                            if (b_second_all_down) {
                                [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                [btn_second setEnabled:NO];
                            }else {
                                [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                [btn_second setEnabled:YES];
                            }
                        }
                        
                        UIButton* btn_third = (UIButton*)[cell.contentView viewWithTag:TAG_BTN_QUICKDOWN_THIRD];
                        if (btn_third) {
                            [btn_third setTitle:[NSString stringWithFormat:@"%d-%d", 41 + 30 * (indexPath.row - 1), 50 + 30 * (indexPath.row - 1)] forState:UIControlStateNormal];
                            bool b_third_all_down = true;
                            for(int n_itr = 40 + 30 * (indexPath.row - 1); n_itr < 50 + 30 * (indexPath.row - 1); ++n_itr){
                                if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                    b_third_all_down = false;
                                    break;
                                }
                            }
                            if (b_third_all_down) {
                                [btn_third setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                [btn_third setEnabled:NO];
                            }else {
                                [btn_third setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                [btn_third setEnabled:YES];
                            }
                        }
                    }else {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                        switch ((m_vecChapterList.size() - 20 - 30 * (indexPath.row - 1)) / 10) {
                            case 0:
                            {
                                UIButton* btn_first = [UIButton buttonWithType:UIButtonTypeCustom];
                                btn_first.frame = CGRectMake(12, 11.5, 87, 44.5);
                                
                                bool b_first_all_down = true;
                                for (int n_itr = (20 + 30 * (indexPath.row - 1)); n_itr < m_vecChapterList.size(); ++n_itr) {
                                    if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                        b_first_all_down = false;
                                        break;
                                    }
                                }
                                if (b_first_all_down) {
                                    [btn_first setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                    [btn_first setEnabled:NO];
                                }else {
                                    [btn_first setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                    [btn_first setEnabled:YES];
                                }
                                
                                [btn_first setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                                
                                [btn_first setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                                [btn_first setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                                [btn_first.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                                [btn_first setTitle:[NSString stringWithFormat:@"%d-%lu", 21 + 30 * (indexPath.row - 1) ,m_vecChapterList.size()] forState:UIControlStateNormal];
                                [btn_first setTag:TAG_BTN_QUICKDOWN_FIRST];
                                [btn_first addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                                
                                [cell.contentView addSubview:btn_first];
                                
                                break;
                            }
                                
                            case 1:
                            {
                                UIButton* btn_first = [UIButton buttonWithType:UIButtonTypeCustom];
                                btn_first.frame = CGRectMake(12, 11.5, 87, 44.5);
                                
                                bool b_first_all_down = true;
                                for (int n_itr = (20 + 30 * (indexPath.row - 1)); n_itr < (30 + 30 * (indexPath.row - 1)); ++n_itr) {
                                    if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                        b_first_all_down = false;
                                        break;
                                    }
                                }
                                if (b_first_all_down) {
                                    [btn_first setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                    [btn_first setEnabled:NO];
                                }else {
                                    [btn_first setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                    [btn_first setEnabled:YES];
                                }
                                
                                [btn_first setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                                
                                [btn_first setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                                [btn_first setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                                [btn_first.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                                [btn_first setTitle:[NSString stringWithFormat:@"%d-%d", 21 + 30 * (indexPath.row - 1) ,30 + 30 * (indexPath.row - 1)] forState:UIControlStateNormal];
                                [btn_first setTag:TAG_BTN_QUICKDOWN_FIRST];
                                [btn_first addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                                
                                [cell.contentView addSubview:btn_first];
                                
                                if (0 != ((m_vecChapterList.size() - 20) % 10)) {
                                    UIButton* btn_second = [UIButton buttonWithType:UIButtonTypeCustom];
                                    btn_second.frame = CGRectMake(116.5, 11.5, 87, 44.5);
                                    
                                    bool b_second_all_down = true;
                                    for (int n_itr = (30 + 30 * (indexPath.row - 1)); n_itr < m_vecChapterList.size(); ++n_itr) {
                                        if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                            b_second_all_down = false;
                                            break;
                                        }
                                    }
                                    if (b_second_all_down) {
                                        [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                        [btn_second setEnabled:NO];
                                    }else {
                                        [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                        [btn_second setEnabled:YES];
                                    }
                                    
                                    [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                                    
                                    [btn_second setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                                    [btn_second setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                                    [btn_second.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                                    [btn_second setTitle:[NSString stringWithFormat:@"%d-%lu", 31 + 30 * (indexPath.row - 1) ,m_vecChapterList.size()] forState:UIControlStateNormal];
                                    [btn_second setTag:TAG_BTN_QUICKDOWN_SECOND];
                                    [btn_second addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                                    
                                    [cell.contentView addSubview:btn_second];
                                }
                                
                                break;
                            }
                                
                            case 2:
                            {
                                UIButton* btn_first = [UIButton buttonWithType:UIButtonTypeCustom];
                                btn_first.frame = CGRectMake(12, 11.5, 87, 44.5);
                                
                                bool b_first_all_down = true;
                                for (int n_itr = (20 + 30 * (indexPath.row - 1)); n_itr < (30 + 30 * (indexPath.row - 1)); ++n_itr) {
                                    if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                        b_first_all_down = false;
                                        break;
                                    }
                                }
                                if (b_first_all_down) {
                                    [btn_first setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                    [btn_first setEnabled:NO];
                                }else {
                                    [btn_first setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                    [btn_first setEnabled:YES];
                                }
                                
                                [btn_first setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                                
                                [btn_first setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                                [btn_first setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                                [btn_first.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                                [btn_first setTitle:[NSString stringWithFormat:@"%d-%d", 21 + 30 * (indexPath.row - 1) ,30 + 30 * (indexPath.row - 1)] forState:UIControlStateNormal];
                                [btn_first setTag:TAG_BTN_QUICKDOWN_FIRST];
                                [btn_first addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                                
                                [cell.contentView addSubview:btn_first];
                                
                                UIButton* btn_second = [UIButton buttonWithType:UIButtonTypeCustom];
                                btn_second.frame = CGRectMake(116.5, 11.5, 87, 44.5);
                                
                                bool b_second_all_down = true;
                                for (int n_itr = (30 + 30 * (indexPath.row - 1)); n_itr < (40 + 30 * (indexPath.row - 1)); ++n_itr) {
                                    if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                        b_second_all_down = false;
                                        break;
                                    }
                                }
                                if (b_second_all_down) {
                                    [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                    [btn_second setEnabled:NO];
                                }else {
                                    [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                    [btn_second setEnabled:YES];
                                }
                                
                                [btn_second setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                                
                                [btn_second setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                                [btn_second setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                                [btn_second.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                                [btn_second setTitle:[NSString stringWithFormat:@"%d-%d", 31 + 30 * (indexPath.row - 1) ,(40 + 30 * (indexPath.row - 1))] forState:UIControlStateNormal];
                                [btn_second setTag:TAG_BTN_QUICKDOWN_SECOND];
                                [btn_second addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                                
                                [cell.contentView addSubview:btn_second];
                                
                                
                                if (0 != ((m_vecChapterList.size() - 20) % 10)){
                                    UIButton* btn_third = [UIButton buttonWithType:UIButtonTypeCustom];
                                    btn_third.frame = CGRectMake(221, 11.5, 87, 44.5);
                                    bool b_third_all_down = true;
                                    for(int n_itr = (40 + 30 * (indexPath.row - 1)); n_itr < m_vecChapterList.size(); ++n_itr){
                                        if (!CBookManagement::GetInstance()->HasChapter(m_vecChapterList[n_itr]->m_unRid)) {
                                            b_third_all_down = false;
                                            break;
                                        }
                                    }
                                    if (b_third_all_down) {
                                        [btn_third setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDowned.png") forState:UIControlStateNormal];
                                        [btn_third setEnabled:NO];
                                    }else {
                                        [btn_third setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnUp.png") forState:UIControlStateNormal];
                                        [btn_third setEnabled:YES];
                                    }
                                    
                                    [btn_third setBackgroundImage:CImageMgr::GetImageEx("BookDetailQuickDownBtnDown.png") forState:UIControlStateHighlighted];
                                    
                                    [btn_third setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
                                    [btn_third setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
                                    [btn_third setTitle:[NSString stringWithFormat:@"%d-%lu", (41 + 30 * (indexPath.row - 1)), m_vecChapterList.size()] forState:UIControlStateNormal];
                                    [btn_third.titleLabel setFont:[UIFont systemFontOfSize:m_nChapterDownTitleSize]];
                                    [btn_third setTag:TAG_BTN_QUICKDOWN_THIRD];
                                    [btn_third addTarget:self action:@selector(btnQuickDownClick:) forControlEvents:UIControlEventTouchUpInside];
                                    
                                    [cell.contentView addSubview:btn_third];
                                }
                                
                                break;
                            }
                            default:
                                break;
                        }
                    }
                }
            }
            
            break;
        }
            
        default:
            break;
    }
    if (cell) {
        [cell setBackgroundColor:[UIColor clearColor]];
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    switch (tableView.tag) {
        case TAG_TAB_PLAYLIST:
        {
            [tableView deselectRowAtIndexPath:indexPath animated:NO];
            
            bool b_flow_protect = false;
            KwConfig::GetConfigureInstance()->GetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, b_flow_protect);
            
            s_chapter_list_lock.Lock();
            CChapterInfo* cur_chapter = m_vecChapterList[indexPath.row];
            s_chapter_list_lock.UnLock();
            
            if (CPlayBookList::getInstance()->getCurChapter() && E_AUDIO_PLAY_PLAYING == CAudioPlayerManager::getInstance()->getCurPlayState() && cur_chapter->m_unRid == CPlayBookList::getInstance()->getCurChapter()->m_unRid) {
                return;
            }
            
            if (b_flow_protect && (NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus() && cur_chapter && !CLocalBookRequest::GetInstance()->IsLocalChapter(cur_chapter->m_unRid))) {
                KBAlertView* alert_view = [[KBAlertView alloc] initWithTitle:nil message:@"继续播放会自动关闭流量保护模式，播放会消耗流量" cancelButtonTitle:@"取消" otherButtonTitles:@"继续播放" clickButton:^(NSInteger indexButton) {
                    if (1 == indexButton) {
                        [_activity_view setHidden:NO];
                        [_indicator_view startAnimating];
                        CChapterInfo* local_chapter = CBookManagement::GetInstance()->GetChapterInfo(cur_chapter->m_strBookId, cur_chapter->m_unRid);
                        CRecentBookInfo* recent_book = CRecentBookList::GetInstance()->GetCurBook([[NSString stringWithUTF8String:m_bookInfo.m_strBookId.c_str()] intValue]);
                        if (local_chapter && recent_book && recent_book->m_unIndex == indexPath.row) {
                            CPlayBookList::getInstance()->resetPlayList();
                            CPlayBookList::getInstance()->addChapters(m_vecChapterList);
                            CPlayBookList::getInstance()->setCurPlayIndex(indexPath.row);
                            CPlayBookList::getInstance()->setCurPos(recent_book->m_unPosMilSec);
                        }
                        else if (local_chapter && NULL != CPlayBookList::getInstance()->getCurChapter() && local_chapter->m_strBookId == CPlayBookList::getInstance()->getCurChapter()->m_strBookId) {
                            CPlayBookList::getInstance()->setCurPlayIndex(indexPath.row);
                            CPlayBookList::getInstance()->setCurPos(0);
                        }else {
                            CPlayBookList::getInstance()->resetPlayList();
                            CPlayBookList::getInstance()->addChapters(m_vecChapterList);
                            CPlayBookList::getInstance()->setCurPlayIndex(indexPath.row);
                            CPlayBookList::getInstance()->setCurPos(0);
                        }
                        
                        SYN_NOTIFY(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState::AudioPlayStatusChanged, E_AUDIO_BOOK_CHANGE);
                        
                        KwConfig::GetConfigureInstance()->SetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, false);
                        CAudioPlayerManager::getInstance()->play();
                        SYN_NOTIFY(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect::FlowProtectStatusChange, false);
                        
                        if (!m_bSendUmengLog) {
                            UMengLog(KB_PLAY_SOURCE, STR_PLAY_SOURCE_TYPE[m_ePlaySource_type]);
                            [self sendStatisticData];
                            m_bSendUmengLog = true;
                        }
                        
                        [_table_chapter_list scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
                        [_table_chapter_list reloadData];
                    }
                }];
                [alert_view show];
                
            }else if(!b_flow_protect && (NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus() && cur_chapter && !CPlayBookList::getInstance()->iSLocalChapter(cur_chapter))){
                [iToast defaultShow:@"运营商网络下，注意你的流量喔"];
                
                [_activity_view setHidden:NO];
                [_indicator_view startAnimating];
                CChapterInfo* local_chapter = CBookManagement::GetInstance()->GetChapterInfo(cur_chapter->m_strBookId, cur_chapter->m_unRid);
                CRecentBookInfo* recent_book = CRecentBookList::GetInstance()->GetCurBook([[NSString stringWithUTF8String:m_bookInfo.m_strBookId.c_str()] intValue]);
                if (local_chapter && recent_book && recent_book->m_unIndex == indexPath.row) {
                    CPlayBookList::getInstance()->resetPlayList();
                    CPlayBookList::getInstance()->addChapters(m_vecChapterList);
                    CPlayBookList::getInstance()->setCurPlayIndex(indexPath.row);
                    CPlayBookList::getInstance()->setCurPos(recent_book->m_unPosMilSec);
                }
                else if (local_chapter && NULL != CPlayBookList::getInstance()->getCurChapter() && local_chapter->m_strBookId == CPlayBookList::getInstance()->getCurChapter()->m_strBookId) {
                    CPlayBookList::getInstance()->setCurPlayIndex(indexPath.row);
                    CPlayBookList::getInstance()->setCurPos(0);
                }else {
                    CPlayBookList::getInstance()->resetPlayList();
                    CPlayBookList::getInstance()->addChapters(m_vecChapterList);
                    CPlayBookList::getInstance()->setCurPlayIndex(indexPath.row);
                    CPlayBookList::getInstance()->setCurPos(0);
                }
                
                SYN_NOTIFY(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState::AudioPlayStatusChanged, E_AUDIO_BOOK_CHANGE);
                
                CAudioPlayerManager::getInstance()->play();
                
                if (!m_bSendUmengLog) {
                    UMengLog(KB_PLAY_SOURCE, STR_PLAY_SOURCE_TYPE[m_ePlaySource_type]);
                    [self sendStatisticData];
                    m_bSendUmengLog = true;
                }
                
                [_table_chapter_list scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
                [_table_chapter_list reloadData];
            }else {
                [_activity_view setHidden:NO];
                [_indicator_view startAnimating];
                CChapterInfo* local_chapter = CBookManagement::GetInstance()->GetChapterInfo(cur_chapter->m_strBookId, cur_chapter->m_unRid);
                CRecentBookInfo* recent_book = CRecentBookList::GetInstance()->GetCurBook([[NSString stringWithUTF8String:m_bookInfo.m_strBookId.c_str()] intValue]);
                if (local_chapter && recent_book && recent_book->m_unIndex == indexPath.row) {
                    CPlayBookList::getInstance()->resetPlayList();
                    CPlayBookList::getInstance()->addChapters(m_vecChapterList);
                    CPlayBookList::getInstance()->setCurPlayIndex(indexPath.row);
                    CPlayBookList::getInstance()->setCurPos(recent_book->m_unPosMilSec);
                }
                else if (local_chapter && NULL != CPlayBookList::getInstance()->getCurChapter() && local_chapter->m_strBookId == CPlayBookList::getInstance()->getCurChapter()->m_strBookId) {
                    CPlayBookList::getInstance()->setCurPlayIndex(indexPath.row);
                    CPlayBookList::getInstance()->setCurPos(0);
                }else {
                    CPlayBookList::getInstance()->resetPlayList();
                    CPlayBookList::getInstance()->addChapters(m_vecChapterList);
                    CPlayBookList::getInstance()->setCurPlayIndex(indexPath.row);
                    CPlayBookList::getInstance()->setCurPos(0);
                }
                
                SYN_NOTIFY(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState::AudioPlayStatusChanged, E_AUDIO_BOOK_CHANGE);
                
                CAudioPlayerManager::getInstance()->play();
                
                if (!m_bSendUmengLog) {
                    UMengLog(KB_PLAY_SOURCE, STR_PLAY_SOURCE_TYPE[m_ePlaySource_type]);
                    [self sendStatisticData];
                    m_bSendUmengLog = true;
                }
                
                [_table_chapter_list scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
                [_table_chapter_list reloadData];
            }
            
            break;
        }
        default:
            break;
    }
}

- (BOOL)getChapterList{
    
    std::string str_request_para("");
    switch (m_bookInfo.m_unType) {
        case 1:
        {
            str_request_para += "srcver=storynew&type=music_list&key=album&start=0&count=10000&id=";
            str_request_para += m_bookInfo.m_strBookId;
            break;
        }
        case 2:
        {
            str_request_para += "srcver=storynew&type=sub_list&digest=8&start=0&count=10000&id=";
            str_request_para += m_bookInfo.m_strBookId;
            break;
        }
        default:
            break;
    }
    
    if (0 == str_request_para.size()) {
        return NO;
    }
    
//    KS_BLOCK_DECLARE{
        bool breadcache = false;
        NSDate *date = CCacheMgr::GetInstance()->GetSaveTime(str_request_para);
        double dtemp = [date timeIntervalSinceNow];
        dtemp = -dtemp;
        if(date && dtemp < CACHEOUTTIME)
        {
            breadcache = true;
        }
        else
        {
            if (NETSTATUS_NONE == CHttpRequest::GetNetWorkStatus()) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [_indicator_view stopAnimating];
                    [_activity_view setHidden:YES];
                    
                    [_prompt_view setHidden:NO];
                });
                
                return NO;
            }
            
            
            std::string str_url = KwTools::Encrypt::CreateDesUrl(str_request_para);
            void* pData(NULL);
            char* pContent = NULL;
            char* pZlibContent = NULL;
            std::string strData;
            unsigned uiLen(0);
            UInt32 nZlibLen = 0;
            UInt32 nUnCompressedLen = 0;
            int nTemp = 0;
            int nHeadLen = 0;
            const char* pos = NULL;
            if(CHttpRequest::QuickSyncGet(str_url, pData, uiLen))
            {
                ((char*)pData)[uiLen] = '\0';
                if (0 == strncmp((char*)pData, "TP=none", 7) || 0 != strncmp((char*)pData, "sig=", 4)){
                    breadcache = true;
                }else {
                    pos = strstr((char*)pData, "\r\n");
                    
                    nHeadLen = pos + 2 - (char*)pData;
                    
                    pZlibContent = (char*)pData + nHeadLen;
                    //unCompress
                    memcpy(&nZlibLen, pZlibContent, ZLIB_REF_LEN);
                    pZlibContent += ZLIB_REF_LEN;

                    memcpy(&nUnCompressedLen, pZlibContent, ZLIB_REF_LEN);
                    pZlibContent += ZLIB_REF_LEN;
                    
                    pContent = new char[nUnCompressedLen+1];
                    if (pContent == nil)
                        return NO;
                    
                    int n_dest_len = nUnCompressedLen + 1;
                    if( uncompress((Bytef*)pContent, (uLongf*)&n_dest_len, (Bytef*)pZlibContent, nZlibLen) == 0) {
                        nTemp = n_dest_len;
                    }
                    
                    if (nTemp > nUnCompressedLen) {
                        return NO;
                    }
                    pContent[nTemp] = 0;
                    
                    CCacheMgr::GetInstance()->Cache(T_SECOND, CACHEOUTTIME, str_request_para, pContent, nTemp);
                    
                    breadcache = YES;
                }
                delete[] (char*)pData;
            }
            else
            {
                CCacheMgr::GetInstance()->UpdateTimeToNow(str_request_para);

                breadcache = true;
            }
        }
            
        
        if(breadcache)
        {
            void* pData(NULL);
            unsigned uiLen(0);
            BOOL bouttime;
            NSData* data_xml = nil;
            if(CCacheMgr::GetInstance()->Read(str_request_para, pData, uiLen,bouttime) && uiLen>0)
            {
                ((char*)pData)[uiLen] = '\0';
                data_xml = [[NSData alloc] initWithBytes:pData length:uiLen];
                
                GDataXMLDocument *doc = [[GDataXMLDocument alloc] initWithData:data_xml options:0 error:nil];

                NSArray* arry_chapters = [doc nodesForXPath:@"//music" error:nil];
                for (GDataXMLElement* chapter in arry_chapters) {
                    CChapterInfo* cur_chapter_info = new CLocalTask;
                    cur_chapter_info->m_strName = [[[chapter attributeForName:@"name"] stringValue] UTF8String];
                    cur_chapter_info->m_strArtist = [[[chapter attributeForName:@"artist"] stringValue] UTF8String];
                    cur_chapter_info->m_strBookId = m_bookInfo.m_strBookId;
                    cur_chapter_info->m_strBookName = m_bookInfo.m_strBookTitle;
                    cur_chapter_info->m_unRid = [[[chapter attributeForName:@"rid"] stringValue] integerValue];
                    cur_chapter_info->m_unHotIndex = [[[chapter attributeForName:@"hot"] stringValue] integerValue];
                    cur_chapter_info->m_unDuration = [[[chapter attributeForName:@"duration"] stringValue] integerValue] * 1000;
                    
                    CChapterInfo* chapter_stored = CBookManagement::GetInstance()->GetChapterInfo(cur_chapter_info->m_strBookId, cur_chapter_info->m_unRid);
                    if (NULL != chapter_stored) {
                        cur_chapter_info->m_unDownload = chapter_stored->m_unDownload;
                        ((CLocalTask*)cur_chapter_info)->taskStatus = ((CLocalTask*)chapter_stored)->taskStatus;
                        ((CLocalTask*)cur_chapter_info)->downStatus = ((CLocalTask*)chapter_stored)->downStatus;
                    }else {
                        cur_chapter_info->m_unDownload = 0;
                        ((CLocalTask*)cur_chapter_info)->taskStatus = TaskStatus_Downing;
                        ((CLocalTask*)cur_chapter_info)->downStatus = Status_DowningBook;
                    }
                    
                    KwTools::CAutoLock auto_lock(&s_chapter_list_lock);
                    m_vecChapterList.push_back(cur_chapter_info);
                }
            }
            else
                return NO;
            if(pData)
                delete[] (char*)pData;
        }
    
    return YES;
}

- (CGSize)getTextDrawSize:(NSString*) str_text{
    
    if(isIOS7()){
        NSMutableAttributedString* str_attr = nil;
        str_attr = [[NSMutableAttributedString alloc] initWithString:str_text];
        NSRange range = NSMakeRange(0, str_attr.length);
        [str_attr addAttribute:(NSString *)kCTFontAttributeName value:(id)CFBridgingRelease(CTFontCreateWithName((CFStringRef)[UIFont systemFontOfSize:13].fontName, 13, NULL)) range:range];
        
        NSDictionary* dic = [str_attr attributesAtIndex:0 effectiveRange:&range];
        return [str_text boundingRectWithSize:CGSizeMake(300, 1100) options:NSStringDrawingUsesFontLeading | NSStringDrawingUsesLineFragmentOrigin attributes:dic context:nil].size;
    }else {
        return [str_text sizeWithFont:[UIFont systemFontOfSize:13] constrainedToSize:CGSizeMake(300, 600) lineBreakMode:NSLineBreakByWordWrapping];
    }
}

-(void)IObserverAudioPlayStateChanged:(AudioPlayState)enumStatus{
    [ROOT_NAVI_CONTROLLER setStatus:(AudioPlayControlState)enumStatus];
    if (E_AUDIO_PLAY_PLAYING == enumStatus && E_AUDIO_PLAY_PLAYING == CAudioPlayerManager::getInstance()->getCurPlayState()) {
        if (CPlayBookList::getInstance()->getCurChapter() && CPlayBookList::getInstance()->getCurChapter()->m_strBookId == m_bookInfo.m_strBookId) {
            int n_total = m_vecChapterList.size();
            int n_cur_chapter = -1;
            for (int n_itr = 0; n_itr < n_total; ++n_itr) {
                if (CPlayBookList::getInstance()->getCurChapter()->m_unRid == m_vecChapterList[n_itr]->m_unRid) {
                    n_cur_chapter = n_itr;
                    break;
                }
            }
            if (-1 != n_cur_chapter) {
                NSIndexPath* indexPath = [NSIndexPath indexPathForRow:n_cur_chapter inSection:0];
                [_table_chapter_list scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
                [_table_chapter_list reloadData];
            }
        }
    }
    
    [_activity_view setHidden:YES];
    [_indicator_view stopAnimating];
}

-(void)IObserverCollectListChanged:(int)nBookId
{
    if (nBookId != [[NSString stringWithUTF8String:m_bookInfo.m_strBookId.c_str()] intValue]) {
        return;
    }
    if (CCollectBookList::GetInstance()->GetCurBook([[NSString stringWithUTF8String:m_bookInfo.m_strBookId.c_str()] intValue])) {
        UIButton* button = (UIButton*)[self.view viewWithTag:TAG_BTN_CARE];
        [button setImage:CImageMgr::GetImageEx("BookDetailCared.png") forState:UIControlStateNormal];
    }else {
        UIButton* button = (UIButton*)[self.view viewWithTag:TAG_BTN_CARE];
        [button setImage:CImageMgr::GetImageEx("BookDetailUnCared.png") forState:UIControlStateNormal];
    }
}
#pragma mark
#pragma mark scroll view delegate
/*
-(void)scrollViewDidScroll:(UIScrollView *)sender
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scrollViewDidEndScrollingAnimation:) object:sender];
    [self performSelector:@selector(scrollViewDidEndScrollingAnimation:) withObject:sender afterDelay:0.3];
    if (!_isScrolling) {
        _isScrolling = YES;
        //[self performSelector:@selector(scrollViewBeginScrolling:) withObject:sender];
    }
}
//-(void)scrollViewBeginScrolling:(UIScrollView *)scrollView
//{
//    CGFloat thisOffset = scrollView.contentOffset.y;
//    
//    if (thisOffset > _lastOffset) {
//        [ROOT_NAVI_CONTROLLER hideCenterButton];
//    }
//    else{
//        [ROOT_NAVI_CONTROLLER showCenterButton];
//    }
//    
//    _lastOffset = thisOffset;
//    _isScrolling = NO;
//}
-(void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    CGFloat thisOffset = scrollView.contentOffset.y;
    
    if (thisOffset > _lastOffset) {
        [ROOT_NAVI_CONTROLLER hideCenterButton];
    }
    else{
        [ROOT_NAVI_CONTROLLER showCenterButton];
    }
    
    _lastOffset = thisOffset;
    _isScrolling = NO;
}*/

-(void)scrollViewDidScroll:(UIScrollView *)sender
{
    CGFloat thisOffset = sender.contentOffset.y;
    if (_isDraging) {
        if (thisOffset > _lastOffset) {
            [ROOT_NAVI_CONTROLLER hideCenterButton];
        }
        else{
            [ROOT_NAVI_CONTROLLER showCenterButton];
        }
    }
     _lastOffset = thisOffset;
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    NSLog(@"begin drag");
    _isDraging = YES;
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    NSLog(@"end drag");
    _isDraging = NO;
}

-(void)IObDownStatus_AddTasksFinish{
    UIButton* btn_back = (UIButton*)[_topBar viewWithTag:TAG_BTN_BACK];
    if (btn_back) {
        [btn_back setEnabled:YES];
    }
    
    [_table_chapter_list reloadData];
    [_table_quickdown_list reloadData];
}

-(void)IObDownStatus_AddTask:(unsigned)un_rid{
    int n_index = 0;
    for (std::vector<CChapterInfo*>::iterator cur_iter = m_vecChapterList.begin(); cur_iter != m_vecChapterList.end(); ++cur_iter, ++n_index) {
        if (un_rid == (*cur_iter)->m_unRid) {
            [_table_chapter_list reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:n_index inSection:0]] withRowAnimation:(UITableViewRowAnimationAutomatic)];
            break;
        }
    }
    
    [_table_quickdown_list reloadData];
}

-(void)IObDownStatus_DownTaskFinish:(unsigned)un_rid{
    int n_index = 0;
    for (std::vector<CChapterInfo*>::iterator cur_iter = m_vecChapterList.begin(); cur_iter != m_vecChapterList.end(); ++cur_iter, ++n_index) {
        if (un_rid == (*cur_iter)->m_unRid) {
            [_table_chapter_list reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:n_index inSection:0]] withRowAnimation:(UITableViewRowAnimationAutomatic)];
            break;
        }
    }
}

//-(void)IObDownStatus_DeleteTask{
//    [_table_chapter_list reloadData];
//    [_table_quickdown_list reloadData];
//}
//-(void)IObDownStatus_DeleteTasks{
//    [_table_chapter_list reloadData];
//    [_table_quickdown_list reloadData];
//}

-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
    switch (alertView.tag) {
        case TAG_ALERT_FLOW_PROTECT_PLAY:
        {
            if (1 == buttonIndex) {
                KwConfig::GetConfigureInstance()->SetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, false);
                CAudioPlayerManager::getInstance()->play();
                SYN_NOTIFY(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect::FlowProtectStatusChange, false);
            }
            break;
        }
        case TAG_ALERT_FLOW_PROTECT_QUICK_DOWNLOAD:
        {
            if (1 == buttonIndex) {
                KwConfig::GetConfigureInstance()->SetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, false);
                SYN_NOTIFY(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect::FlowProtectStatusChange, false);
                
                if (m_curDownBtn) {
                    UITableViewCell* cell = nil;
                    if (NSOrderedAscending != [[[UIDevice currentDevice] systemVersion] compare:@"7.0"]) {
                        cell = (UITableViewCell*)[[[m_curDownBtn superview]superview] superview];
                    }else {
                        cell = (UITableViewCell*)[[m_curDownBtn superview]superview];
                    }
                    
                    NSIndexPath* indexPath = [_table_quickdown_list indexPathForCell:cell];
                    
                    switch (m_curDownBtn.tag) {
                        case TAG_BTN_DOWNALL:
                        {
                            UIButton* btn_back = (UIButton*)[_topBar viewWithTag:TAG_BTN_BACK];
                            if (btn_back) {
                                [btn_back setEnabled:NO];
                            }
                            m_bAllDownClicked = true;
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                                CLocalBookRequest::GetInstance()->StartDownTasks(m_vecChapterList);
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [iToast defaultShow:@"已加入下载列表"];
                                });
                            });
                            
                            break;
                        }
                            
                        case TAG_BTN_QUICKDOWN_FIRST:
                        {
                            int n_begin = 20 + 30 * (indexPath.row - 1);
                            int n_end = 30 + 30 * (indexPath.row - 1);
                            
                            n_end = n_end > m_vecChapterList.size() ? m_vecChapterList.size() : n_end;
                            for (int n_itr = n_begin; n_itr < n_end; ++n_itr) {
                                if (0 == m_vecChapterList[n_itr]->m_unDownload) {
                                    m_vecChapterList[n_itr]->m_unDownload = 1;
                                    CLocalBookRequest::GetInstance()->StartDownTask(m_vecChapterList[n_itr]);
                                }
                            }
                            
                            [iToast defaultShow:@"已加入下载列表"];
                            
                            break;
                        }
                            
                        case TAG_BTN_QUICKDOWN_SECOND:
                        {
                            int n_begin = 30 * indexPath.row;
                            int n_end = 10 + 30 * indexPath.row;
                            
                            n_end = n_end > m_vecChapterList.size() ? m_vecChapterList.size() : n_end;
                            for (int n_itr = n_begin; n_itr < n_end; ++n_itr) {
                                if (0 == m_vecChapterList[n_itr]->m_unDownload) {
                                    m_vecChapterList[n_itr]->m_unDownload = 1;
                                    CLocalBookRequest::GetInstance()->StartDownTask(m_vecChapterList[n_itr]);
                                }
                            }
                            
                            [iToast defaultShow:@"已加入下载列表"];
                            
                            break;
                        }
                            
                        case TAG_BTN_QUICKDOWN_THIRD:
                        {
                            int n_begin = 10 + 30 * indexPath.row;
                            int n_end = 20 + 30 * indexPath.row;
                            
                            n_end = n_end > m_vecChapterList.size() ? m_vecChapterList.size() : n_end;
                            for (int n_itr = n_begin; n_itr < n_end; ++n_itr) {
                                if (0 == m_vecChapterList[n_itr]->m_unDownload) {
                                    m_vecChapterList[n_itr]->m_unDownload = 1;
                                    CLocalBookRequest::GetInstance()->StartDownTask(m_vecChapterList[n_itr]);
                                }
                            }
                            
                            [iToast defaultShow:@"已加入下载列表"];
                            
                            break;
                        }
                        default:
                            break;
                            
                    }
                    
                    [m_curDownBtn setEnabled:NO];
                    m_curDownBtn = nil;
                }
            }else if(0 == buttonIndex){
                if (m_curDownBtn) {
                    UITableViewCell* cell = nil;
                    if (NSOrderedAscending != [[[UIDevice currentDevice] systemVersion] compare:@"7.0"]) {
                        cell = (UITableViewCell*)[[[m_curDownBtn superview]superview] superview];
                    }else {
                        cell = (UITableViewCell*)[[m_curDownBtn superview]superview];
                    }
                    
                    NSIndexPath* indexPath = [_table_quickdown_list indexPathForCell:cell];
                    
                    switch (m_curDownBtn.tag) {
                        case TAG_BTN_DOWNALL:
                        {
                            UIButton* btn_back = (UIButton*)[_topBar viewWithTag:TAG_BTN_BACK];
                            if (btn_back) {
                                [btn_back setEnabled:NO];
                            }
                            m_bAllDownClicked = true;
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                                CLocalBookRequest::GetInstance()->AddWaitingTasks(m_vecChapterList);
                                
                            });
                            [iToast defaultShow:@"已加入下载列表"];
                            break;
                        }
                            
                        case TAG_BTN_QUICKDOWN_FIRST:
                        {
                            int n_begin = 20 + 30 * (indexPath.row - 1);
                            int n_end = 30 + 30 * (indexPath.row - 1);
                            
                            n_end = n_end > m_vecChapterList.size() ? m_vecChapterList.size() : n_end;
                            for (int n_itr = n_begin; n_itr < n_end; ++n_itr) {
                                if (0 == m_vecChapterList[n_itr]->m_unDownload) {
                                    m_vecChapterList[n_itr]->m_unDownload = 1;
                                    CLocalBookRequest::GetInstance()->AddWaitingTask(m_vecChapterList[n_itr]);
                                }
                            }
                            
                            [iToast defaultShow:@"已加入下载列表"];
                            break;
                        }
                            
                        case TAG_BTN_QUICKDOWN_SECOND:
                        {
                            int n_begin = 30 * indexPath.row;
                            int n_end = 10 + 30 * indexPath.row;
                            
                            n_end = n_end > m_vecChapterList.size() ? m_vecChapterList.size() : n_end;
                            for (int n_itr = n_begin; n_itr < n_end; ++n_itr) {
                                if (0 == m_vecChapterList[n_itr]->m_unDownload) {
                                    m_vecChapterList[n_itr]->m_unDownload = 1;
                                    CLocalBookRequest::GetInstance()->AddWaitingTask(m_vecChapterList[n_itr]);
                                }
                            }
                            
                            [iToast defaultShow:@"已加入下载列表"];
                            
                            break;
                        }
                            
                        case TAG_BTN_QUICKDOWN_THIRD:
                        {
                            int n_begin = 10 + 30 * indexPath.row;
                            int n_end = 20 + 30 * indexPath.row;
                            
                            n_end = n_end > m_vecChapterList.size() ? m_vecChapterList.size() : n_end;
                            for (int n_itr = n_begin; n_itr < n_end; ++n_itr) {
                                if (0 == m_vecChapterList[n_itr]->m_unDownload) {
                                    m_vecChapterList[n_itr]->m_unDownload = 1;
                                    CLocalBookRequest::GetInstance()->StartDownTask(m_vecChapterList[n_itr]);
                                }
                            }
                            
                            [iToast defaultShow:@"已加入下载列表"];
                            
                            break;
                        }
                        default:
                            break;
                            
                    }
                    
                    [m_curDownBtn setEnabled:NO];
                    m_curDownBtn = nil;
                }
            }
            break;
        }
        case TAG_ALERT_FLOW_PROTECT_DOWNLOAD:
        {
            if (1 == buttonIndex) {
                KwConfig::GetConfigureInstance()->SetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, false);
                SYN_NOTIFY(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect::FlowProtectStatusChange, false);
                
                CLocalBookRequest::GetInstance()->StartDownTask(m_vecChapterList[m_curIndexPath.row]);
            }else if(0 == buttonIndex){
                CLocalBookRequest::GetInstance()->AddWaitingTask(m_vecChapterList[m_curIndexPath.row]);
            }
            
            [iToast defaultShow:@"已加入下载列表"];
            m_curIndexPath = nil;
            
            break;
        }
            
        case TAG_ALERT_QUICK_DOWN_CONFIRM:{
            if (1 == buttonIndex) {
                if (m_curDownBtn) {
                    UITableViewCell* cell = nil;
                    if (NSOrderedAscending != [[[UIDevice currentDevice] systemVersion] compare:@"7.0"]) {
                        cell = (UITableViewCell*)[[[m_curDownBtn superview]superview] superview];
                    }else {
                        cell = (UITableViewCell*)[[m_curDownBtn superview]superview];
                    }
                    
                    NSIndexPath* indexPath = [_table_quickdown_list indexPathForCell:cell];
                    
                    switch (m_curDownBtn.tag) {
                        case TAG_BTN_DOWNALL:
                        {
                            UIButton* btn_back = (UIButton*)[_topBar viewWithTag:TAG_BTN_BACK];
                            if (btn_back) {
                                [btn_back setEnabled:NO];
                            }
                            m_bAllDownClicked = true;
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                                CLocalBookRequest::GetInstance()->StartDownTasks(m_vecChapterList);
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [iToast defaultShow:@"已加入下载列表"];
                                });
                            });
                            
                            break;
                        }
                            
                        case TAG_BTN_QUICKDOWN_FIRST:
                        {
                            int n_begin = 20 + 30 * (indexPath.row - 1);
                            int n_end = 30 + 30 * (indexPath.row - 1);
                            
                            n_end = n_end > m_vecChapterList.size() ? m_vecChapterList.size() : n_end;
                            for (int n_itr = n_begin; n_itr < n_end; ++n_itr) {
                                if (0 == m_vecChapterList[n_itr]->m_unDownload) {
                                    m_vecChapterList[n_itr]->m_unDownload = 1;
                                    CLocalBookRequest::GetInstance()->StartDownTask(m_vecChapterList[n_itr]);
                                }
                            }
                            
                            [iToast defaultShow:@"已加入下载列表"];
                            
                            break;
                        }
                            
                        case TAG_BTN_QUICKDOWN_SECOND:
                        {
                            int n_begin = 30 * indexPath.row;
                            int n_end = 10 + 30 * indexPath.row;
                            
                            n_end = n_end > m_vecChapterList.size() ? m_vecChapterList.size() : n_end;
                            for (int n_itr = n_begin; n_itr < n_end; ++n_itr) {
                                if (0 == m_vecChapterList[n_itr]->m_unDownload) {
                                    m_vecChapterList[n_itr]->m_unDownload = 1;
                                    CLocalBookRequest::GetInstance()->StartDownTask(m_vecChapterList[n_itr]);
                                }
                            }
                            
                            [iToast defaultShow:@"已加入下载列表"];
                            
                            break;
                        }
                            
                        case TAG_BTN_QUICKDOWN_THIRD:
                        {
                            int n_begin = 10 + 30 * indexPath.row;
                            int n_end = 20 + 30 * indexPath.row;
                            
                            n_end = n_end > m_vecChapterList.size() ? m_vecChapterList.size() : n_end;
                            for (int n_itr = n_begin; n_itr < n_end; ++n_itr) {
                                if (0 == m_vecChapterList[n_itr]->m_unDownload) {
                                    m_vecChapterList[n_itr]->m_unDownload = 1;
                                    CLocalBookRequest::GetInstance()->StartDownTask(m_vecChapterList[n_itr]);
                                }
                            }
                            
                            [iToast defaultShow:@"已加入下载列表"];
                            
                            break;
                        }
                        default:
                            break;
                            
                    }
                    
                    [m_curDownBtn setEnabled:NO];
                    m_curDownBtn = nil;
                }
            }
        }
        default:
            break;
    }
}

@end
