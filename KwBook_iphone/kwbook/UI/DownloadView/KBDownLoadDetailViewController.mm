//
//  KBDownLoadDetailViewController.m
//  kwbook
//
//  Created by 单 永杰 on 13-12-9.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import "KBDownLoadDetailViewController.h"
#include <vector>
#include "ChapterInfo.h"
#include "LocalBookRequest.h"
#include "ImageMgr.h"
#include "globalm.h"
#include "IObserverDownTaskStatus.h"
#include "MessageManager.h"
#include "KBAppDelegate.h"
#include <zlib.h>
#import "GDataXMLNode.h"
#include "CacheMgr.h"
#include "BookInfoList.h"
#include "KwTools.h"
#include "PlayBookList.h"
#include "AudioPlayerManager.h"
#import "iToast.h"

#include "KwUMengElement.h"
#include "UMengLog.h"
#include "BookManagement.h"
#include "KwConfig.h"
#include "KwConfigElements.h"

#define CACHEOUTTIME    3*24*60*60 // 3 day
#define ZLIB_REF_LEN 4

#define COLOR_FONT_BLUE 0x028bd0
#define COLOR_FONT_GRAY 0x515151

#define TAG_BTN_CLEAR     100
#define TAG_BTN_BACK      101
#define TAG_BTN_FINISH    102
#define TAG_BTN_UNFINISH  103

#define TAG_LAB_DOWNED_CHAPTER           104
#define TAG_BTN_DELETE_DOWNED_CHAPTER    105

#define TAG_LAB_DOWNING_CHAPTER          106
#define TAG_BTN_DELETE_DOWNING_CHAPTER   107

#define TAG_BTN_ALL_START     108
#define TAG_BTN_ALL_PAUSE     109
#define TAG_BTN_ALL_DELETE    110

#define TAG_IMG_DOWNING_CONTROL          111
#define TAG_PROGRESS_DOWNING_CHAPTER     112
#define TAG_LAB_PROGRESS_DOWNING_CHAPTER 113

#define TAG_TABLE_DOWNED_CHAPTER_LIST    114
#define TAG_TABLE_DOWNING_CHAPTER_LIST   115

#define TAG_DOWNED_ALERT           116
#define TAG_DOWNING_ALERT          117

#define TAG_LAB_PROMPT             118

#define TAG_ALERT_ALL_START        119
#define TAG_ALERT_SINGLE_START     120

static KwTools::CLock s_cur_chapter_list_lock;

@interface KBDownLoadDetailViewController ()<UITableViewDataSource, UITableViewDelegate, IObserverDownTaskStatus, IObserverAudioPlayState, UIAlertViewDelegate>{
    std::vector<CChapterInfo*> m_vecChapterDowned;
    std::vector<CChapterInfo*> m_vecChapterDowning;
    
    std::vector<CChapterInfo*> m_vecChapterList;
    
    BOOL m_bFinishTable;
    
    BOOL    _isDraging;
    float   _lastOffset;
    
    int m_nRowClicked;
    
    bool m_bSendUmengLog;
    
    NSIndexPath* m_curIndexPath;
}

@property (nonatomic, strong) NSString*     strBookid;
@property (nonatomic, strong) UIView*       topBar;
@property (nonatomic, strong) UITableView*  tableView;
@property (nonatomic, strong) UIView* tab_background;
@property (nonatomic, strong) UIImageView* open_flag_view;
@property (nonatomic, strong) UITableView* finish_chapter_list;
@property (nonatomic, strong) UITableView* unfinish_chapter_list;
@property (nonatomic, strong) NSMutableDictionary* dic_downing_key_value;

@property (nonatomic, strong) UIView* prompt_view;

@end

@implementation KBDownLoadDetailViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _isDraging = NO;
        _lastOffset = 0.0f;
        m_curIndexPath = nil;
    }
    return self;
}

-(id)initWithBookid:(NSString*)str_book_id{
    self = [super init];
    if (self) {
        _strBookid = str_book_id;
    }
    
    m_nRowClicked = -1;
    m_bSendUmengLog = false;
    
    CBookManagement::GetInstance()->GetBookDownList([_strBookid UTF8String], m_vecChapterDowned, m_vecChapterDowning);
    _dic_downing_key_value = [[NSMutableDictionary alloc] initWithCapacity:m_vecChapterDowning.size()];
    int n_total = m_vecChapterDowning.size();
    for (int n_itr = 0; n_itr < n_total; ++n_itr) {
        [_dic_downing_key_value setObject:[NSString stringWithFormat:@"%d", n_itr] forKey:[NSString stringWithFormat:@"%d", m_vecChapterDowning[n_itr]->m_unRid]];
    }
    
    GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus);
    GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
    
    return self;
}

-(void)reloadDowningDic{
    [_dic_downing_key_value removeAllObjects];
    int n_total = m_vecChapterDowning.size();
    for (int n_itr = 0; n_itr < n_total; ++n_itr) {
        [_dic_downing_key_value setObject:[NSString stringWithFormat:@"%d", n_itr] forKey:[NSString stringWithFormat:@"%d", m_vecChapterDowning[n_itr]->m_unRid]];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    m_bFinishTable = YES;
    float gap = 0.0;
    if (isIOS7()) {
        gap = 20;
    }
    
    float width  = self.view.bounds.size.width;

    [self.view setBackgroundColor:UIColorFromRGBValue(0xf0ebe3)];
    self.topBar = ({
        UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 44+gap)];
        UIImageView *backView = [[UIImageView alloc] initWithFrame:topBar.bounds];
        if (isIOS7()) {
            [backView setImage:CImageMgr::GetImageEx("RecoTopBackFor7.png")];
        }
        else{
            [backView setImage:CImageMgr::GetImageEx("RecoTopBackFor6.png")];
        }
        [topBar addSubview:backView];
        
        UIButton *clear_button = [UIButton buttonWithType:UIButtonTypeCustom];
        [clear_button setFrame:CGRectMake(270, gap, 44, 44)];
        [clear_button setBackgroundColor:[UIColor clearColor]];
        [clear_button setTitle:@"清空" forState:(UIControlStateNormal)];
        [clear_button setTag:TAG_BTN_CLEAR];
        [clear_button addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [topBar addSubview:clear_button];
        
        UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [backBtn setImage:CImageMgr::GetImageEx("TopBackBtn.png") forState:UIControlStateNormal];
        [backBtn setFrame:CGRectMake(0, gap, 44, 44)];
        [backBtn setTag:TAG_BTN_BACK];
        [backBtn addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [topBar addSubview:backBtn];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, gap, 180, 44)];
        [titleLabel setText:[NSString stringWithUTF8String:CBookInfoList::getInstance()->getBookInfo([_strBookid UTF8String])->m_strBookTitle.c_str()]];
        [titleLabel setTextAlignment:NSTextAlignmentCenter];
        [titleLabel setTextColor:[UIColor whiteColor]];
        [titleLabel setBackgroundColor:[UIColor clearColor]];
        [titleLabel setFont:[UIFont systemFontOfSize:20.0]];
        [topBar addSubview:titleLabel];
        topBar;
    });
    [[self view] addSubview:_topBar];
    
    _tab_background = [[UIView alloc] initWithFrame:CGRectMake(0, _topBar.frame.origin.y + _topBar.frame.size.height, 320, 44)];
    UIImageView* img_background = [[UIImageView alloc] initWithImage:CImageMgr::GetImageEx("DownloadManageTabBackground.png")];
    img_background.frame = CGRectMake(0, 0, 320, 44);
    [_tab_background addSubview:img_background];
    
    [self.view addSubview:_tab_background];
    
    _open_flag_view = [[UIImageView alloc] initWithImage:CImageMgr::GetImageEx("BookDetailClick.png")];
    _open_flag_view.frame = CGRectMake(73, 38, 14, 6);
    [_tab_background addSubview:_open_flag_view];
    
    UIButton* btn_finish = [UIButton buttonWithType:UIButtonTypeCustom];
    btn_finish.frame = CGRectMake(0, 0, 160, 44);
    [btn_finish setBackgroundColor:[UIColor clearColor]];
    [btn_finish setTag:TAG_BTN_FINISH];
    [btn_finish.titleLabel setFont:[UIFont systemFontOfSize:15]];
    [btn_finish setTitle:@"已完成" forState:(UIControlStateNormal)];
    [btn_finish setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
    [btn_finish addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [_tab_background addSubview:btn_finish];
    
    UIButton* btn_unfinish = [UIButton buttonWithType:UIButtonTypeCustom];
    btn_unfinish.frame = CGRectMake(160, 0, 160, 44);
    [btn_unfinish setBackgroundColor:[UIColor clearColor]];
    [btn_unfinish setTag:TAG_BTN_UNFINISH];
    [btn_unfinish.titleLabel setFont:[UIFont systemFontOfSize:15]];
    [btn_unfinish setTitle:@"未完成" forState:(UIControlStateNormal)];
    [btn_unfinish setTitleColor:UIColorFromRGBValue(COLOR_FONT_GRAY) forState:UIControlStateNormal];
    [btn_unfinish addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [_tab_background addSubview:btn_unfinish];

    _finish_chapter_list = [[UITableView alloc] initWithFrame:CGRectMake(0, _tab_background.frame.origin.y + _tab_background.frame.size.height, 320, self.view.frame.size.height - _topBar.frame.size.height - 44)];
    [_finish_chapter_list setBackgroundColor:UIColorFromRGBValue(0xf0ebe3)];
    [_finish_chapter_list setTag:TAG_TABLE_DOWNED_CHAPTER_LIST];
    _finish_chapter_list.allowsSelection = NO;
    
    _unfinish_chapter_list = [[UITableView alloc] initWithFrame:CGRectMake(0, _tab_background.frame.origin.y + _tab_background.frame.size.height, 320, self.view.frame.size.height - _topBar.frame.size.height - 44)];
    [_unfinish_chapter_list setBackgroundColor:UIColorFromRGBValue(0xf0ebe3)];
    [_unfinish_chapter_list setTag:TAG_TABLE_DOWNING_CHAPTER_LIST];
    _unfinish_chapter_list.hidden = YES;
    
    [_finish_chapter_list setDelegate:self];
    [_finish_chapter_list setDataSource:self];
    
    [_unfinish_chapter_list setDelegate:self];
    [_unfinish_chapter_list setDataSource:self];
    
    [self.view addSubview:_finish_chapter_list];
    [self.view addSubview:_unfinish_chapter_list];
    
    _prompt_view = [[UIView alloc] initWithFrame:_finish_chapter_list.frame];
    [_prompt_view setBackgroundColor:[UIColor clearColor]];
    UILabel* label_prompt = [[UILabel alloc] initWithFrame:CGRectMake(0, self.unfinish_chapter_list.frame.size.height/2, 320, 20)];
    [label_prompt setBackgroundColor:[UIColor clearColor]];
    [label_prompt setTextColor:defaultGrayColor()];
    [label_prompt setTextAlignment:NSTextAlignmentCenter];
    [label_prompt setTag:TAG_LAB_PROMPT];
    [_prompt_view addSubview:label_prompt];
    [self.view addSubview:_prompt_view];
    
    if (0 == m_vecChapterDowned.size()) {
        [label_prompt setText:@"还没有下载完成的任务哦"];
        [_prompt_view setHidden:NO];
    }else {
        [_prompt_view setHidden:YES];
    }
    
    [_finish_chapter_list reloadData];
    [_unfinish_chapter_list reloadData];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self getChapterList];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            _finish_chapter_list.allowsSelection = YES;
        });
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)onBtnClick : (id)sender{
    UIButton* button = (UIButton*)sender;
    switch (button.tag) {
        case TAG_BTN_BACK:
        {
            GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus);
            GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
            [self.navigationController popViewControllerAnimated:YES];
            break;
        }
            
        case TAG_BTN_FINISH:
        {
            _open_flag_view.frame = CGRectMake(73, 38, 14, 6);
            [button setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
            
            UIButton* btn_unfinish = (UIButton*)[_tab_background viewWithTag:TAG_BTN_UNFINISH];
            if (btn_unfinish) {
                [btn_unfinish setTitleColor:UIColorFromRGBValue(COLOR_FONT_GRAY) forState:UIControlStateNormal];
            }
            m_bFinishTable = YES;
            [_unfinish_chapter_list setHidden:YES];
            [_finish_chapter_list setHidden:NO];
            
            if (0 == m_vecChapterDowned.size()) {
                UILabel* label_prompt = (UILabel*)[_prompt_view viewWithTag:TAG_LAB_PROMPT];
                [label_prompt setText:@"还没有下载完成的任务哦"];
                [_prompt_view setHidden:NO];
            }else{
                [_prompt_view setHidden:YES];
            }
            
            UIButton* btn_clear = (UIButton*)[_topBar viewWithTag:TAG_BTN_CLEAR];
            if (btn_clear) {
                [btn_clear setHidden:NO];
            }
            
            break;
        }
        case TAG_BTN_UNFINISH:
        {
            _open_flag_view.frame = CGRectMake(247, 38, 14, 6);
            [button setTitleColor:UIColorFromRGBValue(COLOR_FONT_BLUE) forState:UIControlStateNormal];
            
            UIButton* btn_finish = (UIButton*)[_tab_background viewWithTag:TAG_BTN_FINISH];
            if (btn_finish) {
                [btn_finish setTitleColor:UIColorFromRGBValue(COLOR_FONT_GRAY) forState:UIControlStateNormal];
            }
            m_bFinishTable = NO;
            [_finish_chapter_list setHidden:YES];
            [_unfinish_chapter_list setHidden:NO];
            
            UIButton* btn_clear = (UIButton*)[_topBar viewWithTag:TAG_BTN_CLEAR];
            if (btn_clear) {
                [btn_clear setHidden:YES];
            }
            
            if (0 == m_vecChapterDowning.size()) {
                UILabel* label_prompt = (UILabel*)[_prompt_view viewWithTag:TAG_LAB_PROMPT];
                [label_prompt setText:@"没有未完成的下载任务哦"];
                [_prompt_view setHidden:NO];
            }else{
                [_prompt_view setHidden:YES];
            }
            
            break;
        }
            
        case TAG_BTN_DELETE_DOWNING_CHAPTER:
        {
            UITableViewCell* cell = nil;
            if (NSOrderedAscending != [[[UIDevice currentDevice] systemVersion] compare:@"7.0"]) {
                cell = (UITableViewCell*)[[[(UIButton*)sender superview]superview] superview];
            }else {
                cell = (UITableViewCell*)[[(UIButton*)sender superview]superview];
            }
            if (cell) {
                NSIndexPath* indexPath = [_unfinish_chapter_list indexPathForCell:cell];
                CChapterInfo* chapter_info = m_vecChapterDowning[indexPath.row - 1];
                if (chapter_info){
                    CLocalBookRequest::GetInstance()->DeleteTask(chapter_info);
                }
            }
            break;
        }
        case TAG_BTN_DELETE_DOWNED_CHAPTER:
        {
            UITableViewCell* cell = nil;
            if (NSOrderedAscending != [[[UIDevice currentDevice] systemVersion] compare:@"7.0"]) {
                cell = (UITableViewCell*)[[[(UIButton*)sender superview]superview] superview];
            }else {
                cell = (UITableViewCell*)[[(UIButton*)sender superview]superview];
            }
            if (cell){
                NSIndexPath* indexPath = [_finish_chapter_list indexPathForCell:cell];
                CChapterInfo* chapter_info = m_vecChapterDowned[indexPath.row];
                if (chapter_info){
                    CLocalBookRequest::GetInstance()->DeleteTask(chapter_info);
                }
            }
            
            break;
        }
        case TAG_BTN_ALL_START:
        {
            if (NETSTATUS_NONE == CHttpRequest::GetNetWorkStatus()) {
                [iToast defaultShow:@"网络似乎断开了，请检查连接"];
                return;
            }
            
            bool b_flow_protect = false;
            KwConfig::GetConfigureInstance()->GetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, b_flow_protect);
            if (b_flow_protect && NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus()){
                UIAlertView* alert_view = [[UIAlertView alloc] initWithTitle:nil message:@"已开启流量保护，现在下载会消耗较多流量喔？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"现在下载", nil];
                [alert_view setTag:TAG_ALERT_ALL_START];
                [alert_view show];
            }else {
                CLocalBookRequest::GetInstance()->StartAllTask([_strBookid UTF8String]);
            }
            break;
        }
            
        case TAG_BTN_ALL_PAUSE:
        {
            CLocalBookRequest::GetInstance()->PauseAllTasks([_strBookid UTF8String]);
            break;
        }
            
        case TAG_BTN_ALL_DELETE:
        {
            if (0 == m_vecChapterDowning.size()) {
                return;
            }
            UIAlertView* alert = [[UIAlertView alloc]initWithTitle:@""
                                                           message:@"确定要清空所有下载任务？"
                                                          delegate:self
                                                 cancelButtonTitle:@"取消"
                                                 otherButtonTitles:@"确定", nil];
            [alert setTag:TAG_DOWNING_ALERT];
            [alert show];
            
            break;
        }
            
        case TAG_BTN_CLEAR:
        {
            if (0 == m_vecChapterDowned.size()) {
                return;
            }
            UIAlertView* alert = [[UIAlertView alloc]initWithTitle:@""
                                                           message:@"确定要清空所有已下载任务？"
                                                          delegate:self
                                                 cancelButtonTitle:@"取消"
                                                 otherButtonTitles:@"确定", nil];
            [alert setTag:TAG_DOWNED_ALERT];
            [alert show];
            
            break;
        }
        default:
            break;
    }
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if (TAG_TABLE_DOWNED_CHAPTER_LIST == tableView.tag) {
        return m_vecChapterDowned.size();
    }else {
        if (m_vecChapterDowning.size()) {
            return 1 + m_vecChapterDowning.size();
        }else {
            return 0;
        }
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    if (TAG_TABLE_DOWNED_CHAPTER_LIST == tableView.tag) {
        return 43;
    }else{
        if (0 == indexPath.row) {
            return 50;
        }else {
            if (isIOS7()) {
                return 63;
            }else {
                return 70;
            }
            
        }
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString* str_cell_downed_identifier = @"strCellDownedIdentifier";
    static NSString* str_cell_downing_identifier = @"strCellDowningIdentifier";
    
    UITableViewCell* cell = nil;
    
    if (TAG_TABLE_DOWNED_CHAPTER_LIST == tableView.tag) {
        if (E_AUDIO_PLAY_PLAYING == CAudioPlayerManager::getInstance()->getCurPlayState() && NULL != CPlayBookList::getInstance()->getCurChapter() && CPlayBookList::getInstance()->getCurChapter()->m_unRid == m_vecChapterDowned[indexPath.row]->m_unRid) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            UILabel* lab_title = [[UILabel alloc] initWithFrame:CGRectMake(20, 12, 250, 19)];
            [lab_title setTag:TAG_LAB_DOWNED_CHAPTER];
            [lab_title setTextColor:defaultBlackColor()];
            [lab_title setBackgroundColor:[UIColor clearColor]];
            [cell.contentView addSubview:lab_title];
            [lab_title setText:[NSString stringWithUTF8String:m_vecChapterDowned[indexPath.row]->m_strName.c_str()]];
            
            UIImageView* play_image = [[UIImageView alloc] initWithFrame:CGRectMake(10, 16.5, 7.5, 10)];
            [play_image setImage:CImageMgr::GetImageEx("BookDetailChapterListPlay.png")];
            [cell.contentView addSubview:play_image];
            
            UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.frame = CGRectMake(281, 5, 33, 33);
            button.imageEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
            [button setBackgroundColor:[UIColor clearColor]];
            [button setImage:CImageMgr::GetImageEx("SearchHistoryDelete.png") forState:(UIControlStateNormal)];
            [button setTag:TAG_BTN_DELETE_DOWNED_CHAPTER];
            [button addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
            
            [cell.contentView addSubview:button];
        }else {
            cell = [tableView dequeueReusableCellWithIdentifier:str_cell_downed_identifier];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:str_cell_downed_identifier];
                UILabel* lab_title = [[UILabel alloc] initWithFrame:CGRectMake(20, 12, 250, 19)];
                [lab_title setTag:TAG_LAB_DOWNED_CHAPTER];
                [lab_title setTextColor:defaultBlackColor()];
                [lab_title setBackgroundColor:[UIColor clearColor]];
                [cell.contentView addSubview:lab_title];
                
                UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
                button.frame = CGRectMake(281, 5, 33, 33);
                button.imageEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
                [button setBackgroundColor:[UIColor clearColor]];
                [button setImage:CImageMgr::GetImageEx("SearchHistoryDelete.png") forState:(UIControlStateNormal)];
                [button setTag:TAG_BTN_DELETE_DOWNED_CHAPTER];
                [button addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
                
                [cell.contentView addSubview:button];
            }
            
            UILabel* lab_title = (UILabel*)[cell.contentView viewWithTag:TAG_LAB_DOWNED_CHAPTER];
            if (lab_title) {
                [lab_title setText:[NSString stringWithUTF8String:m_vecChapterDowned[indexPath.row]->m_strName.c_str()]];
            }
        }
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }else {
        if (0 == indexPath.row) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            UIButton* btn_all_start = [UIButton buttonWithType:UIButtonTypeCustom];
            [btn_all_start setBackgroundColor:[UIColor clearColor]];
            btn_all_start.frame = CGRectMake(24, 12, 70, 26);
            [btn_all_start setTag:TAG_BTN_ALL_START];
            [btn_all_start addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
            [btn_all_start setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [btn_all_start setTitle:@"全部开始" forState:(UIControlStateNormal)];
            [btn_all_start.titleLabel setFont:[UIFont systemFontOfSize:14]];
            [btn_all_start setBackgroundImage:CImageMgr::GetImageEx("DownloadManageBtnDown.png") forState:(UIControlStateNormal)];
            [btn_all_start setBackgroundImage:CImageMgr::GetImageEx("DownloadManageBtnUp.png") forState:(UIControlStateHighlighted)];
            [cell.contentView addSubview:btn_all_start];
            
            UIButton* btn_all_pause = [UIButton buttonWithType:UIButtonTypeCustom];
            [btn_all_pause setBackgroundColor:[UIColor clearColor]];
            btn_all_pause.frame = CGRectMake(125, 12, 70, 26);
            [btn_all_pause setTag:TAG_BTN_ALL_PAUSE];
            [btn_all_pause addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
            [btn_all_pause setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [btn_all_pause setTitle:@"全部暂停" forState:(UIControlStateNormal)];
            [btn_all_pause.titleLabel setFont:[UIFont systemFontOfSize:14]];
            [btn_all_pause setBackgroundImage:CImageMgr::GetImageEx("DownloadManageBtnDown.png") forState:(UIControlStateNormal)];
            [btn_all_pause setBackgroundImage:CImageMgr::GetImageEx("DownloadManageBtnUp.png") forState:(UIControlStateHighlighted)];
            [cell.contentView addSubview:btn_all_pause];
            
            UIButton* btn_all_delete = [UIButton buttonWithType:UIButtonTypeCustom];
            [btn_all_delete setBackgroundColor:[UIColor clearColor]];
            btn_all_delete.frame = CGRectMake(226, 12, 70, 26);
            [btn_all_delete setTag:TAG_BTN_ALL_DELETE];
            [btn_all_delete addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
            [btn_all_delete setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [btn_all_delete.titleLabel setFont:[UIFont systemFontOfSize:14]];
            [btn_all_delete setTitle:@"全部删除" forState:(UIControlStateNormal)];
            [btn_all_delete setBackgroundImage:CImageMgr::GetImageEx("DownloadManageBtnDown.png") forState:(UIControlStateNormal)];
            [btn_all_delete setBackgroundImage:CImageMgr::GetImageEx("DownloadManageBtnUp.png") forState:(UIControlStateHighlighted)];
            [cell.contentView addSubview:btn_all_delete];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }else {
            cell = [tableView dequeueReusableCellWithIdentifier:str_cell_downing_identifier];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:str_cell_downing_identifier];
                UIImageView* image_down_ctrl = [[UIImageView alloc] initWithFrame:CGRectMake(17, 22.5, 20, 18)];
                [image_down_ctrl setBackgroundColor:[UIColor clearColor]];
                [image_down_ctrl setTag:TAG_IMG_DOWNING_CONTROL];
                [cell.contentView addSubview:image_down_ctrl];
                
                UILabel* lab_downing_chapter = [[UILabel alloc] initWithFrame:CGRectMake(43, 9, 225, 18)];
                [lab_downing_chapter setBackgroundColor:[UIColor clearColor]];
                [lab_downing_chapter setTextColor:defaultBlackColor()];
                [lab_downing_chapter setTag:TAG_LAB_DOWNING_CHAPTER];
                [lab_downing_chapter setFont:[UIFont systemFontOfSize:18]];
                [cell.contentView addSubview:lab_downing_chapter];;
                
                UILabel* lab_progress = [[UILabel alloc] initWithFrame:CGRectMake(43, 42, 140, 12)];
                [lab_progress setTextColor:defaultGrayColor()];
                [lab_progress setBackgroundColor:[UIColor clearColor]];
                [lab_progress setTag:TAG_LAB_PROGRESS_DOWNING_CHAPTER];
                [lab_progress setFont:[UIFont systemFontOfSize:13]];
                [cell.contentView addSubview:lab_progress];
                
                UIButton* btn_delete = [UIButton buttonWithType:UIButtonTypeCustom];
                btn_delete.frame = CGRectMake(281.5, 10, 43, 43);
                btn_delete.imageEdgeInsets = UIEdgeInsetsMake(11, 11, 11, 11);
                [btn_delete setBackgroundColor:[UIColor clearColor]];
                [btn_delete setImage:CImageMgr::GetImageEx("SearchHistoryDelete.png") forState:(UIControlStateNormal)];
                [btn_delete setTag:TAG_BTN_DELETE_DOWNING_CHAPTER];
                [btn_delete addTarget:self action:@selector(onBtnClick:) forControlEvents:UIControlEventTouchUpInside];
                [cell.contentView addSubview:btn_delete];
                
                UIProgressView* progress_downing = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
                [progress_downing setBackgroundColor:[UIColor clearColor]];
                progress_downing.frame = CGRectMake(17, 60, 286, 2);
                progress_downing.progressTintColor = UIColorFromRGBValue(0x0892d3);
                progress_downing.trackTintColor = [UIColor clearColor];
                [progress_downing setTag:TAG_PROGRESS_DOWNING_CHAPTER];
                [cell.contentView addSubview:progress_downing];
                
                cell.selectionStyle = UITableViewCellSelectionStyleGray;
            }
            
            UIImageView* img_ctrl = (UIImageView*)[cell.contentView viewWithTag:TAG_IMG_DOWNING_CONTROL];
            if (img_ctrl) {
                switch (((CLocalTask*)CBookManagement::GetInstance()->GetChapterInfo(m_vecChapterDowning[indexPath.row - 1]->m_strBookId, m_vecChapterDowning[indexPath.row - 1]->m_unRid))->taskStatus) {
                    case TaskStatus_Waiting:
                    {
                        [img_ctrl setImage:CImageMgr::GetImageEx("DownloadManageDownloadWaiting.png")];
                        break;
                    }
                    case TaskStatus_Downing:
                    {
                        [img_ctrl setImage:CImageMgr::GetImageEx("DownloadManageDownloading.png")];
                        break;
                    }
                    case TaskStatus_Pause:
                    {
                        [img_ctrl setImage:CImageMgr::GetImageEx("DownloadManageDownloadPause.png")];
                        break;
                    }
                    case TaskStatus_Fail:
                    {
                        [img_ctrl setImage:CImageMgr::GetImageEx("DownloadManageDownloadFail.png")];
                        break;
                    }
                    default:
                        break;
                }
            }
            
            UILabel* lab_title = (UILabel*)[cell.contentView viewWithTag:TAG_LAB_DOWNING_CHAPTER];
            if (lab_title) {
                [lab_title setText:[NSString stringWithUTF8String:m_vecChapterDowning[indexPath.row - 1]->m_strName.c_str()]];
            }
            
            UILabel* lab_progress_downing = (UILabel*)[cell.contentView viewWithTag:TAG_LAB_PROGRESS_DOWNING_CHAPTER];
            if (lab_progress_downing) {
                int n_progress = (0 == m_vecChapterDowning[indexPath.row - 1]->m_unFileSize) ? 0 : ((int)(m_vecChapterDowning[indexPath.row - 1]->m_unLocalSize * 100.0 / m_vecChapterDowning[indexPath.row - 1]->m_unFileSize));
                [lab_progress_downing setText:[NSString stringWithFormat:@"%d%%  %.2fMB/%.2fMB", n_progress, m_vecChapterDowning[indexPath.row - 1]->m_unLocalSize * 1.0 / (1024 * 1024), m_vecChapterDowning[indexPath.row - 1]->m_unFileSize * 1.0 / (1024 * 1024)]];
            }
            
            UIProgressView* progress_downing = (UIProgressView*)[cell.contentView viewWithTag:TAG_PROGRESS_DOWNING_CHAPTER];
            if (progress_downing) {
                if (m_vecChapterDowning[indexPath.row - 1]->m_unFileSize) {
                    [progress_downing setProgress:(m_vecChapterDowning[indexPath.row - 1]->m_unLocalSize * 1.0 / m_vecChapterDowning[indexPath.row - 1]->m_unFileSize)];
                }else {
                    [progress_downing setProgress:0];
                }
                
            }
        }
    }
    
    [cell setBackgroundColor:UIColorFromRGBValue(0xf0ebe3)];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if (TAG_TABLE_DOWNED_CHAPTER_LIST != tableView.tag) {
        if (0 == indexPath.row) {
            return;
        }
        UITableViewCell* cell = nil;
        cell = [_unfinish_chapter_list cellForRowAtIndexPath:indexPath];
        if (cell) {
            NSIndexPath* indexPath = [_unfinish_chapter_list indexPathForCell:cell];
            CChapterInfo* chapter_info = m_vecChapterDowning[indexPath.row - 1];
            if (chapter_info) {
                if (TaskStatus_Downing == ((CLocalTask*)chapter_info)->taskStatus || TaskStatus_Waiting == ((CLocalTask*)chapter_info)->taskStatus) {
                    CLocalBookRequest::GetInstance()->PauseDownTask(chapter_info);
                }else {
                    bool b_flow_protect = false;
                    KwConfig::GetConfigureInstance()->GetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, b_flow_protect);
                    if (b_flow_protect && NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus()){
                        UIAlertView* alert_view = [[UIAlertView alloc] initWithTitle:nil message:@"现在下载会自动关闭流量保护模式，下载会消耗流量" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"现在下载", nil];
                        [alert_view setTag:TAG_ALERT_SINGLE_START];
                        m_curIndexPath = indexPath;
                        [alert_view show];
                    }else {
                        CLocalBookRequest::GetInstance()->StartDownTask(chapter_info);
                    }
                    
                }
            }
        }
    }else {
        m_nRowClicked = indexPath.row;
        if (CPlayBookList::getInstance()->getCurChapter() && CPlayBookList::getInstance()->getCurChapter()->m_strBookId == [_strBookid UTF8String]) {
            s_cur_chapter_list_lock.Lock();
            int n_total = m_vecChapterList.size();
            CChapterInfo* chapter_info = m_vecChapterDowned[indexPath.row];
            int n_cur_index = -1;
            for (int n_itr = 0; n_itr < n_total; ++n_itr) {
                if (chapter_info->m_unRid == m_vecChapterList[n_itr]->m_unRid) {
                    n_cur_index = n_itr;
                    break;
                }
            }
            s_cur_chapter_list_lock.UnLock();
            if (n_cur_index == CPlayBookList::getInstance()->getCurPlayIndex()) {
                if (E_AUDIO_PLAY_PLAYING == CAudioPlayerManager::getInstance()->getCurPlayState() || E_AUDIO_PLAY_BUFFERING == CAudioPlayerManager::getInstance()->getCurPlayState()) {
                }else if(E_AUDIO_PLAY_PAUSE == CAudioPlayerManager::getInstance()->getCurPlayState()){
                    if (!m_bSendUmengLog) {
                        UMengLog(KB_PLAY_SOURCE, "download");
                        m_bSendUmengLog = true;
                    }
                    CAudioPlayerManager::getInstance()->resume();
                }else {
                    if (!m_bSendUmengLog) {
                        UMengLog(KB_PLAY_SOURCE, "download");
                        m_bSendUmengLog = true;
                    }
                    CAudioPlayerManager::getInstance()->play();
                }
                
                [_finish_chapter_list reloadData];
                return;
            }
            
            if (-1 != n_cur_index) {
                if (!m_bSendUmengLog) {
                    UMengLog(KB_PLAY_SOURCE, "download");
                    m_bSendUmengLog = true;
                }
                CAudioPlayerManager::getInstance()->pause();
                CPlayBookList::getInstance()->setCurPlayIndex(n_cur_index);
                CPlayBookList::getInstance()->setCurPos(0);
                CAudioPlayerManager::getInstance()->play();
            }
        }else {
            if (!m_bSendUmengLog) {
                UMengLog(KB_PLAY_SOURCE, "download");
                m_bSendUmengLog = true;
            }
            
            CAudioPlayerManager::getInstance()->pause();
            
            CPlayBookList::getInstance()->resetPlayList();
            s_cur_chapter_list_lock.Lock();
            CPlayBookList::getInstance()->addChapters(m_vecChapterList);
            int n_total = m_vecChapterList.size();
            CChapterInfo* chapter_info = m_vecChapterDowned[indexPath.row];
            int n_cur_index = -1;
            for (int n_itr = 0; n_itr < n_total; ++n_itr) {
                if (chapter_info->m_unRid == m_vecChapterList[n_itr]->m_unRid) {
                    n_cur_index = n_itr;
                    break;
                }
            }
            s_cur_chapter_list_lock.UnLock();
            CPlayBookList::getInstance()->setCurPlayIndex(n_cur_index);
            CPlayBookList::getInstance()->setCurPos(0);
            
            SYN_NOTIFY(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState::AudioPlayStatusChanged, E_AUDIO_BOOK_CHANGE);
            CAudioPlayerManager::getInstance()->play();
        }
    
        [_finish_chapter_list reloadData];
    }
}

- (BOOL)getChapterList{
    
    std::string str_request_para("");
    
    CBookInfo* book_info = CBookInfoList::getInstance()->getBookInfo([_strBookid UTF8String]);
    switch (book_info->m_unType) {
        case 1:
        {
            str_request_para += "srcver=storynew&type=music_list&key=album&start=0&count=10000&id=";
            str_request_para += book_info->m_strBookId;
            break;
        }
        case 2:
        {
            str_request_para += "srcver=storynew&type=sub_list&digest=8&start=0&count=10000&id=";
            str_request_para += book_info->m_strBookId;
            break;
        }
        default:
            break;
    }
    
    if (0 == str_request_para.size()) {
        return NO;
    }
    
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
                KwTools::CAutoLock auto_lock(&s_cur_chapter_list_lock);
                for (GDataXMLElement* chapter in arry_chapters) {
                    CChapterInfo* cur_chapter_info = new CChapterInfo;
                    cur_chapter_info->m_strName = [[[chapter attributeForName:@"name"] stringValue] UTF8String];
                    cur_chapter_info->m_strArtist = book_info->m_strArtist;
                    cur_chapter_info->m_strBookId = book_info->m_strBookId;
                    cur_chapter_info->m_strBookName = book_info->m_strBookTitle;
                    cur_chapter_info->m_unRid = [[[chapter attributeForName:@"rid"] stringValue] integerValue];
                    cur_chapter_info->m_unHotIndex = [[[chapter attributeForName:@"hot"] stringValue] integerValue];
                    cur_chapter_info->m_unDuration = [[[chapter attributeForName:@"duration"] stringValue] integerValue] * 1000;
                    
                    CChapterInfo* chapter_stored = CBookManagement::GetInstance()->GetChapterInfo(cur_chapter_info->m_strBookId, cur_chapter_info->m_unRid);
                    if (NULL != chapter_stored) {
                        cur_chapter_info->m_unDownload = chapter_stored->m_unDownload;
                    }
                    
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

-(void)IObDownStatus_TaskProgress:(unsigned)un_rid:(float)fPercent:(float)fLocalSize:(float)fFileSize{
    NSString* str_index = [_dic_downing_key_value objectForKey:[NSString stringWithFormat:@"%d", un_rid]];
    if (nil != str_index) {
        int n_index_path = [str_index intValue] + 1;
        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:n_index_path inSection:0];
        UITableViewCell* cell = [_unfinish_chapter_list cellForRowAtIndexPath:indexPath];
        if (cell) {
            UIProgressView* progress_view = (UIProgressView*)[cell.contentView viewWithTag:TAG_PROGRESS_DOWNING_CHAPTER];
            if (progress_view) {
                [progress_view setProgress:fPercent];
            }
            
            UILabel* label_progress = (UILabel*)[cell.contentView viewWithTag:TAG_LAB_PROGRESS_DOWNING_CHAPTER];
            if (label_progress) {
                [label_progress setText:[NSString stringWithFormat:@"%d%%  %.2fMB/%.2fMB", (int)(fPercent * 100), fLocalSize, fFileSize]];
            }
        }
    }
}

-(void)IObDownStatus_TaskFail:(unsigned)un_rid{
    NSString* str_index = [_dic_downing_key_value objectForKey:[NSString stringWithFormat:@"%d", un_rid]];
    if (nil != str_index) {
        int n_index_path = [str_index intValue] + 1;
        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:n_index_path inSection:0];
        [_unfinish_chapter_list reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:(UITableViewRowAnimationNone)];
    }
}

-(void)IObDownStatus_StartTask:(unsigned)un_rid{
    NSString* str_index = [_dic_downing_key_value objectForKey:[NSString stringWithFormat:@"%d", un_rid]];
    if (nil != str_index) {
        int n_index_path = [str_index intValue] + 1;
        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:n_index_path inSection:0];
        [_unfinish_chapter_list reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:(UITableViewRowAnimationNone)];
    }
}

-(void)IObDownStatus_DownTaskFinish:(unsigned)un_rid{
    CBookManagement::GetInstance()->GetBookDownList([_strBookid UTF8String], m_vecChapterDowned, m_vecChapterDowning);
    [self reloadDowningDic];
    [_finish_chapter_list reloadData];
    [_unfinish_chapter_list reloadData];
    
    if (_finish_chapter_list.hidden) {
        if (0 == m_vecChapterDowning.size()) {
            UILabel* label_prompt = (UILabel*)[_prompt_view viewWithTag:TAG_LAB_PROMPT];
            [label_prompt setText:@"没有未完成的下载任务哦"];
            [_prompt_view setHidden:NO];
        }else{
            [_prompt_view setHidden:YES];
        }
    }else {
        if (0 == m_vecChapterDowned.size()) {
            UILabel* label_prompt = (UILabel*)[_prompt_view viewWithTag:TAG_LAB_PROMPT];
            [label_prompt setText:@"还没有下载完成的任务哦"];
            [_prompt_view setHidden:NO];
        }else{
            [_prompt_view setHidden:YES];
        }
    }
}

-(void)IObDownStatus_DeleteTask{
    CBookManagement::GetInstance()->GetBookDownList([_strBookid UTF8String], m_vecChapterDowned, m_vecChapterDowning);
    [self reloadDowningDic];
    [_finish_chapter_list reloadData];
    [_unfinish_chapter_list reloadData];
    
    if (_finish_chapter_list.hidden) {
        if (0 == m_vecChapterDowning.size()) {
            UILabel* label_prompt = (UILabel*)[_prompt_view viewWithTag:TAG_LAB_PROMPT];
            [label_prompt setText:@"没有未完成的下载任务哦"];
            [_prompt_view setHidden:NO];
        }else{
            [_prompt_view setHidden:YES];
        }
    }else {
        if (0 == m_vecChapterDowned.size()) {
            UILabel* label_prompt = (UILabel*)[_prompt_view viewWithTag:TAG_LAB_PROMPT];
            [label_prompt setText:@"还没有下载完成的任务哦"];
            [_prompt_view setHidden:NO];
        }else{
            [_prompt_view setHidden:YES];
        }
    }
}

-(void)IObDownStatus_DeleteTasks{
    CBookManagement::GetInstance()->GetBookDownList([_strBookid UTF8String], m_vecChapterDowned, m_vecChapterDowning);
    [self reloadDowningDic];

    [_finish_chapter_list reloadData];
    [_unfinish_chapter_list reloadData];
    
    if (_finish_chapter_list.hidden) {
        if (0 == m_vecChapterDowning.size()) {
            UILabel* label_prompt = (UILabel*)[_prompt_view viewWithTag:TAG_LAB_PROMPT];
            [label_prompt setText:@"没有未完成的下载任务哦"];
            [_prompt_view setHidden:NO];
        }else{
            [_prompt_view setHidden:YES];
        }
    }else {
        if (0 == m_vecChapterDowned.size()) {
            UILabel* label_prompt = (UILabel*)[_prompt_view viewWithTag:TAG_LAB_PROMPT];
            [label_prompt setText:@"还没有下载完成的任务哦"];
            [_prompt_view setHidden:NO];
        }else{
            [_prompt_view setHidden:YES];
        }
    }
}

-(void)IObDownStatus_PauseTask:(unsigned)un_rid{
    NSString* str_index = [_dic_downing_key_value objectForKey:[NSString stringWithFormat:@"%d", un_rid]];
    if (nil != str_index) {
        int n_index_path = [str_index intValue] + 1;
        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:n_index_path inSection:0];
        [_unfinish_chapter_list reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:(UITableViewRowAnimationNone)];
    }
}

-(void)IObDownStatus_PauseAllTasks{
    CBookManagement::GetInstance()->GetBookDownList([_strBookid UTF8String], m_vecChapterDowned, m_vecChapterDowning);
    [_unfinish_chapter_list reloadData];
}

-(void)IObDownStatus_StartAllTask{
    CBookManagement::GetInstance()->GetBookDownList([_strBookid UTF8String], m_vecChapterDowned, m_vecChapterDowning);
    [_unfinish_chapter_list reloadData];
}

-(void)IObDownStatus_AddTask:(unsigned)un_rid{
    CBookManagement::GetInstance()->GetBookDownList([_strBookid UTF8String], m_vecChapterDowned, m_vecChapterDowning);
    [self reloadDowningDic];
    [_finish_chapter_list reloadData];
    [_unfinish_chapter_list reloadData];
    if (_finish_chapter_list.hidden) {
        if (0 == m_vecChapterDowning.size()) {
            UILabel* label_prompt = (UILabel*)[_prompt_view viewWithTag:TAG_LAB_PROMPT];
            [label_prompt setText:@"没有未完成的下载任务哦"];
            [_prompt_view setHidden:NO];
        }else{
            [_prompt_view setHidden:YES];
        }
    }else {
        if (0 == m_vecChapterDowned.size()) {
            UILabel* label_prompt = (UILabel*)[_prompt_view viewWithTag:TAG_LAB_PROMPT];
            [label_prompt setText:@"还没有下载完成的任务哦"];
            [_prompt_view setHidden:NO];
        }else{
            [_prompt_view setHidden:YES];
        }
    }
}
-(void)scrollViewDidScroll:(UIScrollView *)sender
{
    if (_isDraging) {
        CGFloat thisOffset = sender.contentOffset.y;
        
        if (thisOffset > _lastOffset) {
            [ROOT_NAVI_CONTROLLER hideCenterButton];
        }
        else{
            [ROOT_NAVI_CONTROLLER showCenterButton];
        }
        
        _lastOffset = thisOffset;
    }
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    _isDraging = YES;
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    _isDraging = NO;
}

-(void)IObserverAudioPlayStateChanged:(AudioPlayState)enumStatus{
    [ROOT_NAVI_CONTROLLER setStatus:(AudioPlayControlState)enumStatus];
    if (CPlayBookList::getInstance()->getCurChapter() && CPlayBookList::getInstance()->getCurChapter()->m_strBookId == [_strBookid UTF8String]) {
        int n_total = m_vecChapterDowned.size();
        int n_cur_chapter = -1;
        for (int n_itr = 0; n_itr < n_total; ++n_itr) {
            if (CPlayBookList::getInstance()->getCurChapter()->m_unRid == m_vecChapterDowned[n_itr]->m_unRid) {
                n_cur_chapter = n_itr;
                break;
            }
        }
        if (-1 != n_cur_chapter) {
            NSIndexPath* indexPath = [NSIndexPath indexPathForRow:n_cur_chapter inSection:0];
            [_finish_chapter_list scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
            [_finish_chapter_list reloadData];
        }
    }
}

-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
    switch (alertView.tag) {
        case TAG_DOWNED_ALERT:
        {
            if (1 == buttonIndex) {
                CLocalBookRequest::GetInstance()->DeleteTasks([_strBookid UTF8String], true);
            }
            break;
        }
        case TAG_DOWNING_ALERT:
        {
            if (1 == buttonIndex) {
                CLocalBookRequest::GetInstance()->DeleteTasks([_strBookid UTF8String], false);
            }
            
            break;
        }
        case TAG_ALERT_ALL_START:
        {
            if (1 == buttonIndex) {
                CLocalBookRequest::GetInstance()->StartAllTask([_strBookid UTF8String]);
                KwConfig::GetConfigureInstance()->SetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, false);
                SYN_NOTIFY(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect::FlowProtectStatusChange, false);
            }
            break;
        }
        case TAG_ALERT_SINGLE_START:
        {
            if (1 == buttonIndex) {
                CChapterInfo* chapter_info = m_vecChapterDowning[m_curIndexPath.row - 1];
                CLocalBookRequest::GetInstance()->StartDownTask(chapter_info);
                m_curIndexPath = nil;
                KwConfig::GetConfigureInstance()->SetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, false);
                SYN_NOTIFY(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect::FlowProtectStatusChange, false);
            }else {
                m_curIndexPath = nil;
            }
            break;
        }
        default:
            break;
    }
}

@end
