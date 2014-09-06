//
//  HotRecoViewController.m
//  kwbook
//
//  Created by 熊 改 on 13-11-29.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import "HotRecoViewController.h"
#import "KBUrls.h"
#import "CacheMgr.h"
#import "HttpRequest.h"
#import "SBJson4.h"
#import "RecoCellDataItem.h"
#import "RecoCellBtnItem.h"
#import "iToast.h"
#import "ImageMgr.h"
#import "KBRefreshHeadView.h"
#import "KBRefreshFootView.h"
#import "globalm.h"

#define RECO_HOT_JSONDATA_CACHE_KEY    "RecoHotJsonDataCacheKey"
#define RECO_HOT_CELL_IDENTIFIER       @"RecoHotCellIdentifier"

#define TAG_LEFT_ITEM                21
#define TAG_CENTER_ITEM              22
#define TAG_RIGHT_ITEM               23

#define TAG_CELL_LOAD_DONE           31
#define TAG_CELL_NEED_LOAD           32

const int kNumOfBooksInOnePage  = 30;

typedef enum
{
    TABLE_FIRST_LOAD,
    TABLE_REFRESH,
    TABLE_LOAD_MORE,
    TABLE_LOAD_FINISH,
    
}TABLE_STATE;

@interface HotRecoViewController ()<UITableViewDataSource,UITableViewDelegate,KBRefreshBaseViewDelegate>
{
    TABLE_STATE        _state;
    
    KBRefreshHeadView *_headView;
    KBRefreshFootView *_footView;

    int _currentPage;
    int _totalBooks;
    CGFloat _lastOffset;
    
    BOOL _isScrolling;
}
@property (nonatomic , strong) UITableView *tableView;
@property (nonatomic , strong) NSMutableArray *tmpArray;
@property (nonatomic , strong) NSMutableArray *dataArray;
@property (nonatomic , strong) NSDictionary *attributeArray;
@property (nonatomic , strong) NSString *sig;

-(void)tableViewNeedChange;
//表格数据的改变都是经过下面三步
-(NSData *)fetchJsonData;
-(BOOL)parserJsonData:(NSData *)jsonData;
-(void)reloadViewWithRes:(BOOL)res;

-(void)onRefresh:(id)sender;
-(void)refreshAllCellToReload;
-(void)startLoadImageAt:(NSIndexPath *)indexPath;
@end

@implementation HotRecoViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _tmpArray=[NSMutableArray array];
        _dataArray= [NSMutableArray array];
        _attributeArray  = @{@"id": @"bookId",
                             @"musiccnt":@"musicCount",
                             @"name":@"bookName",
                             @"pic":@"imageURL",
                             @"listencnt":@"listenCount",
                             @"type":@"type",
                             @"desc":@"desc",
                             @"artist":@"artistName"};
        _currentPage = 0;
        _totalBooks = 0;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [[self view] setBackgroundColor:CImageMgr::GetBackGroundColor()];
    self.tableView = ({
        UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
        [tableView setBackgroundColor:[UIColor clearColor]];
        //        [tableView setShowsHorizontalScrollIndicator:NO];
        //        [tableView setShowsVerticalScrollIndicator:NO];
        [tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
        [tableView setDelegate:self];
        [tableView setDataSource:self];
        tableView;
    });
    [self setTipsRect:self.tableView.frame];
    [[self view] addSubview:self.tableView];
    
    _headView = [KBRefreshHeadView header];
    [_headView setScrollView:self.tableView];
    [_headView setDelegate:self];
    
    _footView = [KBRefreshFootView footer];
    [_footView setScrollView:self.tableView];
    [_footView setDelegate:self];
    
    _state = TABLE_FIRST_LOAD;
    [self tableViewNeedChange];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
-(void)tableViewNeedChange
{
    [self showLoadingPage:YES descript:nil];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *jsonData = [self fetchJsonData];
        BOOL res = [self parserJsonData:jsonData];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reloadViewWithRes:res];
            [self showLoadingPage:NO descript:nil];
        });
    });
}
#pragma mark
#pragma mark load and parser data
-(NSData *)fetchJsonData
{
    BOOL useCache = NO;
    if (TABLE_FIRST_LOAD == _state) {
        useCache = YES; //只有第一次load用cache
    }
    if (TABLE_FIRST_LOAD == _state || TABLE_REFRESH == _state) {
        _currentPage = 1;
    }
    else if(TABLE_LOAD_MORE == _state){
        _currentPage++;
    }
    __block void* jsonData = NULL;
    __block unsigned length = 0;
    BOOL outOfTime;
    if (useCache && CCacheMgr::GetInstance()->Read(RECO_HOT_JSONDATA_CACHE_KEY, jsonData, length, outOfTime)) {
        NSData *data=[NSData dataWithBytesNoCopy:jsonData length:length freeWhenDone:YES];
        return data;
    }
    else if(NETSTATUS_NONE != CHttpRequest::GetNetWorkStatus()){
        NSString *strUrl = [NSString stringWithFormat:@"%@stype=json&srcver=storynew&type=story_list&id=1&pn=%d&ps=%d&sig=%@",
                            BASE_URL,_currentPage,kNumOfBooksInOnePage,self.sig];
        CHttpRequest::QuickSyncGet([strUrl UTF8String],jsonData,length);
        NSData* data=[NSData dataWithBytesNoCopy:jsonData length:length freeWhenDone:YES];
        if (_currentPage == 1) {
            CCacheMgr::GetInstance()->Cache(T_DAY, 1, RECO_HOT_JSONDATA_CACHE_KEY, jsonData, length);
        }
        return data;
    }
    return nil;
}
-(BOOL)parserJsonData:(NSData *)jsonData;
{
    if (jsonData == nil || [jsonData length]==0) {
        if (_state == TABLE_LOAD_MORE) {
            _currentPage--;//数据获取失败page--
        }
        return NO;
    }
    if (TABLE_FIRST_LOAD == _state || TABLE_REFRESH == _state) {
        [self.tmpArray removeAllObjects];
    }
    SBJson4ValueBlock block = ^(id item, BOOL *stop){
        NSDictionary *dic = item;
        
        NSString *sig =  [dic objectForKey:@"sig"];
        self.sig = sig;
        
        NSString *totalCount = [dic objectForKey:@"totalcount"];
        _totalBooks = [totalCount integerValue];
        
        NSArray *array = [dic objectForKey:@"album_list"];
        if (array.count == 0) {
            if (_state == TABLE_LOAD_MORE) {
                _currentPage--; //没有获取到新的数据page--
            }
        }
        for (NSDictionary *itemDic in array) {
            RecoCellDataItem *item = [[RecoCellDataItem alloc] init];
            [item setRecoType:RECO_HOT];
            for (NSString *key in [self.attributeArray allKeys]) {
                NSString *value = [itemDic objectForKey:key];
                [item setValue:value forKey:[self.attributeArray objectForKey:key]];
            }
            [self.tmpArray addObject:item];
        }
    };
    SBJson4ErrorBlock eh = ^(NSError *error){
        NSLog(@"parser json error:%@",error);
    };
    SBJson4Parser *parser = [SBJson4Parser parserWithBlock:block allowMultiRoot:NO unwrapRootArray:NO errorHandler:eh];
    [parser parse:jsonData];
    return YES;
}

-(void)reloadViewWithRes:(BOOL)res
{
    if (TABLE_REFRESH == _state || TABLE_LOAD_MORE == _state) {
        [self performSelector:@selector(endRefresh) withObject:nil afterDelay:1.0];
    }
    if (!res || self.tmpArray.count == 0) {
        [iToast defaultShow:@"获取数据失败，请稍后再试!"];
        if (self.dataArray.count == 0) {
            if (NETSTATUS_NONE == CHttpRequest::GetNetWorkStatus())
                [self showNoNetWorkPage];
            else{
                [self showLoadFailPage];
            }
        }
        return;
    }
    [self removeLoadFailPage];
    [self removeNoNetPage];

    self.dataArray = self.tmpArray;
    if (self.dataArray.count >= _totalBooks) {
        [_footView setHidden:YES];
    }
    else{
        [_footView setHidden:NO];
    }
    
    [self.tableView reloadData];
    _state = TABLE_LOAD_FINISH;
}
-(void)onTap
{
    if(NETSTATUS_NONE == CHttpRequest::GetNetWorkStatus()){
        [iToast defaultShow:@"网络似乎断开了，请检查连接"];
        return;
    }
    [self tableViewNeedChange];
}
#pragma mark
#pragma mark table view async load image

-(void)startLoadImageAt:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (cell) {
        RecoCellBtnItem *leftItem =  (RecoCellBtnItem *)[cell.contentView viewWithTag:TAG_LEFT_ITEM];
        RecoCellBtnItem *centerItem = (RecoCellBtnItem *)[cell.contentView viewWithTag:TAG_CENTER_ITEM];
        RecoCellBtnItem *rightItem = (RecoCellBtnItem *)[cell.contentView viewWithTag:TAG_RIGHT_ITEM];
        
        [leftItem startLoadImage];
        [centerItem startLoadImage];
        [rightItem startLoadImage];
        
        [cell setTag:TAG_CELL_LOAD_DONE];
    }
}
#pragma mark
#pragma mark on refresh

-(void)onRefresh:(id)sender
{
    [self refreshAllCellToReload];
    _state = TABLE_REFRESH;
    [self tableViewNeedChange];
}
-(void)refreshAllCellToReload
{
    int row = [self.tableView numberOfRowsInSection:0];
    for (int i = 0; i<row; i++) {
        NSString *cellIdentifier = [NSString stringWithFormat:@"%@%d",RECO_HOT_CELL_IDENTIFIER,i];
        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        [cell setTag:TAG_CELL_NEED_LOAD];
    }
    NSArray *cellVisble = [self.tableView visibleCells];
    for (UITableViewCell *cell in cellVisble) {
        [cell setTag:TAG_CELL_NEED_LOAD];
    }
}
#pragma mark
#pragma mark on load more
-(void)onLoadMore
{
    _state = TABLE_LOAD_MORE;
    [self tableViewNeedChange];
}

#pragma mark
#pragma mark head and foot delegate
- (void)refreshViewBeginRefreshing:(KBRefreshBaseView *)refreshView
{
    if (refreshView == _headView) {
        [self onRefresh:refreshView];
    }
    else if (refreshView == _footView){
        [self onLoadMore];
    }
}
-(void)endRefresh
{
    [_headView endRefreshing];
    [_footView endRefreshing];
}
#pragma mark
#pragma mark table view data source
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.dataArray.count/3;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *newCellIdentifier = [NSString stringWithFormat:@"%@%d",RECO_HOT_CELL_IDENTIFIER,indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:newCellIdentifier];
    if (cell == nil || cell.tag != TAG_CELL_LOAD_DONE) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:newCellIdentifier];
        [cell.contentView setBackgroundColor:CImageMgr::GetBackGroundColor()];
        int beginIndex = indexPath.row *3;
        if (beginIndex + 2 < self.dataArray.count){
            RecoCellBtnItem *leftItem = [[RecoCellBtnItem alloc] initWithFrame:CGRectMake(2.5, 0, 105, 152)
                                                                  andAlbumInfo:self.dataArray[beginIndex]];
            RecoCellBtnItem *centerItem = [[RecoCellBtnItem alloc] initWithFrame:CGRectMake(107.5, 0, 105, 152)
                                                                    andAlbumInfo:self.dataArray[beginIndex +1]];
            RecoCellBtnItem *rightItem = [[RecoCellBtnItem alloc] initWithFrame:CGRectMake(212.5, 0, 105, 152)
                                                                   andAlbumInfo:self.dataArray[beginIndex+2]];
            
            [leftItem setTag:TAG_LEFT_ITEM];
            [centerItem setTag:TAG_CENTER_ITEM];
            [rightItem setTag:TAG_RIGHT_ITEM];
            
            [cell.contentView addSubview:leftItem];
            [cell.contentView addSubview:centerItem];
            [cell.contentView addSubview:rightItem];
            
            [self performSelector:@selector(startLoadImageAt:) withObject:indexPath afterDelay:0.5];
        }
    }
    return cell;
}
#pragma mark
#pragma mark table view delegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 152.0;
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
//    [self.rootViewController.contentViewController setKSongButtonHidden:YES];
//}
-(void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    CGFloat thisOffset = scrollView.contentOffset.y;
    
    if (thisOffset > _lastOffset) {
        [self.footDelegate hideFoot];
    }
    else{
        [self.footDelegate showFoot];
    }
    
    _lastOffset = thisOffset;
    _isScrolling = NO;
}
 */
@end