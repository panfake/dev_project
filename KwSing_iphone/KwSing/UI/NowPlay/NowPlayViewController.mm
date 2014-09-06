//
//  NowPlayViewController.m
//  KwSing
//
//  Created by Qian Hu on 12-8-14.
//  Copyright (c) 2012年 酷我音乐. All rights reserved.
//

#import "NowPlayViewController.h"
#include "KSAppDelegate.h"
#include "ImageMgr.h"
#include "playPicturesView.h"
#include "globalm.h"
#include "SongInfo.h"
#import "PlayMusicLyricView.h"
#include "KSWebView.h"
#include "LyricRequest.h"
#include "MessageManager.h"
#include "CommentViewController.h"
#include "KwTools.h"
#include "HttpRequest.h"
#include "MediaModelFactory.h"
#include "User.h"
#include "LoginViewController.h"
#include "User.h"
#include "ShareViewController.h"
#include "KSOtherLoginViewController.h"
#include "KSProgressView.h"
#include "IMusicLibObserver.h"
#include "LocalMusicRequest.h"
#include "KSongViewController.h"
#include "iToast.h"
#include "BaseWebViewController.h"
#include "MobClick.h"
#include "KuwoLog.h"
#include "MyPageViewController.h"
#include "WXApi.h"
#include "AWActionSheet.h"
#include "KwConfig.h"
#include "KwConfigElements.h"
#include "KwUMengElement.h"
#include "UMengLog.h"
#include "KwTools.h"
#include "SBJson.h"

#define REFRESH_CONTORL_INTERVAL    1 
#define WIDTH_DOWN_PROGRESS         135 
#define HEIGHT_TOPPICVIEW           320
#define HEIGHT_FLOATVIEW            62

#define URL_USERACTION              @"http://changba.kuwo.cn/kge/mobile/userAction"
#define URL_USERFLOWER              @"http://changba.kuwo.cn/kge/mobile/KgeFlower"
#define URL_FOLLOWOPERAT            @"http://changba.kuwo.cn/kge/mobile/FollowOperat"
#define KID_TO_SONGDATA_URL         "http://changba.kuwo.cn/kge/mobile/KgeData?id="
#define BASE_MUSIC_URL              @"http://player.kuwo.cn/webmusic/kgefs?"
#define GET_PLAYURL                 @"http://changba.kuwo.cn/kge/mobile/getPlayUrl"


#define ALERT_SINA_TAG              101
#define ALERT_QQ_TAG                102
#define ALERT_TENCENT_TAG           103
#define ALERT_RENREN_TAG            104

#define TAG_ACTIONSHEET_MORE_ONLINE  105
#define TAG_ACTIONSHEET_MORE_LOCAL   106
#define TAG_ACTIONSHEET_WEIXIN       107

enum NowPlay_Action_Type
{
    Action_Care = 0,
    Action_Flower,
    Action_Comment,
    Action_Share,
    Action_More
};

enum Status_NowPlay
{
    Status_Init,
    Status_Playing,
    Status_Over
};

enum Play_Type
{
    Play_Online,
    Play_Local,
    Play_Null
};

@interface NowPlayViewController () <IAudioStateObserver,UIActionSheetDelegate,IMusicLibObserver,AWActionSheetDelegate>
{
    UIView * floatView;
    PlayMusicLyricView *lyricView ;
    UISlider *slider;
    UIButton* btnpause;
    UIButton *btnplay;
    playPicturesView * picView;
    UIView * vedioView;
    bool m_bShowFloat;
    UILabel * songinfolable;
    UILabel * labtime1;
    UILabel * labtime2;
    UIImageView *progressview;
    UIButton* btnpic;
    
    NSTimer *timer;
    
    CLyricInfo  m_LyricInfo;
    
    CSongInfoBase* m_pSong;
    
    CMediaOnlinePlay* m_pPlayer;

    Status_NowPlay m_status;
    Play_Type m_playType;
    BOOL m_bIsVideo;
    
    UILabel *careLabel;
    UILabel *flowerLabel;
    UILabel *commentLabel;
    
    UIButton *careBtn;
    UIAlertView * loginAlertView;
    LOGIN_TYPE  m_nloginType;
    
    UIView *viewLoadMusic;
    KSProgressView *progressLoadMusic;
    UILabel *labelLoadMusic ;
    UIButton *btnLoadMusicSing;
    bool bCloseView;
    
    UIImageView * flowerView;
    UIImageView * heartView;
    UIActivityIndicatorView * indicatorView;
    
    bool m_bCare;   // 是否关注了该作品对作者
    bool m_bSeek;   // 是否在seekmedia
    
    bool m_bSendingFlower;
    
    bool m_bLocal;
    NSString* m_strKid;
}
@property (retain,nonatomic) NSString *playUrl;
- (void)requestPlayUrl;
- (void)requestLyric:(CSongInfoBase*)pSong;
- (void)createPlayer:(BOOL)bIsVideo :(BOOL)bLocal;
- (void)releasePlayer;

@end

@implementation NowPlayViewController

-(void)setPlayType:(bool)bLocal{
    m_bLocal = bLocal;
}

-(void)setKid:(NSString *)strKid{
    m_strKid = [[NSString alloc] initWithString:strKid];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    bCloseView = false;
    GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_MUSICLIB,IMusicLibObserver);
//    m_pSong = NULL;
    m_bShowFloat = true;
    if (m_pPlayer && (PLAY_STATUS_PLAYING == m_pPlayer->GetPlayingStatus())) {
        m_status = Status_Playing;
    }else {
        m_status = Status_Init;
    }
//    m_playType = Play_Null;
    viewLoadMusic = nil;
    m_bCare = false;
    m_bSeek = false;
    m_bSendingFlower = false;
    //self.view.backgroundColor = UIColorFromRGBValue(0xededed);
    
    CGRect rcpic = [[self view]bounds];
    rcpic.size.height = HEIGHT_TOPPICVIEW;
    picView = [[[playPicturesView alloc] initWithFrame:rcpic] autorelease];
    [[self view] addSubview:picView];
    
    vedioView = [[UIView alloc]initWithFrame:rcpic];
    [[self view] addSubview:vedioView];
    vedioView.hidden = true;
    
    CGRect rclyric = BottomRect(rcpic, 30, HEIGHT_FLOATVIEW);
    lyricView = [[PlayMusicLyricView alloc]initWithFrame:rclyric];
    [[self view]addSubview:lyricView];
    
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setBackgroundImage:CImageMgr::GetImageEx("KSongCloseNormal.png") forState:UIControlStateNormal];
    [btn setBackgroundImage:CImageMgr::GetImageEx("KSongCloseDown.png") forState:UIControlStateHighlighted];
    btn.frame = CGRectMake(self.view.bounds.size.width-44, 10, 34,34);
    [btn addTarget:self action:@selector(ReturnBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [[self view] addSubview:btn];
    
    songinfolable = [[[UILabel alloc]initWithFrame:CGRectMake(10, 13, self.view.bounds.size.width-54,20)] autorelease];
    songinfolable.textAlignment = UITextAlignmentLeft;
    songinfolable.backgroundColor = [UIColor clearColor];
    songinfolable.textColor = [UIColor whiteColor];
    songinfolable.font = [UIFont systemFontOfSize:18];
    [songinfolable setShadowOffset:CGSizeMake(1, 1)];
    [songinfolable setShadowColor:[UIColor grayColor]];
    if (Play_Local == m_playType) {
        songinfolable.text = [NSString stringWithFormat:@"%@-%@",[NSString stringWithUTF8String:m_pSong->strSongName.c_str()],
                                                   User::GetUserInstance()->getNickName()];
    }

    [[self view] addSubview:songinfolable];
    
    //浮层
    CGRect rcfloat = BottomRect(rcpic, HEIGHT_FLOATVIEW, 0);
    floatView = [[UIView alloc]initWithFrame:rcfloat];
    floatView.backgroundColor =  UIColorFromRGBAValue(0x000000,38);
    [[self view]addSubview:floatView];
    
    btnpic = [UIButton buttonWithType:UIButtonTypeCustom];
    btnpic.frame = CGRectMake(5, 5, 50,50);
    [btnpic setBackgroundImage:CImageMgr::GetImageEx("defaultface.png") forState:UIControlStateNormal];
    [btnpic addTarget:self action:@selector(SingerPicClick:) forControlEvents:UIControlEventTouchUpInside];
    btnpic.layer.cornerRadius = 4;
    btnpic.layer.masksToBounds = true;
    [floatView addSubview:btnpic];
    
    UIImage * imgplay = CImageMgr::GetImageEx("playBtnx.png");
    btnplay = [UIButton buttonWithType:UIButtonTypeCustom];
    btnplay.frame = CGRectMake(63,14, imgplay.size.width,imgplay.size.height);
    [btnplay setTag:1];
    [btnplay setBackgroundImage:imgplay forState:UIControlStateNormal];
    [btnplay addTarget:self action:@selector(ControlBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [floatView addSubview:btnplay];
    [btnplay setHidden:true];
    
    UIImage * imgpause = CImageMgr::GetImageEx("pauseBtnx.png");
    btnpause = [UIButton buttonWithType:UIButtonTypeCustom];
    btnpause.frame = CGRectMake(63,14, imgpause.size.width,imgpause.size.height);
    [btnpause setTag:2];
    [btnpause setBackgroundImage:imgpause forState:UIControlStateNormal];
    [btnpause addTarget:self action:@selector(ControlBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [floatView addSubview:btnpause];

    labtime1 = [[[UILabel alloc]initWithFrame:CGRectMake(105,25,37,15)] autorelease];
    labtime1.textAlignment = UITextAlignmentLeft;
    labtime1.backgroundColor = [UIColor clearColor];
    labtime1.font = [UIFont systemFontOfSize:13];
    labtime1.textColor = [UIColor whiteColor];
    labtime1.text = @"00:00";
    [floatView addSubview:labtime1];
    
    labtime2 = [[[UILabel alloc]initWithFrame:CGRectMake(280,25,37,15)] autorelease];
    labtime2.textAlignment = UITextAlignmentLeft;
    labtime2.backgroundColor = [UIColor clearColor];
    labtime2.font = [UIFont systemFontOfSize:13];
    labtime2.textColor = [UIColor whiteColor];
    labtime2.text = @"00:00";
    [floatView addSubview:labtime2];
    
    progressview = [[[UIImageView alloc]initWithFrame:CGRectMake(142, 29,0, 7)]autorelease];
    progressview.image = CImageMgr::GetImageEx("playProgressDownx_6.png");
    progressview.backgroundColor = [UIColor grayColor];
    [floatView addSubview:progressview];
    
    
    if (NSOrderedAscending != [[[UIDevice currentDevice] systemVersion] compare:@"7.0"]) {
        slider = [[[UISlider alloc]initWithFrame:CGRectMake(140, 25, 140, 15)]autorelease];
    }
    else{
        slider = [[[UISlider alloc]initWithFrame:CGRectMake(140, 21, 140, 15)]autorelease];
    }
    [slider setMaximumTrackImage:CImageMgr::GetImageEx("playSliderMax_6.png") forState:UIControlStateNormal];
    [slider setMinimumTrackImage: CImageMgr::GetImageEx("playSliderMin_6.png") forState:UIControlStateNormal];
    [slider setThumbImage:CImageMgr::GetImageEx("replayProBtn.png") forState:UIControlStateNormal];
    [floatView addSubview:slider];
    
    [slider addTarget:self action:@selector(seekMedia:) forControlEvents:UIControlEventValueChanged];
    [slider addTarget:self action:@selector(startSeekMedia:) forControlEvents:UIControlEventTouchDown];
    [slider addTarget:self action:@selector(endSeekMedia:) forControlEvents:UIControlEventTouchUpInside];
    
    UIView * bottombkView = [[[UIImageView alloc]init]autorelease];
    CGRect rcbkbottom = BottomRect([[self view]bounds],self.view.bounds.size.height-320,0);
    [bottombkView setFrame:rcbkbottom];
    //[bottombkView setImage:CImageMgr::GetImageEx("bottomKSongBK.png")];
    bottombkView.backgroundColor = UIColorFromRGBValue(0xededed);
    [[self view] addSubview:bottombkView];

    UIImage * shadowimage = CImageMgr::GetImageEx("nowplayshadow.png");
    UIImageView * shadowView = [[[UIImageView alloc]init]autorelease];
    [shadowView setFrame:CGRectMake(0, rcbkbottom.origin.y, 320, shadowimage.size.height)];
    [shadowView setImage:shadowimage];
    [[self view] addSubview:shadowView];

    UIImage * flowerimage = CImageMgr::GetImageEx("flower.png");
    flowerView = [[[UIImageView alloc]initWithImage:flowerimage]autorelease];
    flowerView.frame = CGRectMake(75,350,1,1);//CGRectMake((self.view.bounds.size.width-flowerimage.size.width)/2, 40, flowerimage.size.width, flowerimage.size.height);
    flowerView.hidden = true;
    [[self view]addSubview:flowerView];
    
    UIImage * heartimage = CImageMgr::GetImageEx("heart.png");
    heartView = [[[UIImageView alloc]initWithImage:heartimage]autorelease];
    heartView.hidden = true;
    heartView.frame = CGRectMake((self.view.bounds.size.width-heartimage.size.width)/2, 80, heartimage.size.width, heartimage.size.height);
    [[self view]addSubview:heartView];
    
    indicatorView = [[[UIActivityIndicatorView alloc]initWithFrame:CGRectMake(0, 0, 30, 30)]autorelease];
    [indicatorView setCenter:CGPointMake(HEIGHT_TOPPICVIEW/2, HEIGHT_TOPPICVIEW/2)];
    [[self view]addSubview:indicatorView];
    //[indicatorView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    indicatorView.hidden = true;
    
    [self InitButtons];

    timer = [NSTimer scheduledTimerWithTimeInterval:REFRESH_CONTORL_INTERVAL target:self selector:@selector(onRefreshControl) userInfo:nil repeats:YES];
    [timer fire];
    
    [MobClick beginLogPageView:[NSString stringWithUTF8String:object_getClassName(self)]];
    
    if (m_bLocal) {
        [self playLocalReco];
    }else {
        [self playId];
    }
    
}

//- (void)viewWillDisappear:(BOOL)animated{
//    NSLog(@"disappear!!!");
//}

- (void)stopPlay{
    
    if (lyricView) {
        [lyricView StopRefresh];
        [lyricView release];
        lyricView=NULL;
    }
    
    [timer invalidate];
    timer=NULL;
    
    GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_AUDIOSTATUS,IAudioStateObserver);
    
    if (m_pPlayer) {
        m_pPlayer->Stop();
    }
}

-(void)requestPlayUrl
{
    __block void* jsonData(NULL);
    __block unsigned int dataLength(0);
    KS_BLOCK_DECLARE
    {
        NSString * getPlayUrl=[NSString stringWithFormat:@"%@?id=%s",GET_PLAYURL,m_pSong->strKid.c_str()];
//        NSLog(@"get play url:%@",getPlayUrl);
        CHttpRequest::QuickSyncGet(getPlayUrl.UTF8String, jsonData, dataLength);
        NSData *retData=[NSData dataWithBytesNoCopy:jsonData length:dataLength freeWhenDone:YES];
        
        SBJsonParser *parser=[[SBJsonParser alloc] init];
        NSDictionary *parDic=[parser objectWithData:retData];
        [parser release];
//        NSLog(@"get play url ret:%@",[parDic description]);
        NSString *res=[parDic objectForKey:@"result"];
        if ([res isEqualToString:@"ok"]) {
            [self setPlayUrl:KwTools::Encoding::UrlDecode([parDic objectForKey:@"url"])];
       }
    }
    KS_BLOCK_RUN_THREAD()
}
-(void)playId
{
    KS_BLOCK_DECLARE
    {
        std::string strUrl=KID_TO_SONGDATA_URL;
        strUrl+=[m_strKid UTF8String];
        std::string strOut;
        if(CHttpRequest::QuickSyncGet(strUrl, strOut)) {
            std::map<std::string,std::string> mapTokens;
            KwTools::StringUtility::TokenizeKeyValue(strOut,mapTokens,"||","=",true);
            if (mapTokens["result"]=="ok") {
                CPlaySongInfo* info=new CPlaySongInfo;
                info->strRid=mapTokens["rid"];
                info->strKid=mapTokens["kid"];
                info->strSid=mapTokens["sid"];
                info->strSongName=mapTokens["title"];
                info->strArtist = mapTokens["artist"];
                info->strUserPic=mapTokens["userpic"];
                info->recoRes.strUrl=mapTokens["url"];
                info->strPicPackUrl=mapTokens["zip"];
                info->uiFlower=KwTools::Convert::ConvertToDouble(mapTokens["flower"]);
                info->uiComment=KwTools::Convert::ConvertToDouble(mapTokens["comment"]);
                info->strUserId=mapTokens["uid"];
                info->strUserName=mapTokens["uname"];
                info->uiCare=KwTools::Convert::ConvertToDouble(mapTokens["care"]);
                if (KwTools::Dir::GetFileExt(mapTokens["url"])=="mp4") {
                    info->recoRes.eumFormat=FMT_VIDEO;
                } else if (KwTools::Dir::GetFileExt(mapTokens["url"])=="mp3") {
                    info->recoRes.eumFormat=FMT_MP3_128;
                } else { //aac
                    info->recoRes.eumFormat=FMT_AAC_48;
                }
                
                KS_BLOCK_DECLARE
                {
                    if(bCloseView)
                        return;
                    if(m_pSong)delete m_pSong;
                    m_pSong=info;
                    [self createPlayer:info->recoRes.eumFormat==FMT_VIDEO :false];
                    picView.hidden = (info->recoRes.eumFormat==FMT_VIDEO);
                    vedioView.hidden = !(info->recoRes.eumFormat==FMT_VIDEO);
                    bool bret = false;
                    if(m_pPlayer->InitPlayer(&info->recoRes,vedioView))
                        bret = m_pPlayer->Play();
                    if(bret)
                    {
                        RTLog_Play(AR_SUCCESS,m_pSong->strSongName.c_str(),m_pSong->strArtist.c_str(),m_pSong->strRid.c_str(),ONLINE_MUSIC);
                        UMengLog(KS_PLAY_MUSIC, "0");
                    }
                    else
                    {
                        RTLog_Play(AR_FAIL,m_pSong->strSongName.c_str(),m_pSong->strArtist.c_str(),m_pSong->strRid.c_str(),ONLINE_MUSIC);
                        UMengLog(KS_PLAY_MUSIC, "1");
                    }
                    m_status = Status_Playing;
                    songinfolable.text = [NSString stringWithFormat:@"%@-%@",[NSString stringWithUTF8String:m_pSong->strSongName.c_str()],[NSString stringWithUTF8String:((CPlaySongInfo*)m_pSong)->strUserName.c_str()]];
                    careLabel.text = [NSString stringWithFormat:@"%d",((CPlaySongInfo*)m_pSong)->uiCare];
                    flowerLabel.text = [NSString stringWithFormat:@"%d",((CPlaySongInfo*)m_pSong)->uiFlower];
                    commentLabel.text = [NSString stringWithFormat:@"%d",((CPlaySongInfo*)m_pSong)->uiComment];
                    [self requestLyric:info];
                    [self GetUserPic];
                    [self RequestPicShow];
                    [self SetCareStatus];
                    [self requestPlayUrl];
                }
                KS_BLOCK_SYNRUN()
            }
            else if(mapTokens["result"]=="err")
            {
                KS_BLOCK_DECLARE
                {
                    if(bCloseView)
                        return;
                    songinfolable.text = @"缓冲失败";
                }
                KS_BLOCK_SYNRUN()
            }
        }
    }
    KS_BLOCK_RUN_THREAD();
}


-(void)startSeekMedia:(id)sender
{
    m_bSeek = true;
}

-(void)endSeekMedia:(id)sender
{
    m_bSeek = false;
    if(m_status == Status_Init)
        return;
    //添加响应事件
    float f = slider.value; //读取滑块的值
    if(m_pPlayer)
        m_pPlayer->Seek(f*m_pPlayer->Duration());
//    [self onRefreshControl];
}

-(void)seekMedia:(id)sender
{
    if(m_status == Status_Init || !m_pPlayer)
        return;
    int nDurTime = m_pPlayer->Duration();
    float f = slider.value;
    int nCurTime = nDurTime * f;
    int nCurMin,nCunSec;
    nCurMin = nCurTime/60000;
    nCunSec = (nCurTime/1000)%60;
    labtime1.text = [NSString stringWithFormat:@"%02d:%02d",nCurMin,nCunSec];
//    if(m_status == Status_Init)
//        return;
//    //添加响应事件
//    float f = slider.value; //读取滑块的值
//    if(m_pPlayer)
//        m_pPlayer->Seek(f*m_pPlayer->Duration());
}

-(void)onRefreshControl
{
    if(m_status != Status_Playing)
        return;
    int nCurTime = m_pPlayer->CurrentTime();
    int nDurTime = m_pPlayer->Duration();
    float fpercent = 0;
    if(nDurTime)
        fpercent = float(nCurTime)/(float)nDurTime;
    if(!m_bSeek)
        [slider setValue:fpercent];
    
    int nCurMin,nCunSec;
    nCurMin = nCurTime/60000;
    nCunSec = (nCurTime/1000)%60;
    int nMin,nSecond;
    nMin = nDurTime/60000;
    nSecond = (nDurTime/1000)%60;
    if(!m_bSeek)
        labtime1.text = [NSString stringWithFormat:@"%02d:%02d",nCurMin,nCunSec];
    labtime2.text = [NSString stringWithFormat:@"%02d:%02d",nMin,nSecond];
    
    // 缓冲进度
    CGRect rcpro = progressview.frame;
    float fdown = m_pPlayer->GetDownloadProgress();
    int width = WIDTH_DOWN_PROGRESS*fdown;
    if(width != rcpro.size.width )
    {
        rcpro.size.width = width;
        progressview.frame = rcpro;
    }

}

-(void)InitButtons
{
//    CGRect rcbkbottom = BottomRect([[self view]bounds],self.view.bounds.size.height-320, 0);
//    int x[5] = {9,68, 135,201,260};
//    int y[5] = {46,21,11,21,46};
    //UIImage * imageNormal = CImageMgr::GetImageEx("NowPlayBtnNormal.png");
    UIImage * imageDown = CImageMgr::GetImageEx("NowPlayBtnDown.png");
    
    std::string strIcon[5] = {
        "NowPlayNoAttentIcon.png"
        ,"NowPlayFlowerIcon.png"
        ,"NowPlayCommentIcon.png"
        ,"NowPlayShareIcon.png"
        ,"NowPlayMoreIcon.png"};
    
    NSString *strName[5] = {
        @"关注"
        ,@"送花"
        ,@"评论"
        ,@"分享"
        ,@"更多"};
    
    int YgapBetween4_5[5]={0};
    int XgapBetween4_5[5]={0};
    if (IsIphone5()) {
        YgapBetween4_5[0]=67;
        YgapBetween4_5[1]=22;
        YgapBetween4_5[2]=11;
        YgapBetween4_5[3]=22;
        YgapBetween4_5[4]=67;
        
        XgapBetween4_5[0]=4;
        XgapBetween4_5[1]=-6;
        XgapBetween4_5[2]=3;
        XgapBetween4_5[3]=10;
        XgapBetween4_5[4]=1;
    }
    for (int i = 0; i < 5; i++) {
        UIButton * btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTag:i];
        if(i == 0)
            careBtn = btn;
        //[btn setBackgroundImage:imageNormal forState:UIControlStateNormal];
        [btn setBackgroundImage:imageDown forState:UIControlStateHighlighted];
        [btn setImage:CImageMgr::GetImageEx(strIcon[i].c_str()) forState:UIControlStateNormal];
        //btn.frame = CGRectMake(x[i], y[i]+rcbkbottom.origin.y, imageNormal.size.width, imageNormal.size.height );
        btn.frame = CGRectMake(4+62*i+XgapBetween4_5[i], 350+YgapBetween4_5[i], 58, 58);
        [btn addTarget:self action:@selector(OperateBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [[self view]addSubview:btn];
        UILabel * label = [[[UILabel alloc]initWithFrame:CGRectMake(4+62*i+XgapBetween4_5[i], 414+YgapBetween4_5[i], 58, 13)]autorelease];
        label.textColor = UIColorFromRGBValue(0x2b2b2b);
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = UITextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:12.5];
        [label setShadowColor:UIColorFromRGBValue(0xffffff)];
        [label setShadowOffset:CGSizeMake(0, 1)];
        label.text = strName[i];
        [[self view]addSubview:label];
        
        if(i==0 || i==1 || i==2)
        {
            UILabel * label = [[[UILabel alloc]initWithFrame:CGRectMake(4+62*i+XgapBetween4_5[i], 433+YgapBetween4_5[i], 58, 10)]autorelease];
            label.textColor = UIColorFromRGBValue(0x969696);
            label.backgroundColor = [UIColor clearColor];
            label.textAlignment = UITextAlignmentCenter;
            label.font = [UIFont systemFontOfSize:9];
            [label setShadowColor:UIColorFromRGBValue(0xffffff)];
            [label setShadowOffset:CGSizeMake(0, 1)];
            [[self view]addSubview:label];
            if(i==0)
                careLabel = label;
            else if(i==1)
                flowerLabel = label;
            else if(i==2)
                commentLabel = label;

        }
    }
        
}


-(void)InitLoadMusicView
{
    if(viewLoadMusic == nil)
    {
        viewLoadMusic = [[[UIView alloc]initWithFrame:self.view.bounds]autorelease];
        viewLoadMusic.backgroundColor = UIColorFromRGBAValue(0x000000,80);
        [[self view]addSubview:viewLoadMusic];
        
        CGRect rc = CenterRect(self.view.bounds, 180, 100);
        rc.origin.y -= 20;
        
        UIView * bkview = [[[UIView alloc]initWithFrame:rc]autorelease];
        bkview.backgroundColor = UIColorFromRGBAValue(0x000000,150);
        bkview.layer.cornerRadius = 4;
        bkview.layer.masksToBounds = true;
        [viewLoadMusic addSubview:bkview];
        
        labelLoadMusic = [[[UILabel alloc]initWithFrame:CGRectMake(10,10, 160,20)] autorelease];
        labelLoadMusic.textAlignment = UITextAlignmentCenter;
        labelLoadMusic.backgroundColor = [UIColor clearColor];
        labelLoadMusic.textColor = [UIColor whiteColor];
        labelLoadMusic.font = [UIFont systemFontOfSize:14];
        
        [bkview addSubview:labelLoadMusic];
        
        progressLoadMusic = [[[KSProgressView alloc]initWithFrame:CGRectMake(10, 35, 160, 15)]autorelease];
        [progressLoadMusic setOuterColor: [UIColor whiteColor]] ;
        [progressLoadMusic setInnerColor: [UIColor whiteColor]];
        [bkview addSubview:progressLoadMusic];
        
        btnLoadMusicSing = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [btnLoadMusicSing setTitle:@"演唱" forState:UIControlStateNormal];
        [btnLoadMusicSing setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
        btnLoadMusicSing.frame = CGRectMake(10,60,70,25);
        
        [btnLoadMusicSing addTarget:self action:@selector(OnSingSong:) forControlEvents:UIControlEventTouchUpInside];
        [bkview addSubview:btnLoadMusicSing];
        
        UIButton *btncancel = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [btncancel setTitle:@"取消" forState:UIControlStateNormal];
        btncancel.frame = CGRectMake(100,60,70,25);
        [btncancel addTarget:self action:@selector(OnCancelSing:) forControlEvents:UIControlEventTouchUpInside];
        [bkview addSubview:btncancel];

    }
    labelLoadMusic.text = @"正在缓冲伴唱数据...";
    btnLoadMusicSing.enabled = false;
    [progressLoadMusic setProgress:0];
}

-(void) OnSingSong:(id)sender
{
    if(viewLoadMusic)
        viewLoadMusic.hidden = true;
    [self PopRecordView];
}

-(void)OnCancelSing:(id)sender
{
    if(viewLoadMusic)
        viewLoadMusic.hidden = true;
     if (m_pPlayer) m_pPlayer->Play();
    
    if(!m_pSong)
        return;
    CSongInfoBase * songinfo = CLocalMusicRequest::GetInstance()->GetLocalMusic(m_pSong->strRid);
    if(songinfo && ((CLocalTask*)songinfo)->taskStatus != TaskStatus_Finish)
    {
        CLocalMusicRequest::GetInstance()->DeleteTask(songinfo->strRid);
    }
}

-(void)requestLyric:(CSongInfoBase*)pSong
{
    bool bsuc = true;
    std::string strdir;
    KwTools::Dir::GetPath(KwTools::Dir::PATH_LYRIC,strdir);
    std::string strpath = strdir;
    if(pSong->strRid == "")
    {
        [lyricView SetLyricInfo:NULL];
        return;
    }
    else {
        strpath += "/ac";
        strpath += pSong->strRid;
        strpath += ".lrc"; //伴唱资源
        if(!KwTools::Dir::IsExistFile(strpath)) {
            strpath = strdir + "/or";
            strpath += pSong->strRid;
            strpath += ".lrc";
            if(!KwTools::Dir::IsExistFile(strpath))
            {
                bsuc = false;
            }
        }
    }
    if(bsuc) {
        if(m_LyricInfo.ReadFromFile(strpath))
        {
            [lyricView SetLyricInfo:&m_LyricInfo];
            [lyricView SetMedia:m_pPlayer];
        }
        else {
            [lyricView SetLyricInfo:NULL];
        }
    }
    else
    {
        CSongInfoBase * temp = new CSongInfoBase;
        *temp = *pSong;
        KS_BLOCK_DECLARE
        {
            CLyricRequest lyricRequest(temp);
            if(lyricRequest.SyncRequestLyric(true))
            {
                CLyricInfo & lyricinfo = lyricRequest.GetLyricInfo();
                lyricinfo.WriteToFile(strpath);
                KS_BLOCK_DECLARE
                {
                    if(m_LyricInfo.ReadFromFile(strpath))
                    {
                        [lyricView SetLyricInfo:&m_LyricInfo];
                        [lyricView SetMedia:m_pPlayer];
                    }
                    else {
                        [lyricView SetLyricInfo:NULL];
                    }
                }
                KS_BLOCK_SYNRUN()
            }
            else
            {
                KS_BLOCK_DECLARE
                {
                    [lyricView SetLyricInfo:NULL];
                }
                KS_BLOCK_SYNRUN()
            }
            delete temp;
        }
        KS_BLOCK_RUN_THREAD();
    }
    
}

-(void)SingBtnClick
{
    if (m_pPlayer) m_pPlayer->Pause();
    if(m_pSong->strRid == "")
    {
        //清唱
        [self PopRecordView];
        return;
    }
    CSongInfoBase* songinfo = CLocalMusicRequest::GetInstance()->GetLocalMusic(m_pSong->strRid);
    if(songinfo && ((CLocalTask*)songinfo)->taskStatus == TaskStatus_Finish)
    {
        [self PopRecordView];
        return;
    }
    bool bvalue = true;
    KwConfig::GetConfigureInstance()->GetConfigBoolValue(AUTHORITY_GROUP, AUTHORITY_AUTHORIZED, bvalue,true);
    if(!bvalue)
    {
        UIAlertView * alert = [[[UIAlertView alloc] initWithTitle:@"" message:@"基于版权保护，酷我音乐目前仅对中国大陆地区用户提供服务，敬请谅解" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil,nil]autorelease];
        [alert show];
        return;
    }
    [[[iToast makeText:NSLocalizedString(@"已添加至已点歌曲", @"")]setGravity:iToastGravityBottom ]show];
    CLocalMusicRequest::GetInstance()->DownTaskImmediately(m_pSong);
    [self InitLoadMusicView];
    [viewLoadMusic setHidden:false];
    return;
 
}

-(void)IObMusicLib_TaskProgress:(NSString*)strRid:(float)fPercent
{
    if(m_pSong && m_pSong->strRid == [strRid UTF8String] && viewLoadMusic && !viewLoadMusic.hidden)
    {
        [progressLoadMusic setProgress:fPercent];
    }
}

-(void)IObMusicLib_DownTaskFinish:(NSString*)strRid
{
    if(m_pSong && m_pSong->strRid == [strRid UTF8String] && viewLoadMusic && !viewLoadMusic.hidden)
    {
        labelLoadMusic.text = @"伴唱缓冲完成";
        [progressLoadMusic setProgress:1];
        btnLoadMusicSing.enabled = true;
    }
}

-(void)IObMusicLib_TaskFail:(NSString*)strRid
{
    if(m_pSong && m_pSong->strRid == [strRid UTF8String] && viewLoadMusic && !viewLoadMusic.hidden)
    {
        labelLoadMusic.text = @"伴唱缓冲失败";
    }
}

-(void)PopRecordView
{
    std::string strRecordId = m_pSong->strRid;
    KSKSongViewController * ksongView = [[[KSKSongViewController alloc]init]autorelease];
    [ksongView SetRecordId:strRecordId Record: true Video:false];
    [ROOT_NAVAGATION_CONTROLLER pushViewController:ksongView animated:YES];
}

-(void) OperateBtnClick:(id)sender
{
    if(!m_pSong)
        return;
    if([((UIButton*)sender) tag] == Action_More)
    {
        //[self SingBtnClick];
        if (m_playType == Play_Online) {
            UIActionSheet *actionSheet = [[[UIActionSheet alloc] initWithTitle:@"更多" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"我要唱",@"举报垃圾或色情内容", nil] autorelease];
            [actionSheet setTag:TAG_ACTIONSHEET_MORE_ONLINE];
            [actionSheet showInView:self.view];
        }
        else{
            UIActionSheet *actionSheet = [[[UIActionSheet alloc] initWithTitle:@"更多" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"我要唱", nil] autorelease];
            [actionSheet setTag:TAG_ACTIONSHEET_MORE_LOCAL];
            [actionSheet showInView:self.view];
        }
        return;
    }
    int ntag = [((UIButton*)sender) tag];
    if(m_playType != Play_Online)
    {
        if(ntag == Action_Care)
        {
            [[[iToast makeText:NSLocalizedString(@"不可以关注自己哦", @"")]setGravity:iToastGravityCenter  ]show];
            return;
        }
        else if(ntag == Action_Flower)
        {
            [[[iToast makeText:NSLocalizedString(@"把花送给其他人吧", @"")]setGravity:iToastGravityCenter  ]show];
            return;
        }
        else if(ntag == Action_Comment)
        {
            [[[iToast makeText:NSLocalizedString(@"本地作品播放，无法评论", @"")]setGravity:iToastGravityCenter  ]show];
            return;
        }
        else if( ntag == Action_Share && ((CRecoSongInfo*)m_pSong)->eumLocalState != CRecoSongInfo::STATE_UPLOADED)
        {
            [[[iToast makeText:NSLocalizedString(@"该作品还没有上传哦", @"")]setGravity:iToastGravityCenter  ]show];
            return;
        }
    }
    
    if(m_playType == Play_Local)
    {
        if(((CRecoSongInfo*)m_pSong)->eumLocalState != CRecoSongInfo::STATE_UPLOADED)
        {
            UIAlertView * alertview = [[[UIAlertView alloc]initWithTitle:@"上传后才能进行此操作" message:@"" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil]autorelease];
            [alertview show];
            return;
        }
        
    }
    
    if(ntag == Action_Comment)
    {
        CommentViewController * temp = [[[CommentViewController alloc]init]autorelease];
        if(m_playType == Play_Online)
            [temp SetMusicId:((CPlaySongInfo*)m_pSong)->strKid subjectID:((CPlaySongInfo*)m_pSong)->strSid  UserID:((CPlaySongInfo*)m_pSong)->strUserId];
        else if(m_playType == Play_Local)
            [temp SetMusicId:((CPlaySongInfo*)m_pSong)->strKid subjectID:((CRecoSongInfo*)m_pSong)->strKid  UserID:((CPlaySongInfo*)m_pSong)->strUserId];
        [ROOT_NAVAGATION_CONTROLLER pushViewController:temp animated:YES];
        return;
    }
    
    if(!User::GetUserInstance()->isOnline())
    {
        loginAlertView = [[[UIAlertView alloc]initWithTitle:@"" message:@"您还未登录，是否要登录？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"登录", nil]autorelease];
        [loginAlertView show];
        return;
    }
    
    if(ntag == Action_Care)
    {
        if([User::GetUserInstance()->getUserId() isEqualToString:[NSString stringWithUTF8String:((CPlaySongInfo*)m_pSong)->strUserId.c_str()]])
        {
            [[[iToast makeText:NSLocalizedString(@"不可以关注自己哦", @"")]setGravity:iToastGravityCenter  ]show];
            return;
        }
        if(!m_bCare)
        {
            [self CareOther];
        }
       
    }
    else if(ntag == Action_Flower)
    {
        if([User::GetUserInstance()->getUserId() isEqualToString:[NSString stringWithUTF8String:((CPlaySongInfo*)m_pSong)->strUserId.c_str()]])
        {
            [[[iToast makeText:NSLocalizedString(@"把花送给其他人吧", @"")]setGravity:iToastGravityCenter  ]show];
            return;
        }
        if (!m_bSendingFlower) {
            indicatorView.hidden = false;
            [indicatorView startAnimating];
            [self SendFlower];
            m_bSendingFlower = true;
        }
        
    }
    else if(ntag == Action_Share)
    {

        if(User::GetUserInstance()->isOnline())
        {
            AWActionSheet *sheet = [[[AWActionSheet alloc] initwithIconSheetDelegate:self ItemCount:[self numberOfItemsInActionSheet]] autorelease];
            [sheet showInView:self.view];
//            UIActionSheet * menu = [[[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"分享到微信", nil] autorelease];
//            
//            [menu showInView:self.view];
        }
        else {
            //[self ShareSong:LOGIN_TYPE(onlineType-1)];
        }
    }
}

- (int)numberOfItemsInActionSheet
{
    return 4;
}

- (AWActionSheetCell*)cellForActionAtIndex:(NSInteger)index
{
    AWActionSheetCell* cell = [[[AWActionSheetCell alloc] init] autorelease];
    NSArray * arrname = @[@"QQ空间",@"新浪微博",@"微信",@"人人网"];
    std::string stricon[5] = {"qqShare.png","sinaShare.png","weixinShare.png","renrenShare.png"};//,"tencentShare.png","renrenShare.png"};
    [[cell iconView] setImage:CImageMgr::GetImageEx(stricon[index].c_str())];
    [[cell titleLabel] setText:[arrname objectAtIndex:index]];
    cell.index = index;
    return cell;
}

- (void)DidTapOnItemAtIndex:(NSInteger)index
{
    switch (index) {
        case 0:
            [self ShareSong:User::BIND_QQ];
            break;
        case 1:
            [self ShareSong:User::BIND_SINA];
            break;
        case 2:
        {
            if ([WXApi isWXAppInstalled] && [WXApi isWXAppSupportApi]) {
                UIActionSheet *weixinShareSelect=[[[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:nil otherButtonTitles:@"用微信发给朋友",@"分享到微信朋友圈", nil] autorelease];
                [weixinShareSelect setTag:TAG_ACTIONSHEET_WEIXIN];
                [weixinShareSelect showInView:self.view];
            }
            else if(![WXApi isWXAppInstalled]){
                UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"提示" message:@"您还未安装微信" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil] autorelease];
                [alert show];
            }
            else{
                UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"提示" message:@"您当前微信版本不支持分享，请升级后再试！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil] autorelease];
                [alert show];
            }
        }
            break;
        case 3:
            [self ShareSong:User::BIND_RENREN];
            break;
//        case 4:
//            [self ShareSong:User::BIND_RENREN];
//            break;
        default:
            break;
    }
}
-(BOOL)checkTypeIsBindAndAlert:(User::BindType)type
{
    switch (type) {
        case User::BIND_QQ:
        {
            if (!User::GetUserInstance()->isQQBind()) {
                UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"提示" message:@"您的QQ账号还未绑定，是否立即绑定" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil] autorelease];
                [alert setTag:ALERT_QQ_TAG];
                [alert show];
                return false;
            }
            else
                return true;
        }
            break;
        case User::BIND_SINA:
        {
            if (!User::GetUserInstance()->isSinaBind()) {
                UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"提示" message:@"您的Sina账号还未绑定，是否立即绑定" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil] autorelease];
                [alert setTag:ALERT_SINA_TAG];
                [alert show];
                return false;
            }
            else
                return true;
        }
            break;
        case User::BIND_TENCENT:
        {
            if (!User::GetUserInstance()->isTencnetBind()) {
                UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"提示" message:@"您的tencent微博账号还未绑定，是否立即绑定" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil] autorelease];
                [alert setTag:ALERT_TENCENT_TAG];
                [alert show];
                return false;
            }
            else
                return true;
        }
            break;
        case User::BIND_RENREN:
        {
            if (!User::GetUserInstance()->isRenrenBind()) {
                UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"提示" message:@"您的RenRen账号还未绑定，是否立即绑定" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil] autorelease];
                [alert setTag:ALERT_RENREN_TAG];
                [alert show];
                return false;
            }
            else
                return true;
        }
            break;
        default:
            break;
    }
}
-(void)ShareSong:(User::BindType)type
{
    BOOL isBind=[self checkTypeIsBindAndAlert:type];
    if (!isBind) {
        return;
    }
    ShareViewController * shareView = [[[ShareViewController alloc] init]autorelease];
    [shareView setIsShare:YES];
    if(m_playType == Play_Online)
    {
        shareView.shareText = [NSString stringWithFormat:@"我刚刚听到%@唱的《%@》，绝对够赞！快来听听吧！（分享自#酷我K歌#@酷我音乐）",[NSString stringWithUTF8String:((CPlaySongInfo*)m_pSong)->strUserName.c_str()],[NSString stringWithUTF8String:m_pSong->strSongName.c_str()]];
        shareView.shareURL=[NSString stringWithFormat:@"http://kzone.kuwo.cn/mlog/u%s/kge_%s.htm",((CPlaySongInfo*)m_pSong)->strUserId.c_str(),m_pSong->strKid.c_str()];
    }
    else if(m_playType == Play_Local)
    {
        shareView.shareText = [NSString stringWithFormat:@"我刚刚听到%@唱的《%@》，绝对够赞！快来听听吧！（分享自#酷我K歌#@酷我音乐）",User::GetUserInstance()->getNickName(),[NSString stringWithUTF8String:m_pSong->strSongName.c_str()]];
        shareView.shareURL=[NSString stringWithFormat:@"http://kzone.kuwo.cn/mlog/u%@/kge_%s.htm",User::GetUserInstance()->getUserId(),m_pSong->strKid.c_str()];
    }
    [self.navigationController pushViewController:shareView animated:YES];
}

-(void)ShowHeart
{
    heartView.alpha = 1.0;
    heartView.transform = CGAffineTransformMakeScale(0.2, 0.2);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [UIView beginAnimations:nil context:context];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationDuration:0.5];
    heartView.hidden = false;
    heartView.transform = CGAffineTransformIdentity;
    [UIView commitAnimations];
    
    KS_BLOCK_DECLARE
    {
        heartView.alpha = 0.0;
        CATransition *transition1 = [CATransition animation];    
        transition1.duration = 0.75f;         /* 间隔时间*/  
        transition1.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];      
        transition1.type = @"fade";      
        [heartView.layer addAnimation:transition1 forKey:@"animation1"];
        heartView.hidden = true;
    }
    KS_BLOCK_ASYNRUN(1000)

}

-(void)ShowFlower
{
    flowerView.hidden = false;
    flowerView.alpha = 1.0;
    CGContextRef context = UIGraphicsGetCurrentContext();
    [UIView beginAnimations:nil context:context];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationDuration:0.5];

    flowerView.frame = CGRectMake((self.view.bounds.size.width-157)/2, 40,157, 252);
    [UIView commitAnimations];

    KS_BLOCK_DECLARE
    {
        flowerView.alpha = 0.0;
        CATransition *transition1 = [CATransition animation];    
        transition1.duration = 0.75f;         /* 间隔时间*/  
        transition1.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];      
        transition1.type = @"fade";      
        [flowerView.layer addAnimation:transition1 forKey:@"animation1"];
        flowerView.hidden = true;
        flowerView.frame = CGRectMake(75,350,1,1);
    }
    KS_BLOCK_ASYNRUN(1500)


}

-(void)SendFlower
{
    NSString *strURL = [NSString stringWithFormat:@"%@?uid=%@&sid=%@",URL_USERFLOWER,
                                             User::GetUserInstance()->getUserId(),
                                             User::GetUserInstance()->getSid()];
    NSString* strPostUrl = [NSString stringWithFormat:@"%@?id=%s&uid=%@&sid=%@&tv=1",URL_USERFLOWER,
                            m_pSong->strKid.c_str(),
                                                 User::GetUserInstance()->getUserId(),
                                                 User::GetUserInstance()->getSid()];
    KS_BLOCK_DECLARE
    {
        //得到当前用户还可送出的花数

        std::string strOut;
        BOOL bret = CHttpRequest::QuickSyncGet([strURL UTF8String], strOut);
        if(bret)
        {
            strOut = strOut.substr(1,strOut.length()-2);
            std::map<std::string,std::string> mapToken;
            KwTools::StringUtility::TokenizeKeyValue(strOut, mapToken,",",":");
            std::string str = mapToken["\"result\""];
            if(mapToken["\"result\""] == "\"ok\"")
            {
                std::string strtemp = mapToken["\"leftFlower\""];
                int nleftflower = atoi(strtemp.c_str());
                if(nleftflower > 0)  //剩余花大于1
                {
                    //送花
                    std::string strResult; 
                    BOOL bret = CHttpRequest::QuickSyncGet([strPostUrl UTF8String], strResult);
                    if(bret)
                    {
                        strResult = strResult.substr(1,strResult.length()-2);
                        std::map<std::string,std::string> mapToken1;
                        KwTools::StringUtility::TokenizeKeyValue(strResult, mapToken1,",", ":");
                        if(mapToken1["\"result\""] == "\"ok\"")
                        {
                            KS_BLOCK_DECLARE
                            {
                                if (!bCloseView) {
                                    [self ShowFlower];
                                    ((CPlaySongInfo*)m_pSong)->uiFlower++;
                                    flowerLabel.text = [NSString stringWithFormat:@"%d",((CPlaySongInfo*)m_pSong)->uiFlower];
                                }

                            }
                            KS_BLOCK_SYNRUN();
                        }
                    }
                }
                else {    //没有剩余花了
                    KS_BLOCK_DECLARE
                    {
                        if (!bCloseView) {
                            [[[iToast makeText:NSLocalizedString(@"每人每天只可以送20朵花", @"")]setGravity:iToastGravityCenter  ]show];
                        }
                    }
                    KS_BLOCK_SYNRUN();
                }
            }
            else
            {
                // no login
                //NSLog(@"send flower err! %s",strOut.c_str());
            }

        }

        KS_BLOCK_DECLARE
        {
            indicatorView.hidden = true;
            m_bSendingFlower = false;
            [indicatorView stopAnimating];
        }
        KS_BLOCK_SYNRUN();
    }
    KS_BLOCK_RUN_THREAD();
}

-(void) SetCareStatus
{
    std::string userid;
    if(m_playType == Play_Online)
        userid = ((CPlaySongInfo*)m_pSong)->strUserId;
    NSString *strURL = [NSString stringWithFormat:@"%@?act=chk&uid=%@&tid=%s&sid=%@",URL_FOLLOWOPERAT,
                                             User::GetUserInstance()->getUserId(),userid.c_str(),
                                             User::GetUserInstance()->getSid()];
    KS_BLOCK_DECLARE
    {
        std::string strOut;
        BOOL bret = CHttpRequest::QuickSyncGet([strURL UTF8String], strOut);
        if(bret)
        {
            std::map<std::string,std::string> mapToken;
            KwTools::StringUtility::TokenizeKeyValue(strOut, mapToken,"&","=");
            if(mapToken["result"] == "ok" && mapToken["rel"] == "1")
            {
                KS_BLOCK_DECLARE
                {
                    m_bCare = true;
                    [careBtn setImage:CImageMgr::GetImageEx("NowPlayAttentIcon.png") forState:UIControlStateNormal];
                    [careBtn setEnabled:false];
                }
                KS_BLOCK_SYNRUN();
            }
        }
    }
    KS_BLOCK_RUN_THREAD();
}

-(void) CareOther
{
    std::string userid;
    if(m_playType == Play_Online)
        userid = ((CPlaySongInfo*)m_pSong)->strUserId;
    NSString *strURL = [NSString stringWithFormat:@"%@?fid=%@&tid=%s&sid=%@&type=care",URL_USERACTION,
                                             User::GetUserInstance()->getUserId(),userid.c_str(),
                                             User::GetUserInstance()->getSid()];
    KS_BLOCK_DECLARE
    {
        std::string strOut;
        BOOL bret = CHttpRequest::QuickSyncGet([strURL UTF8String], strOut);
        if(bret)
        {
            std::map<std::string,std::string> mapToken;
            KwTools::StringUtility::TokenizeKeyValue(strOut, mapToken,"&","=");
            if(mapToken["result"] == "ok")
            {
                KS_BLOCK_DECLARE
                {
                    if(bCloseView)
                        return ;
                    if(!m_bCare)
                    {
                        [self ShowHeart];
                        m_bCare = true;
                        [careBtn setImage:CImageMgr::GetImageEx("NowPlayAttentIcon.png") forState:UIControlStateNormal];
                        [careBtn setEnabled:false];
                        ((CPlaySongInfo*)m_pSong)->uiCare++;
                        careLabel.text = [NSString stringWithFormat:@"%d",((CPlaySongInfo*)m_pSong)->uiCare];
                    }

                }
                KS_BLOCK_SYNRUN();
            }
        }
    }
    KS_BLOCK_RUN_THREAD();

}
-(NSString*)getSendImagePath
{
    NSString * strpath = KwTools::Dir::GetPath(KwTools::Dir::PATH_CASHE);
    strpath = [strpath stringByAppendingPathComponent:@"userpic"];
    if(m_playType == Play_Online)
        strpath = [strpath stringByAppendingPathComponent:[NSString stringWithFormat:@"%s.jpg",((CPlaySongInfo*)m_pSong)->strUserId.c_str()]];
    else if(m_playType == Play_Local)
        strpath = [strpath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg",User::GetUserInstance()->getUserId()]];
    return strpath;
}
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
{
    if (actionSheet.tag == TAG_ACTIONSHEET_WEIXIN) {
        if (buttonIndex == 2) {
            return;
        }
        WXMediaMessage *sendMsg=[WXMediaMessage message];
        NSString *tit=[NSString stringWithUTF8String:m_pSong->strSongName.c_str()];
        sendMsg.title=tit;
        if (m_playType == Play_Local) {
            //分享本地作品可能不是现在登录的账号的作品，但是按照他的作品处理
            sendMsg.description=User::GetUserInstance()->getNickName();
        }
        else{
            sendMsg.description=[NSString stringWithUTF8String:((CPlaySongInfo*)m_pSong)->strUserName.c_str()];
        }
        UIImage* sendImage=[UIImage imageWithContentsOfFile:[self getSendImagePath]];
        [sendMsg setThumbImage:sendImage];
        
        WXMusicObject *ext = [WXMusicObject object];
        NSString* music=[NSString stringWithFormat:@"%@kid=%s",BASE_MUSIC_URL,m_pSong->strKid.c_str()];
        ext.musicUrl = music;
        //    NSLog(@"share url:%@",[self playUrl]);
        ext.musicDataUrl = [self playUrl];
        
        sendMsg.mediaObject=ext;
        
        SendMessageToWXReq* req = [[[SendMessageToWXReq alloc] init]autorelease];
        req.message=sendMsg;
        req.bText=false;
        if (buttonIndex  == 0) {
            req.scene=WXSceneSession;
        }
        else{
            req.scene=WXSceneTimeline;
        }
        [WXApi sendReq:req];

    }
    else if (actionSheet.tag == TAG_ACTIONSHEET_MORE_ONLINE){
        if (buttonIndex == 2) {
            return;
        }
        else if (buttonIndex == 0){
            [self SingBtnClick];
        }
        else if (buttonIndex == 1){
            [self reportSong];
        }
    }
    else{
        if (1 == buttonIndex) {
            return;
        }
        else if (0 == buttonIndex){
            [self SingBtnClick];
        }
    }
}
-(void)reportSong
{
    NSLog(@"report song :%s",m_pSong->strKid.c_str());
    UMengLog(KS_BLUE_OPUS, m_pSong->strKid);
    UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"感谢您的反馈" message:@"我们回认真处理您的反馈，努力为大家创造一个良好的K歌环境" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil] autorelease];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(alertView == loginAlertView)
    {
        if(buttonIndex == 1)
        {
//            if(m_pPlayer && m_status == Status_Playing)
//                m_pPlayer->Pause();
            // 弹出登录
            KSLoginViewController* loginController=[[[KSLoginViewController alloc] init]autorelease];
            [ROOT_NAVAGATION_CONTROLLER pushViewController:loginController animated:YES];
        }
    }
    else
    {
        if (buttonIndex != 1) {
            return;
        }
        switch (alertView.tag) {
            case ALERT_QQ_TAG:
            {
                KSOtherLoginViewController *loginViewController=[[KSOtherLoginViewController alloc] initWithType:QQ];
                [loginViewController setIsShare:true];
                [ROOT_NAVAGATION_CONTROLLER pushViewController:loginViewController animated:YES];
                [loginViewController release];
                loginViewController = nil;
            }
                break;
            case ALERT_SINA_TAG:
            {
                KSOtherLoginViewController *loginViewController=[[KSOtherLoginViewController alloc] initWithType:SINA];
                [loginViewController setIsShare:true];
                [ROOT_NAVAGATION_CONTROLLER pushViewController:loginViewController animated:YES];
                [loginViewController release];
                loginViewController = nil;
            }
                break;
            case ALERT_TENCENT_TAG:
            {
                KSOtherLoginViewController *loginViewController=[[KSOtherLoginViewController alloc] initWithType:TENCENTWEIBO];
                [loginViewController setIsShare:true];
                [ROOT_NAVAGATION_CONTROLLER pushViewController:loginViewController animated:YES];
                [loginViewController release];
                loginViewController = nil;
            }
                break;
            case ALERT_RENREN_TAG:
            {
                KSOtherLoginViewController *loginViewController=[[KSOtherLoginViewController alloc] initWithType:RENREN];
                [loginViewController setIsShare:true];
                [ROOT_NAVAGATION_CONTROLLER pushViewController:loginViewController animated:YES];
                [loginViewController release];
                loginViewController = nil;
            }
                break;
            default:
                break;
        }
    }
}

-(void)ClearMedia
{
    GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_AUDIOSTATUS,IAudioStateObserver);
    [lyricView SetMedia:nil];
    if(picView)
        [picView stop];
    m_pPlayer = nil;
    [btnpause setHidden:true];
    [btnplay setHidden:false];
    labtime1.text = @"00:00";
    labtime2.text = @"00:00";
    [slider setValue:0];
    m_status = Status_Over;
}

-(void)ResetMedia
{
    if(!m_pSong || m_playType != Play_Online || m_status != Status_Over)
        return;
    [self createPlayer:((CPlaySongInfo*)m_pSong)->recoRes.eumFormat==FMT_VIDEO :false];
    m_pPlayer->InitPlayer(&((CPlaySongInfo*)m_pSong)->recoRes,vedioView);//todo video view
    m_pPlayer->Play();
    [lyricView SetMedia:m_pPlayer];
    m_status = Status_Playing;

}


-(void) ReturnBtnClick:(id)sender
{
    GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_MUSICLIB,IMusicLibObserver);
    
    bCloseView = true;
    if (lyricView) {
        [lyricView StopRefresh];
        [lyricView release];
        lyricView=NULL;
    }
    
    [timer invalidate];
    timer=NULL;
    
    if (m_pPlayer) {
        [self releasePlayer];
        m_pPlayer=nil;
    }

    
    [self ClearMedia];
    
    picView=NULL;
    if (m_pSong) {
        delete m_pSong;
        m_pSong=NULL;
    }
    [self.navigationController popViewControllerAnimated:NO];
    
    [MobClick endLogPageView:[NSString stringWithUTF8String:object_getClassName(self)]];
}

-(void) ControlBtnClick:(id)sender
{
    if (sender==btnpause) {
        if (m_pPlayer) m_pPlayer->Pause();
    } else if (sender==btnplay) {
        if (m_pPlayer) m_pPlayer->Play();
        else
            [self ResetMedia];
    }
    
}

-(void)UpdateFloatView
{
    if(m_bShowFloat)
    {
        m_bShowFloat = false;
        CGRect rclrcend = BottomRect([picView frame], 30, 0);
        [UIView animateWithDuration:0.5 animations:^{
            [lyricView setFrame:rclrcend];
        } ];
        CGRect rcend = [floatView frame];
        rcend.origin.y += rcend.size.height;
        [UIView animateWithDuration:0.5 animations:^{
            [floatView setFrame:rcend];
        } ];
        [UIView animateWithDuration:0.5 animations:^{
            [songinfolable setAlpha:0];
        } ];
        
    }  else {
        m_bShowFloat = true;
        CGRect rclrcend = BottomRect([picView frame], 30, 62);
        [UIView animateWithDuration:0.5 animations:^{
            [lyricView setFrame:rclrcend];
        } ];
        CGRect rcend = BottomRect([picView frame], 62, 0);
        [UIView animateWithDuration:0.5 animations:^{
            [floatView setFrame:rcend];
        } ];
        [UIView animateWithDuration:0.5 animations:^{
            [songinfolable setAlpha:1];
        } ];
    }

}

#define URL_USERHOME    @"http://changba.kuwo.cn/kge/webmobile/ios/userhome.html"
#define URL_MYHOME      @"http://changba.kuwo.cn/kge/webmobile/ios/myhome.html"
-(void) SingerPicClick:(id)sender
{
    if(!m_pSong || m_playType != Play_Online)
        return;
   
    if(User::GetUserInstance()->isOnline() && [User::GetUserInstance()->getUserId() isEqualToString:[NSString stringWithUTF8String:((CPlaySongInfo*)m_pSong)->strUserId.c_str()]])
    {
        return;
//        MyPageViewController * mypageView = [[[MyPageViewController alloc]init]autorelease];
//        [ROOT_NAVAGATION_CONTROLLER pushViewController:mypageView animated:YES];
    }
    else
    {
         BaseWebViewController * temp = [[[BaseWebViewController alloc]init]autorelease];
        temp.title = [NSString stringWithFormat:@"%@的个人主页",[NSString stringWithUTF8String:((CPlaySongInfo*)m_pSong)->strUserName.c_str()]];
        temp.strUrl = [NSString stringWithFormat:@"%@?=777=%s",URL_USERHOME,((CPlaySongInfo*)m_pSong)->strUserId.c_str()];
        [ROOT_NAVAGATION_CONTROLLER pushViewController:temp animated:YES];
    }

    
}

- (void)setSongInfo:(CRecoSongInfo*)songinfo{
    if(m_pSong)delete m_pSong;
    m_pSong = NULL;
    CRecoSongInfo * tempsong = new CRecoSongInfo;
    *tempsong=(*songinfo);
    m_pSong = tempsong;
}
- (void)playLocalReco
{
    m_playType = Play_Local;
    [self createPlayer:((CRecoSongInfo*)m_pSong)->recoRes.eumFormat==FMT_VIDEO :true];
    picView.hidden = (((CRecoSongInfo*)m_pSong)->recoRes.eumFormat==FMT_VIDEO);
    vedioView.hidden = !(((CRecoSongInfo*)m_pSong)->recoRes.eumFormat==FMT_VIDEO);
    m_pPlayer->InitPlayer(&((CRecoSongInfo*)m_pSong)->recoRes,vedioView);//todo video view
    m_pPlayer->Play();
    m_status = Status_Playing;
    [self requestPlayUrl];
    
    if(!User::GetUserInstance()->isOnline())
        songinfolable.text = [NSString stringWithFormat:@"%@-%@",[NSString stringWithUTF8String:((CRecoSongInfo*)m_pSong)->strSongName.c_str()],
                             [NSString stringWithUTF8String:((CRecoSongInfo*)m_pSong)->strArtist.c_str()]];
    else
        songinfolable.text = [NSString stringWithFormat:@"%@-%@",[NSString stringWithUTF8String:((CRecoSongInfo*)m_pSong)->strSongName.c_str()],
                                               User::GetUserInstance()->getNickName()];

    if(((CRecoSongInfo*)m_pSong)->strRid != "")
    {
        [self requestLyric:m_pSong];
    }
    else {
        [lyricView SetLyricInfo:NULL];
    }

    [self GetUserPic];
    [self RequestPicShow];
    
}

-(void)InitPicView :(NSString*)strpath
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
        [picView setImageList:vectemp];
        [picView startPlay];
    }

}

-(void)RequestPicShow
{
    if(m_playType == Play_Local)
    {
        std::string strlocalpath = ((CRecoSongInfo*)m_pSong)->strLocalPicPack;//[KwTools::Dir::GetPath(KwTools::Dir::PATH_BKIMAGE) UTF8String];
        if(strlocalpath != "")
        {
            NSString *strpath = [NSString stringWithUTF8String:strlocalpath.c_str()];
            [self InitPicView:strpath];
        }
    }
    else if(m_playType == Play_Online && m_pSong){
        
        NSString * strPicPackPath = KwTools::Dir::GetPath(KwTools::Dir::PATH_CASHE);
        strPicPackPath = [strPicPackPath stringByAppendingPathComponent:@"picpack"];
        NSString * strDirPath = [strPicPackPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%s",((CPlaySongInfo*)m_pSong)->strKid.c_str()]];
        if(KwTools::Dir::IsExistFile(strDirPath))
        {
             [self InitPicView:strDirPath];
        }
        else {
            KS_BLOCK_DECLARE
            {
                if(m_pSong &&  ((CPlaySongInfo*)m_pSong)->strPicPackUrl != "")
                {
                    CHttpRequest request( ((CPlaySongInfo*)m_pSong)->strPicPackUrl);
                    if(!KwTools::Dir::IsExistFile(strPicPackPath))
                        KwTools::Dir::MakeDir(strPicPackPath);
                    NSString *strzippath = [strPicPackPath stringByAppendingPathComponent:[NSString stringWithFormat:@"pack%s.zip",((CPlaySongInfo*)m_pSong)->strKid.c_str()]];
                    BOOL bret = request.SyncSendRequest([strzippath UTF8String]);
                    if(bret)
                    {
                        if(KwTools::Filezip::UnCompress(strzippath, strDirPath))
                        {
                            KS_BLOCK_DECLARE
                            {
                                if (!bCloseView) {
                                    [self InitPicView:strDirPath];
                                }
                            }
                            KS_BLOCK_SYNRUN()
                        }
                        KwTools::Dir::DeleteFile(strzippath);
                    }
                }
            }
            KS_BLOCK_RUN_THREAD();

        }
     
    }
   

}

-(void) GetUserPic
{
    if(!m_pSong )
         return;
    std::string strUserUrl;
    if(m_playType == Play_Online)
        strUserUrl = ((CPlaySongInfo*)m_pSong)->strUserPic;
    else if(m_playType == Play_Local)
    {
        if(!User::GetUserInstance()->isOnline())
            return;
        NSString * strpath = KwTools::Dir::GetPath(KwTools::Dir::PATH_CASHE);
        strpath = [strpath stringByAppendingPathComponent:@"userpic"];
        strpath = [strpath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg",User::GetUserInstance()->getUserId()]];
        if(KwTools::Dir::IsExistFile(strpath))   // 已存在用户头像
        {
            UIImage * pimage = [UIImage imageWithContentsOfFile:strpath];
            if(pimage)
                [btnpic setBackgroundImage:pimage forState:UIControlStateNormal];
            return;
        }
        
        NSString * strpic = User::GetUserInstance()->getHeadPic();
        if (!strpic || [strpic isEqualToString:@""])
            return;
        strUserUrl = [strpic UTF8String];
    }

    KS_BLOCK_DECLARE
    {
        if(strUserUrl != "")
        {
            CHttpRequest request(strUserUrl);
            __block NSString * strpath = KwTools::Dir::GetPath(KwTools::Dir::PATH_CASHE);
            strpath = [strpath stringByAppendingPathComponent:@"userpic"];
            if(!KwTools::Dir::IsExistFile(strpath))
                KwTools::Dir::MakeDir(strpath);
            if(m_playType == Play_Online)
                strpath = [strpath stringByAppendingPathComponent:[NSString stringWithFormat:@"%s.jpg",((CPlaySongInfo*)m_pSong)->strUserId.c_str()]];
            else if(m_playType == Play_Local)
                strpath = [strpath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg",User::GetUserInstance()->getUserId()]];
            BOOL bret = request.SyncSendRequest([strpath UTF8String]);
            if(bret)
            {
                KS_BLOCK_DECLARE
                {
                    UIImage * pimage = [UIImage imageWithContentsOfFile:strpath];
                    if(pimage)
                        [btnpic setBackgroundImage:pimage forState:UIControlStateNormal];
                }
                KS_BLOCK_SYNRUN()

            }
        }
        
        
    }
    KS_BLOCK_RUN_THREAD();
}

- (void)dealloc
{
    if (m_pSong) {
        delete m_pSong;
        m_pSong = NULL;
    }
    if (vedioView) {
        [vedioView release];
        vedioView = nil;
    }
    
    if (m_strKid) {
        [m_strKid release];
        m_strKid = nil;
    }
    [super dealloc];
}

- (void)createPlayer:(BOOL)bIsVideo :(BOOL)bLocal
{
    if(m_pPlayer)
        [self releasePlayer];
    if(bLocal)
        m_playType = Play_Local;
    else {
        m_playType = Play_Online;
    }
    if(m_playType == Play_Online)
        m_pPlayer = CMediaModelFactory::GetInstance()->CreateMediaOnlinePlay(bIsVideo);
    else if(m_playType == Play_Local)
        m_pPlayer=CMediaModelFactory::GetInstance()->CreateLocalWorkPlayer(bIsVideo);
    
    GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_AUDIOSTATUS,IAudioStateObserver);
    m_bIsVideo=bIsVideo;
}

- (void)releasePlayer
{
    if (m_pPlayer) {
        m_pPlayer->Stop();
        if(m_playType == Play_Online)
            CMediaModelFactory::GetInstance()->ReleaseMediaOnlinePlayer();
        else if(m_playType == Play_Local)
            CMediaModelFactory::GetInstance()->ReleaseLocalWorkPlayer();
        m_pPlayer=NULL;
    }
}

-(void)IAudioStateObserver_PlayStatusPlaying
{
    [btnpause setHidden:false];
    [btnplay setHidden:true];
    if(picView)
        [picView startPlay];
    [self onRefreshControl];
}

-(void)IAudioStateObserver_PlayStatusPaused
{
    [btnpause setHidden:true];
    [btnplay setHidden:false];
    if(picView)
        [picView stop];
    [self onRefreshControl];
}

-(void)IAudioStateObserver_PlayStatusStop
{
    [btnpause setHidden:true];
    [btnplay setHidden:false];
    if (picView) {
         [picView stop];
    }
    [self onRefreshControl];
}

-(void)IAudioStateObserver_OnlinePlayFinish
{
    [btnpause setHidden:true];
    [btnplay setHidden:false];
    [self onRefreshControl];
}

-(void)IAudioStateObserver_OnlineObjectRelease
{
    [self ClearMedia];
}

#pragma mark -
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint pt = [touch locationInView:self.view];
    int height;
    if(m_bShowFloat)
        height = HEIGHT_TOPPICVIEW - HEIGHT_FLOATVIEW;
    else 
        height = HEIGHT_TOPPICVIEW;
    if(pt.y < height ) // 触摸在上方，浮层消失
    {
        [self UpdateFloatView];
    }

}


@end






