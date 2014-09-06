//
//  KBBookDetailViewController.h
//  kwbook
//
//  Created by 单 永杰 on 13-12-9.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import "KBViewController.h"
#include "BookInfo.h"
#include "PlaySourceType.h"

@interface KBBookDetailViewController : KBViewController

-(id)initWithBookInfo : (CBookInfo*)book_info;

-(void)setPlaySource : (PLAY_SOURCE_TYPE)e_soure_type;

-(std::string)theBookId;

@end