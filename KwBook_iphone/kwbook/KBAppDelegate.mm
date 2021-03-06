//
//  KBAppDelegate.m
//  kwbook
//
//  Created by 单 永杰 on 13-11-27.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import "KBAppDelegate.h"
#import "MainViewController.h"
#import "CAppInit.h"
#import "MessageManager.h"
#import "ImageMgr.h"
#import <CoreTelephony/CTCall.h>
#import <CoreTelephony/CTCallCenter.h>
#import <MediaPlayer/MPMusicPlayerController.h>
#import "IObserverApp.h"
#import "HttpRequest.h"
#include "MobClick.h"
#include "KuwoConstants.h"

#include "AudioPlayerManager.h"
#include "KwConfig.h"
#include "KwConfigElements.h"
#include "des1.h"
#define KWBOOK_PUSH_SERVER_URL "http://pushserver.kuwo.cn/push.s?f=kwbook&q="

typedef enum{
    TYPE_NEW_BOOK,
    TYPE_UPGRADE
} PushType;

UINavigationController *rootNavigationController;

@interface KBAppDelegate ()<UIAlertViewDelegate>
{
    CTCallCenter* pCallCenter;
    
    PushType _pushType;
}
@end

@implementation KBAppDelegate

+(UINavigationController *)rootNavigationController
{
    return rootNavigationController;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    
    [application setStatusBarHidden:NO];
    
    [MobClick startWithAppkey:UM_APPKEY reportPolicy:SEND_INTERVAL channelId:KWSING_CHANNEL]; //umeng
    [MobClick updateOnlineConfig];
    [MobClick setAppVersion:@KWSING_VERSION_STRING];
    [MobClick setCrashReportEnabled:YES];
    
    CAppInit::GetInstance()->OnLaunchFinished();
    
    MainViewController *mainViewController = [[MainViewController alloc] init];
    rootNavigationController = [[UINavigationController alloc] initWithRootViewController:mainViewController];
    [rootNavigationController setNavigationBarHidden:YES];
    [self.window setRootViewController:rootNavigationController];
    [self.window makeKeyAndVisible];
    
    //侦听 音量键 按动情况
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onVolumeControlChanged:) name:MPMusicPlayerControllerVolumeDidChangeNotification object:nil];
    
    //响应来电
    pCallCenter=[[CTCallCenter alloc] init];
    pCallCenter.callEventHandler=^(CTCall* call){
        if ([call.callState isEqualToString:@"CTCallStateIncoming"]) {
            ASYN_NOTIFY(OBSERVER_ID_APP,IObserverApp::CallInComing,0);
        } else if([call.callState isEqualToString:@"CTCallStateDisconnected"]){
            ASYN_NOTIFY(OBSERVER_ID_APP,IObserverApp::CallDisconnecte,0);
        } else if ([call.callState isEqualToString:@"CTCallStateDialing"]){
            SYN_NOTIFY(OBSERVER_ID_APP,IObserverApp::CallDialing,0);
        }
    };
    
    [application beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    KS_BLOCK_DECLARE{
        [application registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
    }
    KS_BLOCK_ASYNRUN(3000);
    
    if (launchOptions) {
        NSDictionary *pushNotificationDic=[launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        if (pushNotificationDic) {
            int n_badge = application.applicationIconBadgeNumber;
            if (0 < n_badge) {
                application.applicationIconBadgeNumber = --n_badge;
            }
            
            NSString* type=[[pushNotificationDic objectForKey:@"aps"] objectForKey:@"type"];
            _pushType=(PushType)[type intValue];
            
            if (_pushType == TYPE_UPGRADE) {
                UIAlertView *alert=[[UIAlertView alloc] initWithTitle:[[pushNotificationDic objectForKey:@"aps"] objectForKey:@"title"] message:[[pushNotificationDic objectForKey:@"aps"] objectForKey:@"alert"] delegate:self cancelButtonTitle:@"暂不升级" otherButtonTitles:@"立刻升级", nil];
                [alert show];
            }else {
                NSLog(@"New book");
            }
        }
    }
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    CAppInit::GetInstance()->OnResignActive();
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    CAppInit::GetInstance()->OnEnterBackground();
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    CAppInit::GetInstance()->OnEnterForeground();
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    CAppInit::GetInstance()->OnBecomeActive();
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void) onVolumeControlChanged:(NSNotification*)notification{
    ASYN_NOTIFY(OBSERVER_ID_APP, IObserverApp::VolumeControlChanged, 0);
}
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    //NSLog(@"Memory Warning");
    ASYN_NOTIFY(OBSERVER_ID_APP, IObserverApp::MemoryWarning, 0);
}

-(void)remoteControlReceivedWithEvent:(UIEvent *)event{
    if(event.type == UIEventTypeRemoteControl && CPlayBookList::getInstance()->getCurChapter()){
        switch (event.subtype) {
            case UIEventSubtypeRemoteControlTogglePlayPause:{
                if (E_AUDIO_PLAY_PLAYING == CAudioPlayerManager::getInstance()->getCurPlayState()) {
                    CAudioPlayerManager::getInstance()->pause();
                }else if(E_AUDIO_PLAY_PAUSE == CAudioPlayerManager::getInstance()->getCurPlayState()){
                    CAudioPlayerManager::getInstance()->resume();
                }else {
                    CAudioPlayerManager::getInstance()->play();
                }
                break;
            }
            case UIEventSubtypeRemoteControlPlay:{
                if(E_AUDIO_PLAY_PAUSE == CAudioPlayerManager::getInstance()->getCurPlayState()){
                    CAudioPlayerManager::getInstance()->resume();
                }else {
                    CAudioPlayerManager::getInstance()->play();
                }
                break;
            }
            case UIEventSubtypeRemoteControlPause:{
                if (E_AUDIO_PLAY_PLAYING == CAudioPlayerManager::getInstance()->getCurPlayState()) {
                    CAudioPlayerManager::getInstance()->pause();
                }
                break;
            }
            case UIEventSubtypeRemoteControlNextTrack:{
                CAudioPlayerManager::getInstance()->playNextChapter();
                break;
            }
            case UIEventSubtypeRemoteControlPreviousTrack:{
                CAudioPlayerManager::getInstance()->playPreChapter();
                break;
            }
            default:
                break;
        }
    }
}

- (BOOL)canBecomeFirstResponder{
    return YES;
}

#pragma mark apns delegate

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken{
    //    NSLog(@"Device token is : %@", deviceToken);
    
    NSString* str_device_token = [NSString stringWithFormat:@"%@", deviceToken];
    str_device_token = [str_device_token stringByReplacingOccurrencesOfString:@" " withString:@""];
    std::string str_uuid = "";
    KwConfig::GetConfigureInstance()->GetConfigStringValue(DEVICE_INFO, DEVICE_UUID, str_uuid);
    
    NSString* str_temp = [NSString stringWithFormat:@"corp=%s&prod=%s&instsrc=%s&user=%s&devm=&openudid=&uuid=&uid=&type=%s&deviceID=&devicetoken=%@&devicetype=%s&OSVersion=%s&escape=%s&badge=1", KWSING_COMPANY_NAME, KWSING_CLIENT_VERSION_STRING, GetClientInstallSource(), str_uuid.c_str(), "collect_token", [str_device_token substringWithRange:(NSMakeRange(1, [str_device_token length] - 2))], GetDeviceType(), GetDeviceOSVersion(), "0"];
    
    std::string str_out = "";
    if (!encode_msg(str_out, KWSING_ENCRYPT_KEY, [str_temp UTF8String])) {
        return;
    }
    
    str_out = KWBOOK_PUSH_SERVER_URL + str_out;
    
    KS_BLOCK_DECLARE{
        std::string str_http_out = "";
        bool b_ret = CHttpRequest::QuickSyncGet(str_out, str_http_out);
        NSLog(@"%s", str_http_out.c_str());
    }
    KS_BLOCK_RUN_THREAD();
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error{
    //    NSLog(@"fail register push service");
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo{
    //    NSLog(@"Receive remote notification : %@", userInfo);
    if (userInfo) {
        
        int n_badge = application.applicationIconBadgeNumber;
        if (0 < n_badge) {
            application.applicationIconBadgeNumber = --n_badge;
        }
        
        NSString* type=[[userInfo objectForKey:@"aps"] objectForKey:@"type"];
        _pushType=(PushType)[type intValue];
        if (_pushType == TYPE_UPGRADE) {
            UIAlertView *alert=[[UIAlertView alloc] initWithTitle:[[userInfo objectForKey:@"aps"] objectForKey:@"title"] message:[[userInfo objectForKey:@"aps"] objectForKey:@"alert"] delegate:self cancelButtonTitle:@"暂不升级" otherButtonTitles:@"立刻升级", nil];
            [alert show];
        }else {
            NSLog(@"New book");
        }
    }
}

#pragma mark alert view delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    if(buttonIndex == 1){
        if(TYPE_UPGRADE == _pushType)
        {
            NSURL* url=[NSURL URLWithString:@"https://itunes.apple.com/cn/app/id797350587?mt=8"];
            [[UIApplication sharedApplication]openURL:url];
        }
    }
}

@end
