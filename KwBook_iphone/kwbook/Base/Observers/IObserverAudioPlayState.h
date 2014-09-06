//
//  IObserverAudioPlayState.h
//  kwbook
//
//  Created by 单 永杰 on 13-12-3.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#ifndef kwbook_IObserverAudioPlayState_h
#define kwbook_IObserverAudioPlayState_h

#include "IMessageObserver.h"

enum AudioPlayState
{
    E_AUDIO_PLAY_NONE,
    E_AUDIO_PLAY_BUFFERING,
    E_AUDIO_PLAY_PLAYING,
    E_AUDIO_PLAY_PAUSE,
    E_AUDIO_PLAY_STOP,
    E_AUDIO_PLAY_FINISH,
    E_AUDIO_BOOK_CHANGE
};

@protocol IObserverAudioPlayState <NSObject>
@optional
-(void)IObserverAudioPlayStateChanged:(AudioPlayState)enumStatus;
-(void)IObserverPlaylistStatusChanged;
-(void)IObserverRecentListChanged:(int)nBookId;
-(void)IObserverCollectListChanged:(int)nBookId;
-(void)IObserverTimmingLeft:(int)nMinLeft;
-(void)IObserverChapterLeft:(int)nChapterLeft;
@end

class IObserverAudioPlayState:public IMessageObserver
{
public:
    //网络状态切换
    virtual void IObserverAudioPlayStateChanged(AudioPlayState enumStatus){}
    virtual void IObserverPlaylistStatusChanged(){}
    virtual void IObserverRecentListChanged(int nBookId){}
    virtual void IObserverCollectListChanged(int nBookId){}
    virtual void IObserverTimmingLeft(int nMinLeft){}
    virtual void IObserverChapterLeft(int nChapterLeft){}
    
    enum eumMethod
    {
        AudioPlayStatusChanged,
        AudioPlaylistStatusChanged,
        RecentListChanged,
        CollectListChanged,
        TimmingLeft,
        ChapterLeft
    };
    
    MESSAGE_OBSERVER_NOTIFY_BEGIN(IObserverAudioPlayState)

    NOTIFY_CASE_ITEM(AudioPlayStatusChanged,IObserverAudioPlayStateChanged,_1PARA);
    NOTIFY_CASE_ITEM(AudioPlaylistStatusChanged,IObserverPlaylistStatusChanged,_0PARA);
    NOTIFY_CASE_ITEM(RecentListChanged,IObserverRecentListChanged,_1PARA);
    NOTIFY_CASE_ITEM(CollectListChanged,IObserverCollectListChanged,_1PARA);
    NOTIFY_CASE_ITEM(TimmingLeft,IObserverTimmingLeft,_1PARA);
    NOTIFY_CASE_ITEM(ChapterLeft,IObserverChapterLeft,_1PARA);

    MESSAGE_OBSERVER_NOTIFY_END();
};

#endif