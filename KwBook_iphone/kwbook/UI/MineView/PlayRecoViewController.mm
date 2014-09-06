//
//  PlayRecoViewController.m
//  kwbook
//
//  Created by 熊 改 on 13-12-9.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import "PlayRecoViewController.h"
#import "ImageMgr.h"
#import "globalm.h"
#import "KBBookDetailViewController.h"
#import "RecentBookList.h"
#import "KBAppDelegate.h"
#import "CacheMgr.h"
#import "PlayBookList.h"
#import "MessageManager.h"
#import "IObserverAudioPlayState.h"

#define TAG_IMAGE           41
#define TAG_BOOK_NAME       42
#define TAG_EPISODE         43
#define TAG_TIME            44

#define TAG_CELL_NEED_LOAD          45
#define TAG_CELL_LOAD_DONE          46

@interface PlayRecoViewController ()<UITableViewDataSource,UITableViewDelegate>
@property (nonatomic , strong) UITableView *tableView;
@property (nonatomic , strong) UILabel *tipsLabel;
@end

@implementation PlayRecoViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.tableView = ({
        UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
        [tableView setBackgroundColor:CImageMgr::GetBackGroundColor()];
        [tableView setDelegate:self];
        [tableView setDataSource:self];
        tableView;
    });
    [[self view] addSubview:self.tableView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
-(void)dealloc
{
    GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
}
-(void)setEditing:(BOOL)editing
{
    [super setEditing:editing];
    [self.tableView setEditing:editing animated:YES];
}
-(void)showTips
{
    self.tipsLabel = ({
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 150, 300, 20)];
        [label setTextAlignment:NSTextAlignmentCenter];
        [label setBackgroundColor:[UIColor clearColor]];
        [label setTextColor:[UIColor grayColor]];
        [label setText:@"还没有听过的作品喔"];
        [label setHidden:NO];
        label;
    });
    [[self view] addSubview:self.tipsLabel];
}
-(void)removeTips
{
    if (self.tipsLabel) {
        [self.tipsLabel removeFromSuperview];
        self.tipsLabel = nil;
    }
}
-(unsigned)getMinuteFromMilSecond:(unsigned)milSec
{
    return milSec/60000;
}
-(unsigned)getSecondFromMilSecond:(unsigned)milSec
{
    return (milSec/1000)%60;
}
#pragma mark
#pragma mark load image
-(void)loadImageAnIndex:(NSIndexPath*)indexPath
{
    std::vector<CRecentBookInfo *> vec = CRecentBookList::GetInstance()->GetLocalBookVec();
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (cell) {
        unsigned index = indexPath.row;
        if (index < vec.size()) {
            CBookInfo *info = vec.at(vec.size() - index - 1);
            NSString *strURL = [NSString stringWithFormat:@"%s",info->m_strImgUrl.c_str()];
            
            __block void     *imageData = NULL;
            __block unsigned length = 0;
            __block BOOL     outOfTIme = YES;
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if (CCacheMgr::GetInstance()->Read(info->m_strImgUrl, imageData, length, outOfTIme)) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIImageView *imageView = (UIImageView *)[cell.contentView viewWithTag:TAG_IMAGE];
                        NSData *data = [NSData dataWithBytesNoCopy:imageData length:length freeWhenDone:YES];
                        UIImage *image = [UIImage imageWithData:data];
                        if (image) {
                            [imageView setAlpha:0.0];
                            [UIView animateWithDuration:0.5 animations:^{
                                [imageView setImage:image];
                                [imageView setAlpha:1.0];
                            } completion:^(BOOL finished) {
                                [cell setTag:TAG_CELL_LOAD_DONE];
                            } ];
                        }
                    });
                }
                else{
                    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:strURL]];
                    UIImage *image = [UIImage imageWithData:data];
                    if (image) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            UIImageView *imageView = (UIImageView *)[cell.contentView viewWithTag:TAG_IMAGE];
                            [imageView setAlpha:0.0];
                            [UIView animateWithDuration:0.5 animations:^{
                                [imageView setImage:image];
                                [imageView setAlpha:1.0];
                            } completion:^(BOOL finished) {
                                [cell setTag:TAG_CELL_LOAD_DONE];
                            } ];
                        });
                    }
                }
            });
        }
    }
}
#pragma mark
#pragma mark table view data source
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    std::vector<CRecentBookInfo *> vec = CRecentBookList::GetInstance()->GetLocalBookVec();
    if (vec.size() == 0) {
        [self showTips];
    }
    else{
        [self removeTips];
    }
    return vec.size();
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *playRecoCellIdentifier = [NSString stringWithFormat:@"playRecoCellIdentifier%d",indexPath.row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:playRecoCellIdentifier];
    
    if (cell == nil || cell.tag != TAG_CELL_LOAD_DONE) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:playRecoCellIdentifier];
        cell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
        cell.backgroundView.backgroundColor = CImageMgr::GetBackGroundColor();
        [cell setSelectionStyle:UITableViewCellSelectionStyleGray];
        [cell.contentView setBackgroundColor:CImageMgr::GetBackGroundColor()];
        if (isIOS7()) {
            [cell setSeparatorInset:UIEdgeInsetsZero];
        }
        UIImageView *bookBack = [[UIImageView alloc] initWithFrame:CGRectMake(2.5, 2.5, 69, 69)];
        [bookBack setImage:CImageMgr::GetImageEx("BookPicBack.png")];
        [cell.contentView addSubview:bookBack];
        
        UIImageView *headPic = [[UIImageView alloc] initWithFrame:CGRectMake(7, 7, 60, 60)];
        [headPic setImage:CImageMgr::GetImageEx("DefaultBookImageSmall.png")];
        [headPic setTag:TAG_IMAGE];
        [cell.contentView addSubview:headPic];
        
        UILabel *bookNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(77, 18, 223, 17)];
        [bookNameLabel setTag:TAG_BOOK_NAME];
        [bookNameLabel setTextColor:defaultBlackColor()];
        [bookNameLabel setBackgroundColor:[UIColor clearColor]];
        [bookNameLabel setFont:[UIFont systemFontOfSize:16.0]];
        [cell.contentView addSubview:bookNameLabel];
        
        UILabel *episodeLabel = [[UILabel alloc] initWithFrame:CGRectMake(77, 51, 80, 11)];
        [episodeLabel setTag:TAG_EPISODE];
        [episodeLabel setTextColor:defaultGrayColor()];
        [episodeLabel setBackgroundColor:[UIColor clearColor]];
        [episodeLabel setFont:[UIFont systemFontOfSize:10.0]];
        [cell.contentView addSubview:episodeLabel];
        
        UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(169, 51, 55, 11)];
        [timeLabel setTag:TAG_TIME];
        [timeLabel setTextColor:defaultGrayColor()];
        [timeLabel setBackgroundColor:[UIColor clearColor]];
        [timeLabel setFont:[UIFont systemFontOfSize:10.0]];
        [cell.contentView addSubview:timeLabel];
        
        UIImageView *accessaryView = [[UIImageView alloc] initWithImage:CImageMgr::GetImageEx("cellIndicator.png")];
        [accessaryView setCenter:CGPointMake(300, 37.0)];
        [cell.contentView addSubview:accessaryView];
        
        [cell setTag:TAG_CELL_NEED_LOAD];
        [self performSelector:@selector(loadImageAnIndex:) withObject:indexPath afterDelay:1.0];
    }
    
    std::vector<CRecentBookInfo *> vec = CRecentBookList::GetInstance()->GetLocalBookVec();
    int index = indexPath.row;
    if (index < vec.size()) {
        CRecentBookInfo *bookInfo = vec.at(vec.size() - index -1);
        UILabel *bookNameLabel = (UILabel *)[cell.contentView viewWithTag:TAG_BOOK_NAME];
        [bookNameLabel setText:[NSString stringWithUTF8String:bookInfo->m_strBookTitle.c_str()]];
        
        UILabel *artistLabel = (UILabel *)[cell.contentView viewWithTag:TAG_EPISODE];
        [artistLabel setText:[NSString stringWithFormat:@"播放到第%d集",bookInfo->m_unIndex+1]];
        
        unsigned minute =[self getMinuteFromMilSecond:bookInfo->m_unPosMilSec];
        unsigned second = [self getSecondFromMilSecond:bookInfo->m_unPosMilSec];
        
        UILabel *musicCountLabel = (UILabel *)[cell.contentView viewWithTag:TAG_TIME];
        [musicCountLabel setText:[NSString stringWithFormat:@"%02d:%02d",minute,second]];
    }
    return cell;
}
#pragma mark
#pragma mark table view delegate
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 74.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    std::vector<CRecentBookInfo *> vec = CRecentBookList::GetInstance()->GetLocalBookVec();
    int index = indexPath.row;
    if (index < vec.size()) {
        CRecentBookInfo *bookInfo = vec.at(vec.size() - index -1);
        KBBookDetailViewController* book_detail = [[KBBookDetailViewController alloc] initWithBookInfo:bookInfo];
        [book_detail setPlaySource:E_SOURCE_HISTORY];
        [ROOT_NAVI_CONTROLLER pushAddButtonViewController:book_detail animated:YES];
    }
}
-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        std::vector<CRecentBookInfo *> vec = CRecentBookList::GetInstance()->GetLocalBookVec();
        int index = indexPath.row;
        CRecentBookInfo *bookInfo = vec.at(vec.size() - index -1);
        CRecentBookList::GetInstance()->DeleteBookInfo([[NSString stringWithFormat:@"%s",bookInfo->m_strBookId.c_str()] intValue]);
        [self refreshAllCellToReloadImage];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
        
    }
}
- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"删除";
}
#pragma mark
#pragma mark play status observer
-(void)IObserverPlaylistStatusChanged
{
    std::string bookId =  CPlayBookList::getInstance()->getCurChapter()->m_strBookId;
    CRecentBookInfo *bookInfo = CRecentBookList::GetInstance()->GetCurBook([[NSString stringWithFormat:@"%s",bookId.c_str()] intValue]);
    if (bookInfo) {
        //NSLog(@"recent change time:%u",bookInfo->m_unPosMilSec);
        [self.tableView reloadData];
    }
}
-(void)IObserverRecentListChanged:(int)nBookId
{
    [self refreshAllCellToReloadImage];
    [self.tableView reloadData];
}
-(void)refreshAllCellToReloadImage
{
    int row = [self.tableView numberOfRowsInSection:0];
    for (int i = 0; i<row; i++) {
        NSString *cellIdentifier = [NSString stringWithFormat:@"playRecoCellIdentifier%d",i];
        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        [cell setTag:TAG_CELL_NEED_LOAD];
    }
    
    NSArray *cellVisble = [self.tableView visibleCells];
    for (UITableViewCell *cell in cellVisble) {
        [cell setTag:TAG_CELL_NEED_LOAD];
    }
}
@end
