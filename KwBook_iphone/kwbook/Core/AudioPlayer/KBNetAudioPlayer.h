//
//  KBNetAudioPlayer.h
//  kwbook
//
//  Created by 单 永杰 on 13-11-29.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "ChapterInfo.h"

@interface KBNetAudioPlayer : NSObject

- (BOOL) resetPlayer;
- (BOOL) resetPlayer : (CChapterInfo*) song_info atTime : (float)f_cur_time;
- (BOOL) pause;
- (BOOL) resume;
- (BOOL) stop;
- (BOOL) seek : (float) f_seek_sec;

- (float)currentTime;
- (float)duration;
- (float)bufferRatio;

@end
