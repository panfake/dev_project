//
//  MineViewController.m
//  kwbook
//
//  Created by 熊 改 on 13-11-28.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import "MineViewController.h"
#import "globalm.h"
#import "ImageMgr.h"
#import "KBSegmentControl.h"
#import "PlayRecoViewController.h"
#import "MyCollectionViewController.h"
#import "SettingViewController.h"
#import "RecentBookList.h"
#import "CollectBookList.h"
#import "IObserverAudioPlayState.h"
#import "MessageManager.h"


@interface MineViewController ()<UIScrollViewDelegate>
{
    NSInteger  _selectIndex;
}
@property (nonatomic , strong) UIView                   *topBar;
@property (nonatomic , strong) NSArray                  *arrayBtns;
@property (nonatomic , strong) UIScrollView             *contentView;
@property (nonatomic , strong) NSArray                  *subVC;
@property (nonatomic , strong) UIImageView              *indicatorView;
@property (nonatomic , strong) UIButton                 *editBtn;
-(void)onTopButtonClick:(id)sender;
@end

@implementation MineViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _selectIndex = -1;
        GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    float gap = 0.0;
    if (isIOS7()) {
        gap = 20;
    }
    float width  = self.view.bounds.size.width;
    float height = self.view.bounds.size.height;
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
        
        self.editBtn = ({
            UIButton *editBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            [editBtn setFrame:CGRectMake(270, gap, 44, 44)];
            [editBtn setTitle:@"编辑" forState:UIControlStateNormal];
            [editBtn setTitle:@"完成" forState:UIControlStateSelected];
            [editBtn addTarget:self action:@selector(onEditBtnClick:) forControlEvents:UIControlEventTouchUpInside];
            editBtn;
        });
        [topBar addSubview:self.editBtn];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, gap, 180, 44)];
        [titleLabel setText:@"我的"];
        [titleLabel setTextAlignment:NSTextAlignmentCenter];
        [titleLabel setTextColor:[UIColor whiteColor]];
        [titleLabel setBackgroundColor:[UIColor clearColor]];
        [titleLabel setFont:[UIFont systemFontOfSize:20.0]];
        [topBar addSubview:titleLabel];
        topBar;
    });
    [[self view] addSubview:self.topBar];
    
    UIImageView *topBack = [[UIImageView alloc] initWithImage:CImageMgr::GetImageEx("MineTopBack.png")];
    [topBack setFrame:CGRectMake(0, gap + 44, 320, 44)];
    [[self view] addSubview:topBack];
    
    float btnWidth = 106;
    float btnHeight = 44;
    
    UIButton *btnPlayReco = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnPlayReco setFrame:CGRectMake(1, gap + 44, btnWidth, btnHeight)];
    [btnPlayReco setTitle:@"播放记录" forState:UIControlStateNormal];
    [btnPlayReco.titleLabel setFont:[UIFont systemFontOfSize:14.0]];
    [btnPlayReco setTitleEdgeInsets:UIEdgeInsetsMake(0, 20, 0, 0)];
    [btnPlayReco setTitleColor:UIColorFromRGBValue(0x5e5e5e) forState:UIControlStateNormal];
    [btnPlayReco setTitleColor:UIColorFromRGBValue(0x028bd0) forState:UIControlStateSelected];
    [btnPlayReco setBackgroundImage:CImageMgr::GetImageEx("PlayRecoNormal.png") forState:UIControlStateNormal];
    [btnPlayReco setBackgroundImage:CImageMgr::GetImageEx("PlayRecoDown.png") forState:UIControlStateDisabled];
    [btnPlayReco addTarget:self action:@selector(onTopButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *btnCollect = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnCollect setFrame:CGRectMake(1+btnWidth, gap + 44, btnWidth, btnHeight)];
    [btnCollect setTitle:@"我的收藏" forState:UIControlStateNormal];
    [btnCollect.titleLabel setFont:[UIFont systemFontOfSize:14.0]];
    [btnCollect setTitleEdgeInsets:UIEdgeInsetsMake(0, 20, 0, 0)];
    [btnCollect setTitleColor:UIColorFromRGBValue(0x5e5e5e) forState:UIControlStateNormal];
    [btnCollect setTitleColor:UIColorFromRGBValue(0x028bd0) forState:UIControlStateSelected];
    [btnCollect setBackgroundImage:CImageMgr::GetImageEx("MineCollectionNormal.png") forState:UIControlStateNormal];
    [btnCollect setBackgroundImage:CImageMgr::GetImageEx("MineCollectionDown.png") forState:UIControlStateDisabled];
    [btnCollect addTarget:self action:@selector(onTopButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *btnSetting = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnSetting setFrame:CGRectMake(1+2*btnWidth, gap + 44, btnWidth, btnHeight)];
    [btnSetting setTitle:@"设置" forState:UIControlStateNormal];
    [btnSetting.titleLabel setFont:[UIFont systemFontOfSize:14.0]];
    [btnSetting setTitleEdgeInsets:UIEdgeInsetsMake(0, 5, 0, 0)];
    [btnSetting setTitleColor:UIColorFromRGBValue(0x5e5e5e) forState:UIControlStateNormal];
    [btnSetting setTitleColor:UIColorFromRGBValue(0x028bd0) forState:UIControlStateSelected];
    [btnSetting setBackgroundImage:CImageMgr::GetImageEx("MineSettingNormal.png") forState:UIControlStateNormal];
    [btnSetting setBackgroundImage:CImageMgr::GetImageEx("MineSettingDown.png") forState:UIControlStateDisabled];
    [btnSetting addTarget:self action:@selector(onTopButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [[self view] addSubview:btnPlayReco];
    [[self view] addSubview:btnCollect];
    [[self view] addSubview:btnSetting];
    
    self.arrayBtns = @[btnPlayReco,btnCollect,btnSetting];
    [self onTopButtonClick:btnPlayReco];
    
    self.indicatorView = ({
        UIImageView *indicatorView = [[UIImageView alloc] initWithImage:CImageMgr::GetImageEx("BookDetailClick.png")];
        [indicatorView setFrame:CGRectMake(50, 84+gap, 14, 4)];
        indicatorView;
    });
    [[self view] addSubview:self.indicatorView];
    
    self.contentView = ({
        UIScrollView *contentView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, gap + 88, width, height-gap-88)];
        [contentView setContentSize:CGSizeMake(width * 3, height - gap - 88)];
        [contentView setDelegate:self];
        [contentView setPagingEnabled:YES];
        [contentView setShowsHorizontalScrollIndicator:NO];
        [contentView setShowsVerticalScrollIndicator:NO];
        contentView;
    });
    [[self view] addSubview:self.contentView];
    
    [self addSubViewControllers];
}
-(void)dealloc
{
    GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
}
-(void)addSubViewControllers
{
    float width  = self.view.bounds.size.width;
    
    CGRect subRect = self.contentView.bounds;
    PlayRecoViewController *playRecoVc = [[PlayRecoViewController alloc] initWithFrame:subRect];
    subRect.origin.x += width;
    MyCollectionViewController *myCollectionRecoVc = [[MyCollectionViewController alloc] initWithFrame:subRect];
    subRect.origin.x += width;
    SettingViewController *settingRecoVc = [[SettingViewController alloc] initWithFrame:subRect];
    self.subVC = @[playRecoVc,myCollectionRecoVc,settingRecoVc];
    
    for (KBViewController *viewController in self.subVC) {
        [self addChildViewController:viewController];
        [self.contentView addSubview:viewController.view];
        [viewController didMoveToParentViewController:self];
    }
}
-(void)onEditBtnClick:(id)sender
{
    UIButton *editBtn = (UIButton *)sender;
    editBtn.selected = !editBtn.selected;
    [self.subVC[_selectIndex] setEditing:editBtn.isSelected];
}
-(void)updateEditBtn
{
    [self.editBtn setHidden:(_selectIndex == 2)];
    if (!self.editBtn.isHidden) {
        [self.editBtn setSelected:[(UIViewController *)self.subVC[_selectIndex] isEditing]];
        if (_selectIndex == 0) {
            std::vector<CRecentBookInfo *> vec = CRecentBookList::GetInstance()->GetLocalBookVec();
            [self.editBtn setEnabled:!(vec.size() == 0)];
            
        }
        else if(_selectIndex == 1){
            std::vector<CCollectBookInfo *> vec = CCollectBookList::GetInstance()->GetLocalBookVec();
            [self.editBtn setEnabled:!(vec.size() == 0)];
        }
    }

}
-(void)onTopButtonClick:(id)sender
{
    UIButton *btn = (UIButton *)sender;
    [btn setEnabled:NO];
    
    for (int i = 0; i<self.arrayBtns.count; ++i) {
        if (btn == self.arrayBtns[i]) {
            _selectIndex = i;
        }
        else{
            [self.arrayBtns[i] setEnabled:YES];
        }
    }
    
    [self updateEditBtn];
    
    CGRect endRect  = self.indicatorView.frame;
    endRect.origin.x = 50 + _selectIndex * 106;
    [UIView animateWithDuration:0.25 animations:^{
        [self.indicatorView setFrame:endRect];
    }];
    [self.contentView setContentOffset:CGPointMake(320 * _selectIndex, 0 ) animated:YES];
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    float width  = self.view.bounds.size.width;
    int index = scrollView.contentOffset.x / width;
    for (int i = 0; i<self.arrayBtns.count; ++i) {
        if (i == index) {
            [(UIButton *)self.arrayBtns[i] setEnabled:NO];
            _selectIndex = i;
        }
        else{
            [(UIButton *)self.arrayBtns[i] setEnabled:YES];
        }
    }
    
    [self updateEditBtn];
    
    CGRect endRect  = self.indicatorView.frame;
    endRect.origin.x = 50 + _selectIndex * 106;
    [UIView animateWithDuration:0.25 animations:^{
        [self.indicatorView setFrame:endRect];
    }];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
-(void)IObserverRecentListChanged:(int)nBookId
{
    [self updateEditBtn];
}
-(void)IObserverCollectListChanged:(int)nBookId
{
    [self updateEditBtn];
}
@end
