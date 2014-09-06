//
//  KFinishViewController.m
//  KwSing
//
//  Created by Qian Hu on 12-8-16.
//  Copyright (c) 2012年 酷我音乐. All rights reserved.
//

#import "KFinishViewController.h"
#include "ImageMgr.h"
#include "globalm.h"
#include "picturePickerView.h"
#include "SongInfo.h"
#include "LocalMusicRequest.h"
#include "AuditionPlay.h"
#include "MessageManager.h"
#include "IAudioStateObserver.h"
#include "MediaModelFactory.h"
#include "KSongViewController.h"
#include "KSAppDelegate.h"
#include "ShareViewController.h"
#include "User.h"
#include "KSOtherLoginViewController.h"
#include "KSProgressView.h"
#include "IMediaSaveProcessObserver.h"
#include "MessageManager.h"
#include "MyOpusData.h"
#include "KwConfig.h"
#include "KSAudioLength.h"
#include "IMyOpusObserver.h"
#include "LoginViewController.h"
#include "KwTools.h"
#include "iToast.h"
#include "User.h"
#include "IEmigratedObserver.h"
#include "MobClick.h"
#include "KuwoLog.h"
#include "KwConfigElements.h"
#include "KwUMengElement.h"
#include "UMengLog.h"
#include "RecordTask.h"
#include "ImageProcessingViewController.h"
#include "playPicturesView.h"
#include "MediaReplay.h"
#include "KSongLyricView.h"
#include "PlayMusicLyricView.h"
#include "RecordTask.h"
#include "KuwoConstants.h"
#include "SBJson.h"

#import "KSSpringJoinView.h"

#define BK_TOPVIEW                  "topKSongbk.png"
#define REFRESH_CONTORL_INTERVAL    1 
#define MAX_NAME_LENGTH             9
#define MIN_UPLOAD_LENGTH           6000

#define CONF_KSONG_SECTION          "KSong"
#define KEY_SIMPLESONG_NAME         "simplename"

//#define TAG_WEIBO_BTN                100
//#define TAG_QQ_BTN                   101
//#define URL_SHARE    @"http://changba.kuwo.cn/kge/mobile/pubWeiBo"

static string s_str_match_opus_kid = "";

#define SPRING_MATCH_JOIN_URL  "http://music.sprite.com.cn/sprite/kgeuser?act=userinfo&uid="
#define SPRING_MATCH_REGISTER_URL @"http://music.sprite.com.cn/sprite/kgeuser?act=register&name=%@&uid=%@&phone=%@&id=%@"

#define HEIHGT_LYRICVIEW            80

#define TAG_SPRING_ALERT   200

enum OperateType
{
    Action_ReSing= 1,
    //Action_RePlay,
    Action_Save,
    Action_Upload,
    
    // 闯关
    Action_Emigrated_Return,
    Action_Emigrated_ReSing,
    Action_Emigrated_Normal
};

@interface KFinishViewController ()<UIAlertViewDelegate,imageSelectedDelegate,
                                    IMediaSaveProcessObserver,UITextViewDelegate,
                                    IMyOpusObserver,IUserStatusObserver,ImageProcessing>
{
    playPicturesView * playPicView;
    UIView           * vedioView;
    
    picturePickerView * pickerView;
    UIView * FloatView;
    bool bShowBkView;
    UIButton* btnImgChoose;
    //UIButton* btnRecordEffect;
    UIButton* btnplay;
    UISlider *slider;
    
    UIView * simplesongNameView;
    UITextView * nameTextView;

    UIButton* btnSave;
    UIButton* btnUpload;
    
    UILabel * labelDefeat;
    
    std::vector<UIButton*> arrRecordBtn;
    KSProgressView * progressView;
    UILabel* progressLabel;
    UIView * popView;
    NSTimer *timer;
    UIImageView * topbkView;
    UIAlertView * loginAlertView;
    UIAlertView * closeAlertView;
    
    UIView * mainView;
    //UIView * emigratedView;
    
    CMediaReplay * m_mediaReplay;
    std::string strRecordId;
    bool bVideo;
    
    LOGIN_TYPE  m_nloginType;
    int m_nSimpleName;
    CRecoSongInfo * m_pRecoSongInfo;
    CMediaSaveInterface * m_mediaSave;
    
    bool m_bUpLoad;
    
    //bool m_bEmigrated;    // 是否从闯关那来的
    KSWebView *m_EmigratedWebView;
    
    CLyricInfo * m_pLyricInfo;
    //KSongLyricView *lyricView;
    PlayMusicLyricView *lyricView;
    
    UIImageView * topResultbkView;
    
    UILabel *timeLabel;
    
    bool isPlaying;
}

@end

@implementation KFinishViewController

//-(void)SetEmigrated: (bool)bEmigrated : (KSWebView*)emiWebView
//{
//    m_bEmigrated = bEmigrated;
//    m_EmigratedWebView = emiWebView;
//}

-(void)SetRecordId:(std::string&) rid Vedio: (bool)bvedio Point:(unsigned)point
{
    strRecordId = rid;
    bVideo = bvedio;
    m_pRecoSongInfo->uiPoints = point;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        playPicView =  nil;
        vedioView = nil;
        
        bShowBkView = false;
        m_mediaReplay = NULL;
        bVideo = false;
        timer = nil;
        
        pickerView = nil;
        progressView = nil;
        popView = nil;
        m_pRecoSongInfo = new CRecoSongInfo;
        m_mediaSave = NULL;
        simplesongNameView = nil;
        nameTextView = nil;
        m_bUpLoad = false;
        labelDefeat = nil;
        //m_bEmigrated = false;
        
        lyricView=nil;
        isPlaying=false;
    }
    return self;
}
-(void)viewDidAppear:(BOOL)animated
{
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending) {
        [ROOT_NAVAGATION_CONTROLLER.view setFrame:CGRectMake(0, 20, 320, [UIScreen mainScreen].bounds.size.height-20)];
        [self.view setFrame:CGRectMake(0, 0, 320, [UIScreen mainScreen].bounds.size.height-20)];
    }
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    CSongInfoBase * songinfo = NULL;
    s_str_match_opus_kid = "";
    if(strRecordId != "")
    {
        songinfo = CLocalMusicRequest::GetInstance()->GetLocalMusic(strRecordId);
        if(songinfo)
            *((CSongInfoBase*)m_pRecoSongInfo) = (*songinfo);
    }
    else {
        m_pRecoSongInfo->strRid = "";
        m_nSimpleName = 1;
        KwConfig:: GetConfigureInstance()->GetConfigIntValue(CONF_KSONG_SECTION, KEY_SIMPLESONG_NAME, m_nSimpleName);
    }

    
    GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_MEDIA_SAVE_PROGRESS,IMediaSaveProcessObserver);
    GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_MYOPUS, IMyOpusObserver);
    GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_USERSTATUS, IUserStatusObserver);
    
    topbkView = [[[UIImageView alloc]init]autorelease];
    CGRect rcbk = [[self view]bounds];
    rcbk.size.height = 320;
    [topbkView setFrame:rcbk];
    [topbkView setImage:CImageMgr::GetImageEx(BK_TOPVIEW)];
    [[self view] addSubview:topbkView];
    
    mainView = [[[UIView alloc]initWithFrame:self.view.bounds]autorelease];
    [[self view]addSubview:mainView];
    
    if (bVideo) {
        vedioView = [[[UIView alloc] initWithFrame:rcbk] autorelease];
        [mainView addSubview:vedioView];
        [vedioView setHidden:true];
    }
    else{
        if (CRecordTask::GetInstance()->m_bIsHrbActivity) {
            UIImageView *hrbBkImage = [[[UIImageView alloc] initWithFrame:rcbk] autorelease];
            [hrbBkImage setImage:CImageMgr::GetImageEx("HrbBkImage.jpg")];
            [mainView addSubview:hrbBkImage];
            
            if (User::GetUserInstance()->isOnline() && User::GetUserInstance()->getPartInType() != PARTIN) {
                [self getPartInInfo];
            }
        }
        else{
            playPicView = [[[playPicturesView alloc] initWithFrame:rcbk]autorelease];
            [mainView addSubview:playPicView];
            [playPicView setHidden:true];
            [self InitPicShow];
        }
    }
    
    if(songinfo)
    {
        CGRect rclyric = BottomRect(rcbk, HEIHGT_LYRICVIEW , 0);
        rclyric.size.height-=35;
        lyricView = [[[PlayMusicLyricView alloc]initWithFrame:rclyric]autorelease];
        [lyricView setHidden:true];
        [mainView addSubview:lyricView];
        std::string strpath = [self GetLyricPath:songinfo->strRid];
        if(m_pLyricInfo == NULL)
            m_pLyricInfo = new CLyricInfo;
        m_pLyricInfo->ReadFromFile(strpath);
        [lyricView SetLyricInfo:m_pLyricInfo];
    }
    
    if((strRecordId != "") && (NULL != m_pLyricInfo) && (LYRIC_KDTX == m_pLyricInfo->GetLyricType()))
    {
        topResultbkView = [[[UIImageView alloc]init]autorelease];
        CGRect rcresult = CGRectMake(61.5, 29, 197, 63.5);
        
        [topResultbkView setFrame:rcresult];
        [topResultbkView setImage:CImageMgr::GetImageEx("resultBK.png")];
        [mainView addSubview:topResultbkView];
        
        UILabel* lableresult1 = [[[UILabel alloc]initWithFrame:[topResultbkView convertRect:CGRectMake(61.5, 35, 197,20) fromView:mainView] ] autorelease];
        lableresult1.textAlignment = UITextAlignmentCenter;
        lableresult1.backgroundColor = [UIColor clearColor];
        lableresult1.textColor = [UIColor whiteColor];
        lableresult1.font = [UIFont systemFontOfSize:18];
        lableresult1.lineBreakMode = UILineBreakModeWordWrap;
        [topResultbkView addSubview:lableresult1];
        lableresult1.text = [NSString stringWithFormat:@"演唱得分：%d分",m_pRecoSongInfo->uiPoints];
        
        labelDefeat = [[[UILabel alloc]initWithFrame:[topResultbkView convertRect:CGRectMake(61.5, 65, 197,20) fromView:mainView]] autorelease];
        labelDefeat.textAlignment = UITextAlignmentCenter;
        labelDefeat.backgroundColor = [UIColor clearColor];
        labelDefeat.textColor = [UIColor whiteColor];
        labelDefeat.font = [UIFont systemFontOfSize:18];
        labelDefeat.lineBreakMode = UILineBreakModeWordWrap;
        [topResultbkView addSubview:labelDefeat];
        labelDefeat.text = @"...";
        [self ShowDefeatData];
    }
    
    timeLabel=[[[UILabel alloc] initWithFrame:CGRectMake(240, 325, 100, 20)] autorelease];
    [timeLabel setBackgroundColor:[UIColor clearColor]];
    [timeLabel setTextColor:[UIColor whiteColor]];
    [timeLabel setFont:[UIFont systemFontOfSize:14.0]];
    [timeLabel setTextAlignment:NSTextAlignmentLeft];
    [timeLabel setShadowColor:[UIColor grayColor]];
    [timeLabel setShadowOffset:CGSizeMake(1, 1)];
    [self.view addSubview:timeLabel];

    /*
    UILabel* lable = [[[UILabel alloc]initWithFrame:CGRectMake(10, 13, self.view.bounds.size.width-54,17)] autorelease];
    lable.textAlignment = UITextAlignmentLeft;
    lable.backgroundColor = [UIColor clearColor];
    lable.textColor = [UIColor whiteColor];
    lable.font = [UIFont systemFontOfSize:18];
    [lable setShadowOffset:CGSizeMake(1, 1)];
    [lable setShadowColor:[UIColor grayColor]];
    lable.lineBreakMode = UILineBreakModeWordWrap;
    if(songinfo)
    {
        std::string strinfo = songinfo->strSongName + "-" + songinfo->strArtist.c_str();
        lable.text = [NSString stringWithUTF8String:strinfo.c_str()];
    }
    else {
        lable.text = @"自由清唱";
    }
    [[self view] addSubview:lable];
     */
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setBackgroundImage:CImageMgr::GetImageEx("KSongCloseNormal.png") forState:UIControlStateNormal];
    [btn setBackgroundImage:CImageMgr::GetImageEx("KSongCloseDown.png") forState:UIControlStateHighlighted];
    btn.frame = CGRectMake(self.view.bounds.size.width-44, 10, 34,34);
    [btn addTarget:self action:@selector(ReturnBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [mainView addSubview:btn];

    CGRect rcFloat = BottomRect(rcbk, 34, 0);
    rcFloat.size.height = 114;
    FloatView = [[[UIView alloc]initWithFrame:rcFloat]autorelease];
    [mainView addSubview:FloatView];

    if(!bVideo && !CRecordTask::GetInstance()->m_bIsHrbActivity)
    {
        btnImgChoose = [UIButton buttonWithType:UIButtonTypeCustom];
        btnImgChoose.frame = CGRectMake(248,0, 63, 26);
        [btnImgChoose setTitle:@"背 景" forState:UIControlStateNormal];
        [btnImgChoose setBackgroundImage:CImageMgr::GetImageEx("BkEffectTabNormal_17.png") forState:UIControlStateNormal];
        [btnImgChoose setBackgroundImage:CImageMgr::GetImageEx("BkEffectTabDown_17.png") forState:UIControlStateHighlighted];
        [btnImgChoose setBackgroundImage:CImageMgr::GetImageEx("BkEffectTabDown_17.png") forState:UIControlStateDisabled];
        [btnImgChoose setSelected:true];
        btnImgChoose.titleLabel.font = [UIFont systemFontOfSize:13];
        [btnImgChoose addTarget:self action:@selector(ChooseimageClick:) forControlEvents:UIControlEventTouchUpInside];
        [FloatView addSubview:btnImgChoose];
    }
    
    UIImage * imgplay = CImageMgr::GetImageEx("replayBtn.png");
    btnplay = [UIButton buttonWithType:UIButtonTypeCustom];
    btnplay.frame = CGRectMake(120,120,80,80);
    [btnplay setTag:1];
    [btnplay setBackgroundImage: imgplay forState:UIControlStateNormal];
    [btnplay setBackgroundImage:CImageMgr::GetImageEx("replayBtnDown.png") forState:UIControlStateSelected];
    [btnplay addTarget:self action:@selector(ControlBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [btnplay setHidden:false];
    //[recordView addSubview:btnplay];
    [mainView addSubview:btnplay];
   
    slider = [[[UISlider alloc]initWithFrame:CGRectMake(0, 307, 320, 7)]autorelease];
    //[slider setMaximumTrackImage:CImageMgr::GetImageEx("playSliderMax_6.png") forState:UIControlStateNormal];
    //[slider setMinimumTrackImage:CImageMgr::GetImageEx("playSliderMin_6.png") forState:UIControlStateNormal];
    [slider setMinimumTrackImage:CImageMgr::GetImageEx("replayProTrack.png") forState:UIControlStateNormal];
    [slider setMaximumTrackImage:CImageMgr::GetImageEx("replayProback.png") forState:UIControlStateNormal];
    [slider setThumbImage:CImageMgr::GetImageEx("replayProBtn.png") forState:UIControlStateNormal];
    [slider setValue:0.0f];
    [self.view addSubview:slider];
    [slider setHidden:false];
    [slider addTarget:self action:@selector(seekMedia:) forControlEvents:UIControlEventTouchUpInside];
    
    UIView * bottombkView = [[[UIImageView alloc]init]autorelease];
    CGRect rcbkbottom = BottomRect([[self view]bounds],self.view.bounds.size.height-320,0);
    [bottombkView setFrame:rcbkbottom];
    bottombkView.backgroundColor = UIColorFromRGBValue(0xededed);
    [mainView addSubview:bottombkView];
    
    UIImage * shadowimage = CImageMgr::GetImageEx("nowplayshadow.png");
    UIImageView * shadowView = [[[UIImageView alloc]init]autorelease];
    [shadowView setFrame:CGRectMake(0, rcbkbottom.origin.y, 320, shadowimage.size.height)];
    [shadowView setImage:shadowimage];
    [mainView addSubview:shadowView];
     
    std::string strIcon[4] = {
        "finishresing.png"
        ,"finishsave.png"
        ,"finishupload.png"
        };
    UIImage * imageDown = CImageMgr::GetImageEx("NowPlayBtnDown.png");
    NSString * str1[3] = {@"重唱",@"保存",@"上传"};
    int x[3]={0};
    int y[3]={0};
    int ly[3]={0};
    if (!IsIphone5()) {
        x[0]=17.5;x[1]=132.5;x[2]=245.5;
        y[0]=y[1]=y[2]=350;
        ly[0]=ly[1]=ly[2]=414;
    }
    else{
        x[0]=13;x[1]=132.5;x[2]=248.5;
        y[0]=413;y[1]=368;y[2]=413;
        ly[0]=477;ly[1]=432;ly[2]=477;
    }

    for (int i = 0; i < 3; i++) {
        UIButton* btnoprate = [UIButton buttonWithType:UIButtonTypeCustom];
        btnoprate.frame = CGRectMake(x[i] ,y[i], 58, 58);
  
        [btnoprate setTag:i+1];
        btnoprate.titleLabel.font = [UIFont systemFontOfSize:15];
        [btnoprate setBackgroundImage:imageDown forState:UIControlStateHighlighted];
        [btnoprate setImage:CImageMgr::GetImageEx(strIcon[i].c_str()) forState:UIControlStateNormal]; 
        [btnoprate setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
        [btnoprate addTarget:self action:@selector(OperateBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [mainView addSubview:btnoprate];
        
        UILabel * label = [[[UILabel alloc]initWithFrame:CGRectMake(x[i], ly[i], 58, 13)]autorelease];
        label.textColor = UIColorFromRGBValue(0x2b2b2b);
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = UITextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:12.5];
        [label setShadowColor:UIColorFromRGBValue(0xffffff)];
        [label setShadowOffset:CGSizeMake(0, 1)];
        label.text = str1[i];
        [mainView addSubview:label];
        
        if(i == 1)
            btnSave = btnoprate;
        else if (i == 2)
            btnUpload = btnoprate;
    }
        
    //[self InitShareView];
    
//    if(m_bEmigrated)
//    {
//        [self InitEmigratedView];
//        mainView.hidden = true;
//        emigratedView.hidden = false;
//    }
    [MobClick beginLogPageView:[NSString stringWithUTF8String:object_getClassName(self)]];
   }

//string resStr;
//BOOL res=CHttpRequest::QuickSyncGet([cancelUrlStr UTF8String], resStr);
//if (!res) {
//    return false;
//}
//SBJsonParser *parser=[[SBJsonParser alloc] init];
//NSDictionary *retDic=[parser objectWithString:[NSString stringWithUTF8String:resStr.c_str()]];
//[parser release];
//NSString *result=[retDic objectForKey:@"result"];
//if ([result isEqualToString:@"err"]) {
//    //NSLog(@"cancel fail,error:%@",[retDic objectForKey:@"errMsg"]);
//    return false;
//}

/*
 获取用户是否参与了活动，决定了分享的语句
 return:json  {"result":"ok","ispartin":"1/0"}
 result表示请求状态，1为参加，0为未参加
 */
#define URL_GET_PARTIN @"http://changba.kuwo.cn/kge/mobile/ActivityServer?"
//#define URL_GET_PARTIN @"http://60.28.205.41/kge/mobile/ActivityServer?"

-(void)getPartInInfo
{
    KS_BLOCK_DECLARE
    {
        NSString *url=[NSString stringWithFormat:@"%@act=ispartin&uid=%@&sid=%@&src=%s",
                                            URL_GET_PARTIN,
                                            User::GetUserInstance()->getUserId(),
                                            User::GetUserInstance()->getSid(),
                                            KWSING_CLIENT_VERSION_STRING];
        string resStr;
        BOOL res = CHttpRequest::QuickSyncGet([url UTF8String], resStr);
        NSLog(@"get partin info url :%@",url);
        if (!res){
            NSLog(@"get part in info fail");
            return;
        }
        SBJsonParser *parser = [[SBJsonParser alloc] init];
        NSDictionary *retDic = [parser objectWithString:[NSString stringWithUTF8String:resStr.c_str()]];
        [parser release];
        NSString *result = [retDic objectForKey:@"result"];
        NSString *isPartin = [retDic objectForKey:@"ispartin"];
        NSLog(@"get part info return res:%@,partin:%@",result,isPartin);
        
        if ([result isEqualToString:@"ok"]) {
            if ([isPartin isEqualToString:@"1"]) {
                User::GetUserInstance()->setPartInType(PARTIN);
            }
            if ([isPartin isEqualToString:@"0"]) {
                User::GetUserInstance()->setPartInType(NO_PARTIN);
            }
        }
    }KS_BLOCK_RUN_THREAD()
}

#define URL_USER_DEFEAT              "http://changba.kuwo.cn/kge/mobile/UserPercent"
-(void)ShowDefeatData
{
    if(CHttpRequest::GetNetWorkStatus() == NETSTATUS_NONE)
    {
        labelDefeat.text = @"音乐路上需要你不断地努力";
        return;
    }
    //ONLINE_TYPE type = User::GetUserInstance()->getOnlineType();
    NSString *struid = nil;
    NSString *strsid = nil;
    if(User::GetUserInstance()->isOnline())
    {
        struid = User::GetUserInstance()->getUserId();
        strsid = User::GetUserInstance()->getSid();
    }
    unsigned score = 0;
    if(m_pRecoSongInfo)
        score = m_pRecoSongInfo->uiPoints;
    if(score == 0)
    {
        if(m_pRecoSongInfo)
            m_pRecoSongInfo->uiDefeat = 0;
        labelDefeat.text = @"击败了全国0%的K友";
        return;
    }
    std::string strUrl;
    if(!User::GetUserInstance()->isOnline())
        strUrl = KwTools::StringUtility::Format("%s?rid=%s&score=%d",URL_USER_DEFEAT,m_pRecoSongInfo->strRid.c_str(),score);
    else
        strUrl = KwTools::StringUtility::Format("%s?rid=%s&score=%d&uid=%@&sid=%@",URL_USER_DEFEAT,m_pRecoSongInfo->strRid.c_str(),score,struid,strsid);
    KS_BLOCK_DECLARE
    {
        std::string strOut;
        if(CHttpRequest::QuickSyncGet(strUrl, strOut)) {
            strOut = strOut.substr(1,strOut.length()-2);
            std::map<std::string,std::string> mapTokens;
            KwTools::StringUtility::TokenizeKeyValue(strOut,mapTokens,",",":");
            if(mapTokens["\"result\""] == "\"ok\"") {
                std::string strlower = mapTokens["\"lower\""];
                std::string strtotal = mapTokens["\"total\""];
                int nlower = atoi(strlower.c_str());
                int ntotal = atoi(strtotal.c_str());
                KS_BLOCK_DECLARE
                {
                    if (m_pRecoSongInfo) {
                        if(ntotal)
                            m_pRecoSongInfo->uiDefeat = nlower * 100 / ntotal;
                        else
                            m_pRecoSongInfo->uiDefeat = 100;
                        labelDefeat.text = [NSString stringWithFormat:@"击败了全国%d%%的K友",m_pRecoSongInfo->uiDefeat];
                    }
                }
                KS_BLOCK_SYNRUN();
    
            }
        }

    }
    KS_BLOCK_RUN_THREAD();
}

-(void)ShowSimpleSongNameView
{
    if(simplesongNameView == nil)
    {
        simplesongNameView = [[[UIView alloc]initWithFrame:self.view.bounds]autorelease];
        simplesongNameView.backgroundColor = UIColorFromRGBAValue(0x000000,51);
        [[self view] addSubview:simplesongNameView];
        
        CGRect rcbk = CGRectMake(42, 100, 230, 155);
        UIImageView * bkimageView = [[[UIImageView alloc]init]autorelease];
        [bkimageView setFrame:rcbk];
        [bkimageView setImage:CImageMgr::GetImageEx("orginKsongbk_20_19.png")];
        [simplesongNameView addSubview:bkimageView];
        
        UIView * mainview = [[[UIView alloc]initWithFrame:rcbk]autorelease];
        [simplesongNameView addSubview:mainview];
        
        UILabel* lable = [[[UILabel alloc]initWithFrame:CGRectMake(17, 15, 200,14)]autorelease];
        lable.backgroundColor = [UIColor clearColor];
        lable.text = @"为你的作品起个名字吧";
        lable.font = [UIFont systemFontOfSize:14];
        lable.textColor = [UIColor blackColor];
        [mainview addSubview:lable];
        
        nameTextView = [[[UITextView alloc]initWithFrame:CGRectMake(17, 50, 190, 40)]autorelease];
        nameTextView.Font = [UIFont systemFontOfSize:15];
        [nameTextView.layer setBorderColor:[[UIColor grayColor] CGColor]];
        [nameTextView.layer setBorderWidth:1];
        nameTextView.delegate = self;
        nameTextView.text = [NSString stringWithFormat:@"清唱%d",m_nSimpleName];
        [mainview addSubview:nameTextView];
        
        UIButton* btn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [btn setTitle:@"确定" forState: UIControlStateNormal];
        [btn setTag:1];
        btn.frame = CGRectMake(20, 110, 70,30);
        [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:17];
        [btn addTarget:self action:@selector(SimpleNameClick:) forControlEvents:UIControlEventTouchUpInside];
        [mainview addSubview:btn];
        
        UIButton* btn1 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [btn1 setTitle:@"取消" forState: UIControlStateNormal];
        [btn1 setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        btn1.frame = CGRectMake(140, 110, 70,30);
        [btn1 setTag:2];
        btn1.titleLabel.font = [UIFont systemFontOfSize:17];
        [btn1 addTarget:self action:@selector(SimpleNameClick:) forControlEvents:UIControlEventTouchUpInside];
        [mainview addSubview:btn1];

    }
    simplesongNameView.hidden = false;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

//- (void)viewWillDisappear:(BOOL)animated{
//    
//}

- (void)stopPlay{
    
    [timer invalidate];
    timer=NULL;
    
    [lyricView StopRefresh];
    lyricView=NULL;
    
    if (m_pLyricInfo) {
        delete m_pLyricInfo;
        m_pLyricInfo = NULL;
    }
    
    if (m_mediaReplay) {
        m_mediaReplay->Stop();
    }
    
    GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_AUDIOSTATUS,IAudioStateObserver);
}

-(void)dealloc
{
    if (m_pLyricInfo) {
        delete m_pLyricInfo;
        m_pLyricInfo = NULL;
    }
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(void) ReturnBtnClick:(id)sender
{
    if(m_pRecoSongInfo && m_pRecoSongInfo->eumLocalState == CRecoSongInfo::STATE_NOSAVE)
    {
        closeAlertView = [[[UIAlertView alloc]initWithTitle:@"是否放弃此次录制？" message:@"" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:@"取消", nil]autorelease];
        [closeAlertView show];
    }
    else {
        [self CloseView];
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text  
{
    if (range.location>=MAX_NAME_LENGTH)
    {  
        return  NO;  
    }  
    else   
    {  
        return YES;  
    }  
}  


-(void) SimpleNameClick:(id)sender
{
    if(simplesongNameView)      //需要先做本页面的事情，再去弹出其它页面
    {
        simplesongNameView.hidden = true;
        [nameTextView resignFirstResponder];
    }
    if(((UIButton*)sender).tag == 1)
    {
        if([nameTextView.text isEqualToString:@""])
        {
            [[[iToast makeText:NSLocalizedString(@"名字不能为空", @"")]setGravity:iToastGravityCenter  ]show];
            return;
        }
        m_pRecoSongInfo->strSongName = [nameTextView.text UTF8String];
        if([nameTextView.text isEqualToString:[NSString stringWithFormat:@"清唱%d",m_nSimpleName ]])
        {
            // 清唱名字数字顺延
            m_nSimpleName++;
            KwConfig::GetConfigureInstance()->SetConfigIntValue(CONF_KSONG_SECTION, KEY_SIMPLESONG_NAME, m_nSimpleName);
        }
        if(!m_bUpLoad)
            [self StartSave];
        else
        {
            ShareViewController *shareView=[[[ShareViewController alloc] init] autorelease];
            [shareView setShareSongInfo:m_pRecoSongInfo index:0 isVideo:bVideo];
            [ROOT_NAVAGATION_CONTROLLER pushViewController:shareView animated:YES];
        }
    }
}


-(void)seekMedia:(id)sender
{
    //添加响应事件
    float f = slider.value; //读取滑块的值
    if(m_mediaReplay)
        m_mediaReplay->Seek(f*m_mediaReplay->Duration());
}

-(void)onImageSelected:(UIImage *)selectImage
{
    if (selectImage == nil) {
        [topbkView setImage:CImageMgr::GetImageEx(BK_TOPVIEW)];
    }
    else {
        topbkView.image = selectImage;
    }
    
}
-(void)onAddImage:(UIImage *)addImage
{
    ImageProcessingViewController * imageController = [[[ImageProcessingViewController alloc] initWithImage:addImage] autorelease];
    [imageController setDelegate:self];
    [ROOT_NAVAGATION_CONTROLLER pushViewController:imageController animated:YES];
}
-(void)onImageProcessingDone:(UIImage *)image
{
    [pickerView onImageProsessingDone:image];
}
/*
-(void) BtnShareClick:(id)sender
{
    int ntag = (LOGIN_TYPE)((UIButton*)sender).tag;
    if(User::GetUserInstance()->getOnlineType() == KUWO_ONLINE || User::GetUserInstance()->getOnlineType() == ONLINE_TYPE_NONE)
    {
        if(ntag == TAG_WEIBO_BTN)
            m_nloginType = SINA;
        else if(ntag == TAG_QQ_BTN)
            m_nloginType = QQ;
        KSOtherLoginViewController * otherLogin = [[[KSOtherLoginViewController alloc]initWithType:m_nloginType ]autorelease];
        otherLogin.isShare = true;
        [self.navigationController pushViewController:otherLogin animated:NO];
    }
    else if(ntag == TAG_WEIBO_BTN)
    {
        btnWeiboShare.selected = !btnWeiboShare.selected;
    }
    else if(ntag == TAG_QQ_BTN)
    {
        btnQQZoneShare.selected = !btnQQZoneShare.selected;
    }

    
//    if(User::GetUserInstance()->getOnlineType() == KUWO_ONLINE || User::GetUserInstance()->getOnlineType() == NONE)
//    {
//        loginAlertView = [[[UIAlertView alloc]initWithTitle:@"" message:@"您还未登录，是否要登录？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"登录", nil]autorelease];
//        [loginAlertView show];
//    }
//    else if(User::GetUserInstance()->getOnlineType() == ((UIButton*)sender).tag+1)
//    {
//        ShareViewController * shareView = [[[ShareViewController alloc] init]autorelease];
//        [shareView SetShareType:m_nloginType];
//        if(m_pRecoSongInfo && m_pRecoSongInfo->strRid != "")
//            shareView.shareText = [NSString stringWithFormat:@"我用#酷我K歌#iPhone版演唱了《%@》，得到%d分，击败了全国%d%%的网友哦，大家快来听听吧！",[NSString stringWithUTF8String:m_pRecoSongInfo->strSongName.c_str()] ,m_pRecoSongInfo->uiPoints,m_nDefeatPercent];
//        else 
//            shareView.shareText = @"我用#酷我K歌#iPhone版清唱了一首歌，大家快来听听吧！";
//
//        [self.navigationController pushViewController:shareView animated:NO];
//        
//    }
 }


-(void)IUserStatusObserver_LoginFinish:(LOGIN_TYPE) type :(LOGIN_TIME)first
{
    [self SetShareBtnStatus:(ONLINE_TYPE)(type+1)];
}
*/
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (TAG_SPRING_ALERT == alertView.tag) {
        switch (buttonIndex) {
            case 0:
            {
                break;
            }
            case 1:
            {
                std::string str_spring_join_url = SPRING_MATCH_JOIN_URL;
                str_spring_join_url += [User::GetUserInstance()->getUserId() UTF8String];
                
                KS_BLOCK_DECLARE{
                    std::string str_out = "";
                    bool b_ret = CHttpRequest::QuickSyncGet(str_spring_join_url, str_out);
                    int n_retry_times = 0;
                    while (!b_ret && 3 > n_retry_times++) {
                        b_ret = CHttpRequest::QuickSyncGet(str_spring_join_url, str_out);
                    }
                    
                    if (b_ret) {
                        //是否报名
                        if (std::string::npos == str_out.find(":200")) {
                            //弹出报名页面
                            KS_BLOCK_DECLARE{
                                KSSpringJoinView* spring_join_view = [[[KSSpringJoinView alloc] initWithFrame:self.view.frame] autorelease];
                                [spring_join_view setStrKid:[NSString stringWithUTF8String:s_str_match_opus_kid.c_str()]];
                                [spring_join_view setStrUserId:User::GetUserInstance()->getUserId()];
                                [self.view addSubview:spring_join_view];
                            }
                            KS_BLOCK_SYNRUN();
                        }else {
                            //发送UID和kid给服务器
                            NSString* str_register_url = [NSString stringWithFormat:SPRING_MATCH_REGISTER_URL, @"", User::GetUserInstance()->getUserId(), @"", [NSString stringWithUTF8String:s_str_match_opus_kid.c_str()]];
                            KS_BLOCK_DECLARE{
                                std::string str_out = "";
                                int n_retry_time = 0;
                                bool b_ret = CHttpRequest::QuickSyncGet([str_register_url UTF8String], str_out);
                                while (!b_ret && 3 > n_retry_time++) {
                                    b_ret = CHttpRequest::QuickSyncGet([str_register_url UTF8String], str_out);
                                }
                                
                                if (b_ret && std::string::npos != str_out.find(":200")) {
                                    KS_BLOCK_DECLARE{
                                        [[[[iToast makeText:NSLocalizedString(@"参赛成功", @"")]setGravity:iToastGravityCenter] setDuration:2000] show];
                                    }
                                    KS_BLOCK_SYNRUN();
                                }else {
                                    KS_BLOCK_DECLARE{
                                        [[[[iToast makeText:NSLocalizedString(@"参赛失败，请检查网络连接", @"")]setGravity:iToastGravityCenter] setDuration:2000] show];
                                    }
                                    KS_BLOCK_SYNRUN();
                                }
                            }
                            KS_BLOCK_RUN_THREAD();
                        }
                    }else {
                        //toast 提示 参赛失败
                        KS_BLOCK_DECLARE{
                            [[[[iToast makeText:NSLocalizedString(@"参赛失败，请检查网络连接", @"")]setGravity:iToastGravityCenter] setDuration:2000] show];
                        }
                        KS_BLOCK_SYNRUN();
                    }
                }
                KS_BLOCK_RUN_THREAD();
                break;
            }
            case 2:
            {
                KwConfig::GetConfigureInstance()->SetConfigBoolValue(SPRING_MATCH_GROUP, SPRING_MATCH_ENABLE, false);
                break;
            }
            default:
                break;
        }
    }else {
        if(alertView == loginAlertView)
        {
            if(buttonIndex == 1)
            {
                KSLoginViewController* loginView=[[[KSLoginViewController alloc] init] autorelease];
                [ROOT_NAVAGATION_CONTROLLER pushViewController:loginView animated:YES];
            }
        }
        
        if(alertView == closeAlertView)
        {
            if(buttonIndex == 0)
                [self CloseView];
        }
    }
}

-(void)ReleaseReplay
{
    if(m_mediaReplay) {
        CMediaModelFactory::GetInstance()->ReleaseMediaReplay();
        m_mediaReplay = NULL;
    }
        
    GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_AUDIOSTATUS,IAudioStateObserver);
    [timer invalidate];
    timer = nil;
}

-(void) ControlBtnClick:(id)sender
{
    if (topResultbkView.isHidden == false) {
        [topResultbkView setHidden:true];
    }
    if(((UIButton*)sender).tag == 1)
    {
        //[slider setHidden:false];
        [sender setHidden:true];
        if (playPicView){
            [playPicView setHidden:false];
            [playPicView startPlay];
        }
        if (vedioView) {
            [vedioView setHidden:false];
        }
        
        if(m_mediaReplay == NULL || (m_mediaReplay && m_mediaReplay->GetPlayStatus() == PLAY_STATUS_STOP))
        {
            if(m_mediaReplay == NULL)
            {
                timer = [NSTimer scheduledTimerWithTimeInterval:REFRESH_CONTORL_INTERVAL target:self selector:@selector(onRefreshControl) userInfo:nil repeats:YES];
                GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_AUDIOSTATUS,IAudioStateObserver);
            }
            else {
                    CMediaModelFactory::GetInstance()->ReleaseMediaReplay();
            }
            m_mediaReplay = CMediaModelFactory::GetInstance()->CreateMediaReplay(bVideo);
//            CSongInfoBase * songinfo = NULL;
//            if(strRecordId != "")
//                songinfo = CLocalMusicRequest::GetInstance()->GetLocalMusic(strRecordId);
//            if(songinfo)
//            {
//                bool bret = m_mediaReplay->InitPlayer();
//                if(!bret)
//                    return;
//            }
//            else {
//                bool bret = m_mediaReplay->InitPlayer();
//                if(!bret)
//                    return;
//            }
            bool bret = m_mediaReplay->InitPlayer(vedioView);
            if(!bret)
                return;
            m_mediaReplay->SetAudioEchoEffect(CRecordTask::GetInstance()->GetEchoType());
            m_mediaReplay->StartPlay();
            [lyricView SetMedia:m_mediaReplay];
            UMengLog(KS_TRY_LISTEN, "Record Replay");
        }
        else {
             m_mediaReplay->ContinuePlay();
        }
    }
}

-(void)CloseView
{
    [self ReleaseReplay];
    GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_MEDIA_SAVE_PROGRESS,IMediaSaveProcessObserver);
    GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_MYOPUS, IMyOpusObserver);
    GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_USERSTATUS, IUserStatusObserver);
    [self.navigationController popViewControllerAnimated:NO];
    
//    if(m_mediaSave)
//        CMediaModelFactory::GetInstance()->ReleaseMediaSaver();
    m_mediaSave = NULL;
    if(m_pRecoSongInfo)
        delete m_pRecoSongInfo;
    m_pRecoSongInfo = NULL;
    
    [lyricView StopRefresh];
    lyricView=NULL;
    
    [MobClick endLogPageView:[NSString stringWithUTF8String:object_getClassName(self)]];
}

-(void) OperateBtnClick:(id)sender
{
    int ntag = ((UIButton*)sender).tag;
    if(ntag == Action_ReSing || ntag == Action_Emigrated_ReSing)
    {
        [self CloseView];
        KSKSongViewController * ksongView = [[[KSKSongViewController alloc]init]autorelease];
        //[ksongView SetEmigrated:m_bEmigrated :m_EmigratedWebView ];
        [ksongView SetRecordId:strRecordId Record: true Video:false];
        [ROOT_NAVAGATION_CONTROLLER pushViewController:ksongView animated:YES];
        UMengLog(KS_RESING, "KSingResing");
 
    }
//    else if(ntag == Action_RePlay)
//    {
//        if(m_mediaReplay)
//            m_mediaReplay->Stop();
//        [self ReleaseReplay];
//        KSKSongViewController * ksongView = [[[KSKSongViewController alloc]init]autorelease];
//        [ksongView SetRecordId:strRecordId Record: false Video:bVideo];
//        [self.navigationController pushViewController:ksongView animated:YES];
//    }
    else if(ntag == Action_Save)
    {
         m_bUpLoad = false;
        if(strRecordId == "" && m_pRecoSongInfo->strSongName == "") // 清唱
        {
            [self ShowSimpleSongNameView];
        }
        else {
            [self StartSave];
        }
        
    }
    else if(ntag == Action_Upload){
        
        if(!User::GetUserInstance()->isOnline())
        {
            loginAlertView = [[[UIAlertView alloc]initWithTitle:@"" message:@"您还未登录，是否要登录？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"登录", nil]autorelease];
            [loginAlertView show];
            return;
        }
        float uilength = [KSAudioLength getRecordAudioLength:m_pRecoSongInfo->accompanyRes.strLocalPath];
        if(uilength < MIN_UPLOAD_LENGTH)
        {
            UIAlertView *alertview = [[[UIAlertView alloc]initWithTitle:@"" message:@"作品长度不足60秒,不能上传" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil]autorelease];
            [alertview show];
            return;
        }
        m_bUpLoad=true;
        if(strRecordId == "" && m_pRecoSongInfo->strSongName == "") // 清唱
        {
            [self ShowSimpleSongNameView];
        }
        else {
            //[self StartSave];
            ShareViewController *shareView=[[[ShareViewController alloc] init] autorelease];
            [shareView setShareSongInfo:m_pRecoSongInfo index:0 isVideo:bVideo];
            //[shareView setSongIndex:0];
            [ROOT_NAVAGATION_CONTROLLER pushViewController:shareView animated:YES];
        }        
    }
    else if(ntag == Action_Emigrated_Return){
        [self CloseView];
    }
    else if(ntag == Action_Emigrated_Normal){
        mainView.hidden = false;
    }
}

-(void)StartSave
{
    [self InitProgressView];

    if(!m_bUpLoad && m_pRecoSongInfo && m_pRecoSongInfo->eumLocalState == CRecoSongInfo::STATE_NOSAVE)
    {
        popView.hidden = false;
        progressLabel.text = @"正在合成录音...";
        [self SaveRecord];
    }
    
}

-(void)InitProgressView
{
    if(popView == nil)
    {
        popView = [[[UIView alloc]initWithFrame:self.view.bounds]autorelease];
        popView.backgroundColor = UIColorFromRGBAValue(0x000000,80);
        [[self view]addSubview:popView];
        
        CGRect rc = CenterRect(self.view.bounds, 180, 60);
        rc.origin.y -= 20;
        
        UIView * bkview = [[[UIView alloc]initWithFrame:rc]autorelease];
        bkview.backgroundColor = UIColorFromRGBAValue(0x000000,150);
        bkview.layer.cornerRadius = 4;
        bkview.layer.masksToBounds = true;
        [popView addSubview:bkview];
        
        progressLabel = [[[UILabel alloc]initWithFrame:CGRectMake(10,10, 160,20)] autorelease];
        progressLabel.textAlignment = UITextAlignmentCenter;
        progressLabel.backgroundColor = [UIColor clearColor];
        progressLabel.textColor = [UIColor whiteColor];
        progressLabel.font = [UIFont systemFontOfSize:14];
        [bkview addSubview:progressLabel];
        
        progressView = [[[KSProgressView alloc]initWithFrame:CGRectMake(10, 35, 160, 15)]autorelease];
        [progressView setOuterColor: [UIColor whiteColor]] ;
        [progressView setInnerColor: [UIColor whiteColor]];
        [bkview addSubview:progressView];
    }
    [progressView setProgress:0];
}

-(void)SaveRecord
{
    NSString *strname = GetCurTimeToString();
    strname = [strname stringByReplacingOccurrencesOfString:@":" withString:@""];
    strname = [strname stringByReplacingOccurrencesOfString:@"-" withString:@""];
    // 拷贝图片
    if(!bVideo)    // 非视频
    {
        if (CRecordTask::GetInstance()->m_bIsHrbActivity && User::GetUserInstance()->getPartInType()==PARTIN){
            NSString *strImgPath = KwTools::Dir::GetPath(KwTools::Dir::PATH_MYIMAGE);
            strImgPath = [strImgPath stringByAppendingPathComponent:strname];
            NSString *strScrPath = [[NSBundle mainBundle] pathForResource:@"HrbBkImage@2x" ofType:@"jpg"];
            NSString *strDesPath = [strImgPath stringByAppendingPathComponent:@"HrbBkImage.jpg"];
            if(!KwTools::Dir::IsExistFile(strImgPath))
                KwTools::Dir::MakeDir(strImgPath);
            NSFileManager *fileManage = [NSFileManager defaultManager];
            NSError *error;
            BOOL bRes=[fileManage copyItemAtPath:strScrPath toPath:strDesPath error:&error];
            if (bRes) {
                m_pRecoSongInfo->strLocalPicPack = [strImgPath UTF8String];
            }
        }
        else{
            NSString * strImgPath = KwTools::Dir::GetPath(KwTools::Dir::PATH_MYIMAGE);
            strImgPath = [strImgPath stringByAppendingPathComponent:strname];
            NSString * strsrcpath = KwTools::Dir::GetPath(KwTools::Dir::PATH_BKIMAGE);
            if(KwTools::Dir::CopyDir(strsrcpath, strImgPath))
            {
                m_pRecoSongInfo->strLocalPicPack = [strImgPath UTF8String];
            }
        }
    }
    if(m_mediaSave)
        CMediaModelFactory::GetInstance()->ReleaseMediaSaver();
    // 保存音频
    m_mediaSave = CMediaModelFactory::GetInstance()->CreateMediaSaver(bVideo);
    
    NSString *strpath = KwTools::Dir::GetPath(KwTools::Dir::PATH_OPUS);
    NSString *opusname;
    std::string strlog;
    if(bVideo)
    {
        strlog = "mp4";
        opusname = [NSString stringWithFormat:@"%@%s",strname,".mp4"];
        m_pRecoSongInfo->recoRes.eumFormat = FMT_VIDEO;
    }
    else {
        strlog = "m4a";
        opusname = [NSString stringWithFormat:@"%@%s",strname,".m4a"];
        m_pRecoSongInfo->recoRes.eumFormat = FMT_AAC_48;
    }
    
    strpath = [strpath stringByAppendingPathComponent:opusname];
    m_pRecoSongInfo->recoRes.strLocalPath = [strpath UTF8String];
    CRecordTask::GetInstance()->m_strSaveFilePath = [strpath UTF8String];
    m_pRecoSongInfo->recoRes.uiDuration = [KSAudioLength getRecordAudioLength:m_pRecoSongInfo->accompanyRes.strLocalPath];
    bool bret = m_mediaSave->SaveFile();
    if(!bret)
    {
        RTLog_SaveMusic(AR_FAIL,m_pRecoSongInfo->strSongName.c_str(),m_pRecoSongInfo->strArtist.c_str(),m_pRecoSongInfo->strRid.c_str(),strlog.c_str(),
                        0,CRecordTask::GetInstance()->GetEchoType(),0,0,m_pRecoSongInfo->uiPoints);
        UMengLog(KS_SAVE_MUSIC, "1");
        popView.hidden = true;
        UIAlertView* alert = [[[UIAlertView alloc]initWithTitle:@"保存" message:@"保存失败" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil]autorelease];
        [alert show];
    }else {
        RTLog_SaveMusic(AR_SUCCESS,m_pRecoSongInfo->strSongName.c_str(),m_pRecoSongInfo->strArtist.c_str(),m_pRecoSongInfo->strRid.c_str(),strlog.c_str(),
                        0,CRecordTask::GetInstance()->GetEchoType(),0,0,m_pRecoSongInfo->uiPoints);
        UMengLog(KS_SAVE_MUSIC, "0");
    }
}

-(void) ChooseRecord: (id)sender
{
     if(((UIButton*)sender).tag == 1)
     {
         if(m_mediaReplay)
             m_mediaReplay->SetAudioEchoEffect(NO_EFFECT);
         CRecordTask::GetInstance()->SetEchoType(NO_EFFECT);
     }
     else if(((UIButton*)sender).tag == 2)
     {
         CRecordTask::GetInstance()->SetEchoType(SMALL_ROOM_EFFECT);
         if(m_mediaReplay)
         m_mediaReplay->SetAudioEchoEffect(SMALL_ROOM_EFFECT);
     }
    else if(((UIButton*)sender).tag == 3)
    {
        CRecordTask::GetInstance()->SetEchoType(MID_ROOM_EFFECT);
        if(m_mediaReplay)
            m_mediaReplay->SetAudioEchoEffect(MID_ROOM_EFFECT);
     }
     else if(((UIButton*)sender).tag == 4)
     {
         CRecordTask::GetInstance()->SetEchoType(BIG_ROOM_EFFECT);
         if(m_mediaReplay)
         m_mediaReplay->SetAudioEchoEffect(BIG_ROOM_EFFECT);
     }
     else if(((UIButton*)sender).tag == 5)
     {
         CRecordTask::GetInstance()->SetEchoType(BIG_HALL_EFFECT);
         if(m_mediaReplay)
        m_mediaReplay->SetAudioEchoEffect(BIG_HALL_EFFECT);
     }
    for (size_t i = 0; i < arrRecordBtn.size(); i++) {
        if(((UIButton*)sender).tag == i+1)
            [arrRecordBtn[i] setEnabled:NO];
        else {
            [arrRecordBtn[i] setEnabled:YES];
        }
    }
}

-(void)InitPicker
{
    CGRect rcfloat = BottomRect([FloatView bounds], 82, 0);
    pickerView = [[[picturePickerView alloc]initWithFrame:rcfloat]autorelease];  
    pickerView.delegate = self;
    if (playPicView) 
        [pickerView setPlayView:playPicView];
    [FloatView addSubview:pickerView];
    NSString * strpath = KwTools::Dir::GetPath(KwTools::Dir::PATH_BKIMAGE);
    if(strpath != nil)
    {
        NSError * err = nil;
        NSArray *filearr = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:strpath error:&err]; 
        if(err == nil)
        {
            vector<NSString*>vectemp;
            for (NSString * str in filearr){
                str = [strpath stringByAppendingPathComponent:str];
                vectemp.push_back(str);
            }
            [pickerView setImagePathList:vectemp];
        }
    }
}

-(void) ChooseimageClick:(id)sender
{
    if (topResultbkView.isHidden == false) {
        [topResultbkView setHidden:true];
    }
    if(pickerView == nil)
    {
        [self InitPicker];
    }
    if (bShowBkView) {
        [self PopFloatView:false];
        bShowBkView = false;
        //[pickerView setHidden:true];
    }
    else {
        [self PopFloatView:true];
        bShowBkView = true;
        //[pickerView setHidden:false];
    }
}

-(void)PopFloatView:(bool)bpop
{
    if(!bpop)
    {
        CGRect rcfloat = FloatView.frame;
        rcfloat.origin.y += 80;
        
        [UIView animateWithDuration:0.5 animations:^{
            if (isPlaying) {
                KS_BLOCK_DECLARE
                {
                    [lyricView setHidden:false];
                }
                KS_BLOCK_ASYNRUN(500)
                
            }
            [FloatView setFrame:rcfloat]; 
        }];
    }
    else 
    {
        CGRect rcfloat = FloatView.frame;
        rcfloat.origin.y -= 80;
        [UIView animateWithDuration:0.5 animations:^{
            if (isPlaying) {
                [lyricView setHidden:true];
            }
            [FloatView setFrame:rcfloat]; 
        }];
    }

}

-(void)IAudioStateObserver_PlayStatusPlaying
{
    isPlaying=true;
    if (!bShowBkView) {
        [lyricView setHidden:false];
    }
    [btnplay setHidden:true];
    [self onRefreshControl];
}

-(void)IAudioStateObserver_PlayStatusPaused
{
    [btnplay setHidden:false];
    [self onRefreshControl];
    if (playPicView){
        [playPicView setHidden:false];
        [playPicView stop];
    }
    if (vedioView) {
        [vedioView setHidden:false];
    }
}

-(void)IAudioStateObserver_PlayStatusStop
{
    isPlaying=false;
    [lyricView setHidden:true];
    //[slider setHidden:true];
    [btnplay setHidden:false];
    if (playPicView) {
        [playPicView stop];
        [playPicView setHidden:true];
    }
    if (vedioView) {
        [vedioView setHidden:true];
    }
    [self onRefreshControl];
}

-(void)IAudioStateObserver_PlayStatusErr
{
}

-(void)IMediaSaveProcessObserver_SaveProgressChanged:(float)f_progress
{
    if (progressView) {
        [progressView setProgress:f_progress];
    }
}

-(void)IMediaSaveProcessObserver_SaveStatusFinish:(EFileSaveStatus)e_status : (int)n_save_time
{
    std::string strlog;
    if(bVideo)
    {
        strlog = "mp4";
    }
    else {
        strlog = "aac";
    }
    int nlength = m_pRecoSongInfo->recoRes.uiDuration/1000;
    if(e_status == E_SAVE_FAIL)
    {
        RTLog_SaveMusic(AR_FAIL,m_pRecoSongInfo->strSongName.c_str(),m_pRecoSongInfo->strArtist.c_str(),m_pRecoSongInfo->strRid.c_str(),strlog.c_str(),
                        0,CRecordTask::GetInstance()->GetEchoType(),nlength,n_save_time,m_pRecoSongInfo->uiPoints);
        popView.hidden = true;
        UIAlertView *alert= [[[UIAlertView alloc]initWithTitle:@"保存" message:@"保存失败" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil]autorelease];
        [alert show];
    }
    else {
        RTLog_SaveMusic(AR_SUCCESS,m_pRecoSongInfo->strSongName.c_str(),m_pRecoSongInfo->strArtist.c_str(),m_pRecoSongInfo->strRid.c_str(),strlog.c_str(),
                        KwTools::Dir::GetFileCount(m_pRecoSongInfo->strLocalPicPack),CRecordTask::GetInstance()->GetEchoType(),nlength,n_save_time,m_pRecoSongInfo->uiPoints);
        m_pRecoSongInfo->eumLocalState = CRecoSongInfo::STATE_NOUPLOAD;
        
        if(!m_bUpLoad)
        {
            BOOL bret = CMyOpusData::GetInstance()->AddSong(m_pRecoSongInfo);
            if(bret)
                progressLabel.text = @"保存成功";
            else {
                progressLabel.text = @"保存失败";
            }
            KS_BLOCK_DECLARE
            {
                popView.hidden = true;
                btnSave.enabled = false;
            }
            KS_BLOCK_ASYNRUN(1000);
        }
        else
            btnSave.enabled = false;
    }
}

- (void)IMyOpusObserver_FinishUploadOne:(unsigned)idx :(CRecoSongInfo*)pSong :(CMyOpusData::SEND_RESULT)sendRes
{
    if(sendRes == CMyOpusData::SEND_SUCCESS)
    {
        s_str_match_opus_kid = pSong->strKid;
        btnSave.enabled = false;
        btnUpload.enabled = false;
        
        bool b_spring_match_enable = true;
        KwConfig::GetConfigureInstance()->GetConfigBoolValue(SPRING_MATCH_GROUP, SPRING_MATCH_ENABLE, b_spring_match_enable);
        if (b_spring_match_enable) {
            UIAlertView* alert_view = [[[UIAlertView alloc] initWithTitle:@"雪碧音碰音" message:@"作品上传成功！\n是否将您的作品提交到“雪碧音碰音”活动？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确认", @"不再提示", nil] autorelease];
            [alert_view setTag:TAG_SPRING_ALERT];
            [alert_view show];
        }
    }
}

-(void)onRefreshControl
{
    int nCurTime = m_mediaReplay->CurrentTime();
    int nCurMin,nCunSec;
    nCurMin = nCurTime/60000;
    nCunSec = (nCurTime/1000)%60;
    int nDurTime = m_mediaReplay->Duration();
    int nMin,nSecond;
    nMin = nDurTime/60000;
    nSecond = (nDurTime/1000)%60;
    
    if(m_mediaReplay->GetPlayStatus() == PLAY_STATUS_STOP){
        [slider setValue:0];
        [timeLabel setText:[NSString stringWithFormat:@"00:00/%02d:%02d",nMin,nSecond]];
    }
    else {
        int nCurTime = m_mediaReplay->CurrentTime();
        int nDurTime = m_mediaReplay->Duration();
        float fpercent = 0;
        if(nDurTime)
            fpercent = float(nCurTime)/(float)nDurTime;
        [slider setValue:fpercent];
        [timeLabel setText:[NSString stringWithFormat:@"%02d:%02d/%02d:%02d",nCurMin,nCunSec,nMin,nSecond]];
    }
}

#pragma mark -
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (popView && popView.hidden==false) {
        return;
    }
    UITouch *touch=(UITouch *)[touches anyObject];
    CGRect rcbk = [[self view]bounds];
    rcbk.size.height = 320;
    if(!CGRectContainsPoint(rcbk, [touch locationInView:self.view]))
        return;
    if (m_mediaReplay && m_mediaReplay->GetPlayStatus() == PLAY_STATUS_PLAYING) {
        [btnplay setHidden:false];
        //[slider setHidden:true];
        m_mediaReplay->PausePlay();
        if (playPicView !=nil) {
            [playPicView stop];
            [playPicView setHidden:true];
        }
    }
    
    if (topResultbkView.isHidden == false) {
        [topResultbkView setHidden:true];
    }

    if(nameTextView)
        [nameTextView resignFirstResponder];
}

-(void)InitPicShow
{
    NSString * strpath = KwTools::Dir::GetPath(KwTools::Dir::PATH_BKIMAGE);
    if(strpath != nil)
    {
        NSError * err = nil;
        NSArray *filearr = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:strpath error:&err];
        if(err == nil)
        {
            vector<NSString*>vectemp;
            for (NSString * str in filearr){
                str = [strpath stringByAppendingPathComponent:str];
                vectemp.push_back(str);
            }
            [playPicView setImageList:vectemp];
        }
    }
}
-(std::string) GetLyricPath :(std::string)strid
{
    std::string strpath;
    KwTools::Dir::GetPath(KwTools::Dir::PATH_LYRIC,strpath);
    strpath += "/ac";
    strpath += strid;
    strpath += ".lrc";
    return strpath;
}
@end
