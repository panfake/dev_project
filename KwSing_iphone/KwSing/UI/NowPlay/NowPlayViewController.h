//
//  NowPlayViewController.h
//  KwSing
//
//  Created by Qian Hu on 12-8-14.
//  Copyright (c) 2012年 酷我音乐. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "SongInfo.h"

@interface NowPlayViewController : UIViewController

- (void)setSongInfo:(CRecoSongInfo*)songinfo;
- (void)setKid:(NSString*)strKid;
- (void)setPlayType:(bool)bLocal;
- (void)stopPlay;
@end
