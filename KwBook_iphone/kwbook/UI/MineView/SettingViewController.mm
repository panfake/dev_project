//
//  SettingViewController.m
//  kwbook
//
//  Created by 熊 改 on 13-12-4.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#import "SettingViewController.h"
#import "globalm.h"
#import "ImageMgr.h"
#import "UMFeedback.h"
#import "KBAppDelegate.h"
#import "KuwoConstants.h"
#import "AboutViewController.h"
#import "iToast.h"
#import "LocalBookRequest.h"
#import "BookManagement.h"
#import "KBSetTimming.h"
#import "AudioPlayerManager.h"
#import "IObserverAudioPlayState.h"
#import "MessageManager.h"
#include "KwConfig.h"
#include "KwConfigElements.h"
#include "IObserverFlowProtect.h"

#define kTimeCell       @"TimeCell"
#define kEpisodeCell    @"EpisodeCell"

#define kTimePickerTag      61
#define kEpisodePickerTag   62
#define kSwitchViewTag      63

const CGFloat pickerCellHeight = 180;

@interface SettingViewController ()<UITableViewDataSource,UITableViewDelegate,UIPickerViewDataSource,UIPickerViewDelegate,IObserverAudioPlayState, IObserverFlowProtect>
{
    NSInteger  _theSelectTimeIndex;
    NSInteger  _theSelectEpisodeIndex;
}
@property (nonatomic , strong) UIView           *topBar;
@property (nonatomic , strong) UITableView      *tableView;
@property (nonatomic , strong) UIPickerView     *timePicker;
@property (nonatomic , strong) UIPickerView     *episodePicker;
@property (nonatomic , strong) UITableViewCell  *flowProtectCell;
@property (nonatomic , strong) UITableViewCell  *showTimeCell;              //显示的cell
@property (nonatomic , strong) UITableViewCell  *showEpisodeCell;
@property (nonatomic , strong) UITableViewCell  *timeCell;                  //包含picker的cell
@property (nonatomic , strong) UITableViewCell  *episodeCell;
@property (nonatomic , strong) NSIndexPath      *pickerCellIndexPath;       //如果有inline的picker该项指向picker所在的位置
@property (nonatomic , strong) NSArray          *timeData;
@property (nonatomic , strong) NSArray          *timeDataText;
@property (nonatomic , strong) NSArray          *timeDataCellText;
@property (nonatomic , strong) NSArray          *episodeData;
@property (nonatomic , strong) NSArray          *episodeDataText;
@property (nonatomic , strong) NSArray          *episodeDataCellText;
@property (nonatomic , strong) NSArray          *sectionOneData;
@property (nonatomic , strong) UIToolbar        *toolBar;

@end

@implementation SettingViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _timeData = @[@0,@10,@20,@30,@40,@50,@60,@90,@120];
        _timeDataText = @[@"未定时",@"10分钟",@"20分钟",@"30分钟",@"40分钟",@"50分钟",@"60分钟",@"90分钟",@"120分钟"];
        _timeDataCellText = @[@"未定时",@"10分钟后停止播放",@"20分钟后停止播放",@"30分钟后停止播放",@"40分钟后停止播放",@"50分钟后停止播放",@"60分钟后停止播放",@"90分钟后停止播放",@"120分钟后停止播放"];
        _episodeData = @[@0,@1,@2,@3,@4,@5,@6,@7,@8,@9,@10];
        _episodeDataText = @[@"未定时",@"1集",@"2集",@"3集",@"4集",@"5集",@"6集",@"7集",@"8集",@"9集",@"10集"];
        _episodeDataCellText = @[@"未定时",@"1集播完后停止播放",@"2集播完后停止播放",@"3集播完后停止播放",@"4集播完后停止播放",@"5集播完后停止播放",@"6集播完后停止播放",@"7集播完后停止播放",@"8集播完后停止播放",@"9集播完后停止播放",@"10集播完后停止播放"];
        
        _sectionOneData = @[@"按时间定时",@"按集数定时"];
        _theSelectTimeIndex = 0;
        _theSelectEpisodeIndex = 0;
        GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
        GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    float width  = self.view.bounds.size.width;
    float height = self.view.bounds.size.height;
    self.tableView = ({
        UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, width, height-self.topBar.bounds.size.height) style:UITableViewStyleGrouped];
        tableView.backgroundView = nil;
        [tableView setBackgroundColor:CImageMgr::GetBackGroundColor()];
        [tableView setDelegate:self];
        [tableView setDataSource:self];
        tableView;
    });
    [[self view] addSubview:self.tableView];
    
    self.timePicker = ({
        UIPickerView *timePicker = [[UIPickerView alloc] init];
        [timePicker setFrame:CGRectMake(0, 0, 320, pickerCellHeight)];
        [timePicker setDelegate:self];
        [timePicker setDataSource:self];
        [timePicker setTag:kTimePickerTag];
        [timePicker setShowsSelectionIndicator:YES];
        timePicker;
    });
    self.flowProtectCell = ({
        UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        [cell.textLabel setText:@"流量保护"];
        
        UISwitch* switch_view = [[UISwitch alloc] initWithFrame:CGRectMake(220, 8, 30, 20)];
        [switch_view setTag:kSwitchViewTag];
        cell.accessoryView = switch_view;
        
        bool b_flow_protect = false;
        KwConfig::GetConfigureInstance()->GetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, b_flow_protect);
        [switch_view setOn:b_flow_protect];
        
        [switch_view addTarget:self action:@selector(onSwitchClicked:) forControlEvents:UIControlEventValueChanged];
        
        cell;
    });
    self.timeCell = ({
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kTimeCell];
        [cell.contentView addSubview:self.timePicker];
        cell;
    });
    self.episodePicker = ({
        UIPickerView *episodePicker = [[UIPickerView alloc] init];
        [episodePicker setFrame:CGRectMake(0, 0, 320, pickerCellHeight)];
        [episodePicker setDelegate:self];
        [episodePicker setDataSource:self];
        [episodePicker setTag:kEpisodePickerTag];
        [episodePicker setShowsSelectionIndicator:YES];
        episodePicker;
    });
    self.episodeCell = ({
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kEpisodeCell];
        [cell.contentView addSubview:self.episodePicker];
        cell;
    });
    self.showTimeCell = ({
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        [cell.textLabel setText:@"按时间定时"];
        if ([[KBSetTimming sharedInstance] isTimingSet]) {
            [cell.detailTextLabel setText:[NSString stringWithFormat:@"%d分钟后停止播放",[[KBSetTimming sharedInstance] getLeftTime]]];
        }
        else{
            [cell.detailTextLabel setText:self.timeDataCellText[_theSelectTimeIndex]];
        }
        cell;
    });
    self.showEpisodeCell = ({
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        [cell.textLabel setText:@"按集数定时"];
        if (CAudioPlayerManager::getInstance()->isChapterTimerSet()) {
            [cell.detailTextLabel setText:[NSString stringWithFormat:@"%d集播放完后停止播放",CAudioPlayerManager::getInstance()->chapterLeft()]];
        }
        else{
            [cell.detailTextLabel setText:self.episodeDataCellText[_theSelectEpisodeIndex]];
        }
        cell;
    });
    self.toolBar = ({
        UIToolbar *toolBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0,height, width, 44)];
        UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStyleBordered target:self action:@selector(onCancel:)];
        UIBarButtonItem *fixItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        [fixItem setWidth:210];
        UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithTitle:@"确定" style:UIBarButtonItemStyleBordered target:self action:@selector(onDone:)];
        [toolBar setItems:@[leftItem,fixItem,rightItem]];
        toolBar;
    });
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
-(void)dealloc{
    GLOBAL_DETACH_MESSAGE_OC(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState);
    GLOBAL_ATTACH_MESSAGE_OC(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect);
    [self.tableView setDelegate:nil];
    [self.tableView setDataSource:nil];
    [self.timePicker setDelegate:nil];
    [self.episodePicker setDelegate:nil];
}
#pragma mark 
#pragma mark table view data source

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 4;
}
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
        {
            return 1;
        }
        case 1:
        {
            if ([self hasInlineDatePicker]) {
                return 3;
            }
            else{
                return 2;
            }
        }
        case 2:
            return 1;
        case 3:
            return 2;
        default:
            break;
    }
    return 0;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"%d", indexPath.section);
    if (2 == indexPath.section) {
        NSLog(@"%f", ([self indexPathHasPicker:indexPath] ? pickerCellHeight : self.tableView.rowHeight));
    }
    return ([self indexPathHasPicker:indexPath] ? pickerCellHeight : self.tableView.rowHeight);
}

//- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
//    return 30;
//}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return @"流量保护";
    }
    if (section == 1) {
        return @"睡眠模式";
    }
    if (section == 3) {
        return @"其它";
    }
    return nil;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;//[[UITableViewCell alloc] init];
    switch (indexPath.section) {
        case 0:
        {
            cell = _flowProtectCell;
            
            break;
        }
        case 1:
        {
            if ([self indexPathHasPicker:indexPath])
            {
                if (indexPath.row == 1) {
                    cell = self.timeCell;
                }
                else{
                    cell = self.episodeCell;
                }
            }
            else if ([self indexPathHasDate:indexPath])
            {
                if (indexPath.row == 0) {
                    cell = self.showTimeCell;
                }
                else{
                    cell = self.showEpisodeCell;
                }
            }
            break;
        }
//        case 1:
//        {
//            cell = [[UITableViewCell alloc] init];
//            if (indexPath.row == 0) {
//                [cell.textLabel setText:@"夜间模式"];
//            }
//            else if (indexPath.row == 1){
//                [cell.textLabel setText:@"拔出耳机自动暂停"];
//            }
//            UISwitch *switchView = [[UISwitch alloc] init];
//            [cell setAccessoryView:switchView];
//            break;
//        }
        case 2:
        {
            cell = [[UITableViewCell alloc] init];
            [cell.textLabel setText:@"清空缓存"];
            [cell.textLabel setTextAlignment:NSTextAlignmentCenter];
            break;
        }
        case 3:
        {
            cell = [[UITableViewCell alloc] init];
            if (indexPath.row == 0) {
                [cell.textLabel setText:@"意见反馈"];
            }
            else if (indexPath.row == 1){
                [cell.textLabel setText:@"关于"];
            }
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            break;
        }
        default:
            break;
    }
    [cell setSelectionStyle:UITableViewCellSelectionStyleGray];
    return cell;
}
#pragma mark
#pragma mark table view delegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if (indexPath.section != 1) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    if (indexPath.section == 1){
        if (isIOS7())
            [self displayInlineDatePickerForRowAtIndexPath:indexPath];
        else
            [self displayExternalDatePickerForRowAtIndexPath:indexPath];
    }
    
    if (indexPath.section == 2) {
        CBookManagement::GetInstance()->ClearBuffer();
        [iToast defaultShow:@"清理成功"];
    }
    if (indexPath.section == 3) {
        switch (indexPath.row) {
            case 0:
            {
                [UMFeedback showFeedback:ROOT_NAVI_CONTROLLER withAppkey:UM_APPKEY];
                break;
            }
            case 1:
            {
                AboutViewController *aboutViewController = [[AboutViewController alloc] init];
                [ROOT_NAVI_CONTROLLER pushViewController:aboutViewController animated:YES];
                break;
            }
            default:
                break;
        }
    }
}
#pragma mark
#pragma mark  picker view data source
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if (pickerView == self.timePicker) {
        return self.timeData.count;
    }
    else if (pickerView == self.episodePicker){
        return self.episodeData.count;
    }
    return 0;
}
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    if (pickerView == self.timePicker) {
        return self.timeDataText[row];
    }
    if (pickerView == self.episodePicker) {
        return self.episodeDataText[row];
    }
    return nil;
}
#pragma mark
#pragma mark  picker view delegate

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    NSIndexPath *targetedCellIndexPath = nil;
    
    if ([self hasInlineDatePicker]){
        targetedCellIndexPath = [NSIndexPath indexPathForRow:self.pickerCellIndexPath.row - 1 inSection:1];
    }
    else{
        targetedCellIndexPath = [self.tableView indexPathForSelectedRow];
    }
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:targetedCellIndexPath];
    if (pickerView == self.timePicker) {
        _theSelectTimeIndex = row;
        _theSelectEpisodeIndex = 0;
        [[cell detailTextLabel] setText:[self.timeDataCellText objectAtIndex:_theSelectTimeIndex]];
        [[self.showEpisodeCell detailTextLabel] setText:self.episodeDataCellText[_theSelectEpisodeIndex]];
        [self.episodePicker selectRow:_theSelectEpisodeIndex inComponent:0 animated:NO];
    }
    else if (pickerView == self.episodePicker){
        _theSelectTimeIndex = 0;
        _theSelectEpisodeIndex = row;
        [[cell detailTextLabel] setText:[self.episodeDataCellText objectAtIndex:_theSelectEpisodeIndex]];
        [[self.showTimeCell detailTextLabel] setText:self.timeDataCellText[_theSelectTimeIndex]];
        [self.timePicker selectRow:_theSelectTimeIndex inComponent:0 animated:NO];
    }
    
}
#pragma mark
#pragma mark show inline picker view

- (BOOL)hasInlineDatePicker
{
    return (self.pickerCellIndexPath != nil);
}
- (BOOL)indexPathHasPicker:(NSIndexPath *)indexPath
{
    return ([self hasInlineDatePicker] && self.pickerCellIndexPath.row == indexPath.row);
}
- (BOOL)indexPathHasDate:(NSIndexPath *)indexPath
{
    BOOL hasDate = NO;
    
    if ((indexPath.row == 0) ||
        (indexPath.row == 1 || ([self hasInlineDatePicker] && (indexPath.row == 2))))
    {
        hasDate = YES;
    }
    
    return hasDate;
}
- (BOOL)hasPickerForIndexPath:(NSIndexPath *)indexPath
{
    BOOL hasDatePicker = NO;
    
    NSInteger targetedRow = indexPath.row;
    targetedRow++;
    
    UITableViewCell *checkDatePickerCell =
    [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:targetedRow inSection:1]];
    //UIDatePicker *checkDatePicker = (UIDatePicker *)[checkDatePickerCell viewWithTag:kDatePickerTag];
    UIPickerView *timePicker    = (UIPickerView *)[checkDatePickerCell viewWithTag:kTimePickerTag];
    UIPickerView *episodePicker = (UIPickerView *)[checkDatePickerCell viewWithTag:kEpisodePickerTag];
    
    hasDatePicker = ((timePicker != nil) || episodePicker != nil);
    return hasDatePicker;
}
- (void)displayInlineDatePickerForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // display the date picker inline with the table content
    [self.tableView beginUpdates];
    
    BOOL before = NO;   // indicates if the date picker is below "indexPath", help us determine which row to reveal
    if ([self hasInlineDatePicker])
    {
        before = self.pickerCellIndexPath.row < indexPath.row;
    }
    
    BOOL sameCellClicked = (self.pickerCellIndexPath.row - 1 == indexPath.row);
    
    // remove any date picker cell if it exists
    if ([self hasInlineDatePicker])
    {
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.pickerCellIndexPath.row inSection:1]]
                              withRowAnimation:UITableViewRowAnimationFade];
        self.pickerCellIndexPath = nil;
    }
    
    if (!sameCellClicked)
    {
        // hide the old date picker and display the new one
        NSInteger rowToReveal = (before ? indexPath.row - 1 : indexPath.row);
        NSIndexPath *indexPathToReveal = [NSIndexPath indexPathForRow:rowToReveal inSection:1];
        
        [self toggleDatePickerForSelectedIndexPath:indexPathToReveal];
        self.pickerCellIndexPath = [NSIndexPath indexPathForRow:indexPathToReveal.row + 1 inSection:1];
    }
    else{
        if (indexPath.row == 0) {
            if (_theSelectTimeIndex > 0 && _theSelectTimeIndex < self.timeData.count) {
                NSLog(@"set time %@",self.timeData[_theSelectTimeIndex]);
                [[KBSetTimming sharedInstance] setTimming:[self.timeData[_theSelectTimeIndex] integerValue]];
                _theSelectEpisodeIndex = 0;
                CAudioPlayerManager::getInstance()->setChapterTimming(_theSelectEpisodeIndex);
            }
        }
        else{
            if (_theSelectEpisodeIndex > 0 && _theSelectEpisodeIndex < self.episodeData.count) {
                NSLog(@"set episode:%@",self.episodeData[_theSelectEpisodeIndex]);
                CAudioPlayerManager::getInstance()->setChapterTimming([self.episodeData[_theSelectEpisodeIndex] integerValue]);
                _theSelectEpisodeIndex = 0;
                [[KBSetTimming sharedInstance] setTimming:_theSelectEpisodeIndex];
            }
        }
    }
    // always deselect the row containing the start or end date
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [self.tableView endUpdates];
    
    // inform our date picker of the current date to match the current cell
    [self updateDatePicker];
}
- (void)toggleDatePickerForSelectedIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView beginUpdates];
    
    NSArray *indexPaths = @[[NSIndexPath indexPathForRow:indexPath.row + 1 inSection:1]];
    
    // check if 'indexPath' has an attached date picker below it
    if ([self hasPickerForIndexPath:indexPath])
    {
        // found a picker below it, so remove it
        [self.tableView deleteRowsAtIndexPaths:indexPaths
                              withRowAnimation:UITableViewRowAnimationFade];
    }
    else
    {
        // didn't find a picker below it, so we should insert it
        [self.tableView insertRowsAtIndexPaths:indexPaths
                              withRowAnimation:UITableViewRowAnimationFade];
    }
    
    [self.tableView endUpdates];
}
- (void)updateDatePicker
{
//    if (self.pickerCellIndexPath != nil)
//    {
//        UITableViewCell *associatedDatePickerCell = [self.tableView cellForRowAtIndexPath:self.pickerCellIndexPath];
//        
//        UIDatePicker *targetedDatePicker = (UIDatePicker *)[associatedDatePickerCell viewWithTag:kTimePickerTag];
//        if (targetedDatePicker != nil){
//            // we found a UIDatePicker in this cell, so update it's date value
//            //
//            NSDictionary *itemData = self.dataArray[self.datePickerIndexPath.row - 1];
//            [targetedDatePicker setDate:[itemData valueForKey:kDateKey] animated:NO];
//        }
//    }
}
#pragma mark
#pragma mark show extern picker
- (void)displayExternalDatePickerForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIPickerView *pickerView  = nil;
    if (indexPath.row == 0) {
        pickerView = self.timePicker;
    }
    else{
        pickerView = self.episodePicker;
    }
    
    if (!self.toolBar.superview) {
        CGRect startFrame = pickerView.frame;
        CGRect endFrame = pickerView.frame;
        
        // the start position is below the bottom of the visible frame
        startFrame.origin.y = self.view.frame.size.height - 44;
        
        // the end position is slid up by the height of the view
        endFrame.origin.y = startFrame.origin.y - endFrame.size.height + 44;
        
        pickerView.frame = startFrame;
        
        CGRect toolBarStartFrame = self.toolBar.frame;
        CGRect tooBarEndFrame = self.toolBar.frame;
        
        toolBarStartFrame.origin.y = self.view.frame.size.height;
        tooBarEndFrame.origin.y = toolBarStartFrame.origin.y - endFrame.size.height;
        
        [self.view addSubview:pickerView];
        [self.view addSubview:self.toolBar];
        
        [UIView animateWithDuration:0.25 animations: ^{
            pickerView.frame = endFrame;
            self.toolBar.frame = tooBarEndFrame;
        }
        completion:^(BOOL finished) {
            [self.tableView setUserInteractionEnabled:NO];
        }];
    }
}
#pragma mark
#pragma mark tool bar button action
-(void)onCancel:(id)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    UIPickerView    *pickerView  = nil;
    UITableViewCell *cell        = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if (indexPath.row == 0) {
        pickerView = self.timePicker;
    }
    else{
        pickerView = self.episodePicker;
    }
    
    if (self.toolBar.superview) {
        CGRect startFrame = pickerView.frame;
        CGRect endFrame = pickerView.frame;
        
        endFrame.origin.y = startFrame.origin.y + endFrame.size.height + 44;
        
        CGRect toolBarStartFrame = self.toolBar.frame;
        CGRect tooBarEndFrame = self.toolBar.frame;
        
        tooBarEndFrame.origin.y = toolBarStartFrame.origin.y + endFrame.size.height;
    
        [UIView animateWithDuration:0.25 animations: ^{
            pickerView.frame = endFrame;
            self.toolBar.frame = tooBarEndFrame;
        }
        completion:^(BOOL finished) {
            [pickerView removeFromSuperview];
            [self.toolBar removeFromSuperview];
            [cell.detailTextLabel setText:@"未定时"];
            [self.tableView setUserInteractionEnabled:YES];
        }];
    }

}
-(void)onDone:(id)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    UIPickerView    *pickerView  = nil;
    
    if (indexPath.row == 0) {
        pickerView = self.timePicker;
        if (_theSelectTimeIndex > 0 && _theSelectTimeIndex < self.timeData.count) {
            [[KBSetTimming sharedInstance] setTimming:[self.timeData[_theSelectTimeIndex] integerValue]];
            _theSelectEpisodeIndex = 0;
            CAudioPlayerManager::getInstance()->setChapterTimming(_theSelectEpisodeIndex);
        }
    }
    else{
        pickerView = self.episodePicker;
        if (_theSelectEpisodeIndex > 0 && _theSelectEpisodeIndex < self.episodeData.count) {
            CAudioPlayerManager::getInstance()->setChapterTimming([self.episodeData[_theSelectEpisodeIndex] integerValue]);
            _theSelectEpisodeIndex = 0;
            [[KBSetTimming sharedInstance] setTimming:_theSelectEpisodeIndex];
        }
    }
    
    if (self.toolBar.superview) {
        CGRect startFrame = pickerView.frame;
        CGRect endFrame = pickerView.frame;
        
        endFrame.origin.y = startFrame.origin.y + endFrame.size.height + 44;
        
        CGRect toolBarStartFrame = self.toolBar.frame;
        CGRect tooBarEndFrame = self.toolBar.frame;
        
        tooBarEndFrame.origin.y = toolBarStartFrame.origin.y + endFrame.size.height;
        
        [UIView animateWithDuration:0.25 animations: ^{
            pickerView.frame = endFrame;
            self.toolBar.frame = tooBarEndFrame;
        }
            completion:^(BOOL finished) {
            [pickerView removeFromSuperview];
            [self.toolBar removeFromSuperview];
            [self.tableView setUserInteractionEnabled:YES];
        }];
    }
}

- (void)onSwitchClicked:(id)sender{
    UISwitch* switch_view = (UISwitch*)sender;
    KwConfig::GetConfigureInstance()->SetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, switch_view.on);
    //发送通知
    SYN_NOTIFY(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect::FlowProtectStatusChange, switch_view.on);
}


#pragma mark - time and episode observer methods
-(void)IObserverTimmingLeft:(int)nMinLeft{
    
    _theSelectTimeIndex = nMinLeft;
    if (_theSelectTimeIndex <= 0) {
        _theSelectTimeIndex = 0;
        [self.showTimeCell.detailTextLabel setText:@"未定时"];
        //[self.timePicker selectRow:_theSelectTimeIndex inComponent:0 animated:NO];
    }
    else{
        [self.showTimeCell.detailTextLabel setText:[NSString stringWithFormat:@"%d分钟后停止播放",nMinLeft]];
        //[self.timePicker selectRow:_theSelectTimeIndex inComponent:0 animated:NO];
    }
}

-(void)IObserverChapterLeft:(int)nChapterLeft
{
    _theSelectEpisodeIndex = nChapterLeft;
    if (_theSelectEpisodeIndex <= 0) {
        _theSelectEpisodeIndex = 0;
        [self.showEpisodeCell.detailTextLabel setText:@"未定时"];
        //[self.episodePicker selectRow:_theSelectEpisodeIndex inComponent:0 animated:NO];
    }
    else{
        [self.showEpisodeCell.detailTextLabel setText:[NSString stringWithFormat:@"%d集播放完后停止播放",nChapterLeft]];
        //[self.episodePicker selectRow:_theSelectEpisodeIndex inComponent:0 animated:NO];
    }
}

#pragma mark   flow protect observer
-(void)IObserverFlowProtectStatusChanged:(bool)b_protect_on{
    UISwitch* flow_switch = (UISwitch*)_flowProtectCell.accessoryView;
    flow_switch.on = b_protect_on;
    
    [flow_switch setOn:b_protect_on];
    
//    [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]
//                                        ] withRowAnimation:(UITableViewRowAnimationNone)];
}

@end
