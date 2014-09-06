//
//  MyPageEditViewController.m
//  KwSing
//
//  Created by 改 熊 on 12-8-6.
//  Copyright (c) 2012年 酷我音乐. All rights reserved.
//

#import "MyPageEditViewController.h"
#import "globalm.h"
#import "FooterTabBar.h"
#import "User.h"
#import "HttpRequest.h"
#import "KSAppDelegate.h"
#import "ImageMgr.h"
#import "KwDir.h"
#import "KwTools.h"
#import "MessageManager.h"
#import "IUserStatusObserver.h"
#import "iToast.h"

@interface MyPageEditViewController ()<UIPickerViewDelegate,UIPickerViewDataSource>

@end

@implementation MyPageEditViewController

@synthesize tableView=_tableView;
@synthesize nickname=_nickname;
@synthesize hometown=_hometown;
@synthesize address=_address;
@synthesize birthday=_birthday;
@synthesize dataSource=dataSource;
@synthesize dataPicker;
@synthesize pickerView1=_pickerView1;
@synthesize pickerView2=_pickerView2;
@synthesize provinceCities;
@synthesize cities;
@synthesize provinces;

#define LeftMargin				10.0
#define TopMargin				10.0
#define TextFieldHeight         30.0
#define TextFieldWidth          285.0
const int ViewTag=1;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
     
    }
    return self;
}


- (void)viewDidLoad
{
//    [self setTitle:@"编辑资料"];
    
    self.dataSource=[NSArray arrayWithObjects:self.nickname,self.hometown,self.address,self.birthday, nil];
    
    UIView* view_title = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)] autorelease];
    [view_title setBackgroundColor:UIColorFromRGBValue(0x0a63a7)];
    [self.view addSubview:view_title];
    
    UILabel* label_title = [[[UILabel alloc] initWithFrame:CGRectMake(112.5, 8, 95, 28)] autorelease];
    [label_title setBackgroundColor:[UIColor clearColor]];
    [label_title setTextAlignment:(NSTextAlignmentCenter)];
    [label_title setTextColor:[UIColor whiteColor]];
    [label_title setFont:[UIFont systemFontOfSize:18]];
    [label_title setText:@"编辑资料"];
    [view_title addSubview:label_title];
    
    
    UIButton* okButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [okButton setTag:1];
    [okButton setTitle:@"确定" forState: UIControlStateNormal];
    [okButton setBackgroundImage:CImageMgr::GetImageEx("topReturnBtn_6.png") forState:UIControlStateNormal];
    [okButton setBackgroundImage:CImageMgr::GetImageEx("topReturnBtnDown_6.png") forState:UIControlStateHighlighted];
    [okButton.titleLabel setFont:[UIFont systemFontOfSize:14]];
    okButton.frame = CGRectMake(260, 9, 47,28);
    [okButton addTarget:self action:@selector(onOkClick) forControlEvents:UIControlEventTouchUpInside];
    [[self view] addSubview:okButton];
    
    UILabel* lable = [[[UILabel alloc]initWithFrame:CGRectMake(60, 15, self.navigationController.navigationBar.bounds.size.width-120,18)] autorelease];
    lable.textAlignment = UITextAlignmentCenter;
    lable.text = [self title];
    lable.Font = [UIFont systemFontOfSize:18];
    [lable setShadowColor:UIColorFromRGBAValue(0x000000,50)];
    [lable setShadowOffset:CGSizeMake(1, 1)];
    lable.backgroundColor = [UIColor clearColor];
    lable.textColor = [UIColor whiteColor];
    [[self view] addSubview:lable];
    
    UIImageView * topshadow=[[UIImageView alloc] init];
    CGRect rcshadow=ROOT_NAVAGATION_CONTROLLER.navigationBar.bounds;
    rcshadow.origin.y+=rcshadow.size.height;
    rcshadow.size.height=5;
    [topshadow setFrame:rcshadow];
    [topshadow setImage:CImageMgr::GetImageEx("topShadow.png")];
    [[self view] addSubview:topshadow];
    [topshadow release];
    
    CGRect rc=[self view].bounds;
    CGRect rcna=ROOT_NAVAGATION_CONTROLLER.navigationBar.bounds;
    CGRect back=BottomRect(rc, rc.size.height-rcna.size.height, 0);
    
    [[self view] setBackgroundColor:UIColorFromRGBValue(0xededed)];
    
    self.tableView = [[[UITableView alloc] initWithFrame:back style:UITableViewStyleGrouped] autorelease];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor=CImageMgr::GetBackGroundColor();
    self.tableView.separatorColor=UIColorFromRGBAValue(0x000000,26);
    [self.view addSubview:self.tableView];
    
    NSBundle *bundle=[NSBundle mainBundle];
    NSURL *plistURL=[bundle URLForResource:@"provinceCities" withExtension:@"plist"];
    
    NSMutableDictionary *dic=[[NSMutableDictionary alloc] initWithContentsOfURL:plistURL];

    self.provinceCities=dic;
    self.provinces=[dic allKeys];
    self.cities=[provinceCities objectForKey:[self.provinces objectAtIndex:0]];
    [dic release];
    
    _waitingDialog=[[UIAlertView alloc] initWithTitle:@"正在修改资料,请稍后..." message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:nil, nil];
    
    UIActivityIndicatorView *activity=[[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite] autorelease];
    [activity setCenter:CGPointMake(150, 50)];
    [activity startAnimating];
    [_waitingDialog addSubview:activity];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    _waitingDialog=nil;
    // Release any retained subviews of the main view.
}
-(void)ReturnBtnClick
{
    [self.navigationController popViewControllerAnimated:YES];
}
//http://changba.kuwo.cn/kge/mobile/ModProfile?uid=xxx?sid=xxx&nickname=xxx&sex=xx&birth_city=xx&resident_city=xx&birthday=xxx
-(void)onOkClick
{
    
    if (_nickname.text.length == 0 || _hometown.text.length == 0 || _address.text.length == 0 || _birthday.text.length == 0) {
        UIAlertView *alertView=[[[UIAlertView alloc] initWithTitle:@"提示"
                                                             message:@"请输入相应的信息"
                                                            delegate:nil
                                                   cancelButtonTitle:@"确定"
                                                   otherButtonTitles:nil, nil] autorelease];
        [alertView show];
        return;
    }
    [_waitingDialog show];
    NSString* nick=[_nickname text];
    nick=KwTools::Encoding::UrlEncode(nick);
    User::sexType s=User::GetUserInstance()->getSex();
    NSString* home=_hometown.text;
    home=KwTools::Encoding::UrlEncode(home);
    NSString* add=_address.text;
    add=KwTools::Encoding::UrlEncode(add);
    NSString* birth=_birthday.text;
    NSString *sendString;
    if ([birth isEqualToString:@"保密"]) {
        birth=nil;
        sendString=[NSString stringWithFormat:@"http://changba.kuwo.cn/kge/mobile/ModProfile?uid=%@&sid=%@&nickname=%@&sex=%d&birth_city=%@&resident_city=%@&act=mod",User::GetUserInstance()->getUserId(),User::GetUserInstance()->getSid(),nick,s,home,add];

    }
    else{
        birth=KwTools::Encoding::UrlEncode(birth);
        sendString=[NSString stringWithFormat:@"http://changba.kuwo.cn/kge/mobile/ModProfile?uid=%@&sid=%@&nickname=%@&sex=%d&birth_city=%@&resident_city=%@&birthday=%@&act=mod",User::GetUserInstance()->getUserId(),User::GetUserInstance()->getSid(),nick,s,home,add,birth];

    }
    //NSLog(@"send:%@",sendString);
    KS_BLOCK_DECLARE
    {
        std::string outString;
        BOOL returnRes=CHttpRequest::QuickSyncGet([sendString UTF8String], outString);
        KS_BLOCK_DECLARE
        {
            [_waitingDialog dismissWithClickedButtonIndex:0 animated:NO];
            if(returnRes)
            {
                [[[[iToast makeText:NSLocalizedString(@"修改成功", @"")]setGravity:iToastGravityCenter] setDuration:2000] show];
                User::GetUserInstance()->setNickName(_nickname.text);
                User::GetUserInstance()->setHometown(_hometown.text);
                User::GetUserInstance()->setAddress(_address.text);
                User::GetUserInstance()->setBirthday(_birthday.text);
                User::GetUserInstance()->setNickName(_nickname.text);
                SYN_NOTIFY(OBSERVER_ID_USERSTATUS,IUserStatusObserver::StateChange);
                [self.navigationController popViewControllerAnimated:YES];
            }
            else{
                [[[[iToast makeText:NSLocalizedString(@"修改失败，请稍后再试", @"")]setGravity:iToastGravityCenter] setDuration:3000] show];
            }
        }KS_BLOCK_SYNRUN()
    }KS_BLOCK_RUN_THREAD()
   
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    int count = dataSource.count;  
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = nil;
	NSUInteger row = [indexPath row];

    cell = [tableView dequeueReusableCellWithIdentifier:@"MyPageCell"];
    if (cell == nil)
    {
        // a new cell needs to be created
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:@"MyPageCell"] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    else
    {
        // a cell is being recycled, remove the old edit field (if it contains one of our tagged edit fields)
        UIView *viewToCheck = nil;
        viewToCheck = [cell.contentView viewWithTag:ViewTag];
        if (viewToCheck)
            [viewToCheck removeFromSuperview];
    }
    UITextField *textField = [self.dataSource objectAtIndex: row];
    [cell.contentView addSubview:textField];
    return cell;
}
- (void)handleHideKey:(id)sender{
    [self.nickname resignFirstResponder];
    [self.hometown resignFirstResponder];
    [self.address resignFirstResponder];
    [self.birthday resignFirstResponder];
}
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    [self.nickname resignFirstResponder];
    [self.hometown resignFirstResponder];
    [self.address resignFirstResponder];
    [self.birthday resignFirstResponder];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    [self.nickname resignFirstResponder];
    [self.hometown resignFirstResponder];
    [self.address resignFirstResponder];
    [self.birthday resignFirstResponder];

}
- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
	return YES;
}
-(void)onDataPicker
{
    NSDateFormatter *dateFormatter=[[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    NSString* strDate=[dateFormatter stringFromDate:[dataPicker date]];
    [_birthday setText:strDate];
}
-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 2;
}
-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if (component==0) {
        return self.provinces.count;
    }
    else {
        return self.cities.count;
    }
}
-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    if (component==0) {
        return [self.provinces objectAtIndex:row];
    }
    else {
        return [self.cities objectAtIndex:row];
    }
}
-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    if (component == 0) {
        NSArray * array=[provinceCities objectForKey:[self.provinces objectAtIndex:row]];
        self.cities=array;
        [pickerView selectRow:0 inComponent:1 animated:YES];
        [pickerView reloadComponent:1];
    }
    NSInteger provinceRow=[pickerView selectedRowInComponent:0];
    NSInteger cityRow=[pickerView selectedRowInComponent:1];
    if (pickerView.tag == 1) {
        [_hometown setText:[NSString stringWithFormat:@"%@_%@",[self.provinces objectAtIndex:provinceRow],[self.cities objectAtIndex:cityRow]]];
    }
    else
    {
        [_address setText:[NSString stringWithFormat:@"%@_%@",[self.provinces objectAtIndex:provinceRow],[self.cities objectAtIndex:cityRow]]];
    }
}
-(UITextField*)nickname{
    if (_nickname == nil) {
        CGRect frame = CGRectMake(LeftMargin,TopMargin, TextFieldWidth, TextFieldHeight);
		_nickname = [[UITextField alloc] initWithFrame:frame];
		[_nickname setText:User::GetUserInstance()->getNickName()];
		_nickname.borderStyle = UITextBorderStyleNone;//UITextBorderStyleLine;
		_nickname.textColor = [UIColor blackColor];
		_nickname.font = [UIFont systemFontOfSize:16.0];
        _nickname.textAlignment = UITextAlignmentLeft;
        _nickname.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		//_nickname.placeholder = @"";
		_nickname.backgroundColor = [UIColor clearColor];
		_nickname.autocorrectionType = UITextAutocorrectionTypeNo;	// no auto correction support
		_nickname.autocapitalizationType = UITextAutocapitalizationTypeNone;
		_nickname.keyboardType = UIKeyboardTypeDefault;
		_nickname.returnKeyType = UIReturnKeyDone;
		
		_nickname.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x' button to the right
		
		_nickname.tag = ViewTag;		// tag this control so we can remove it later for recycled cells
		
		_nickname.delegate = self;	// let us be the delegate so we know when the keyboard's "Done" button is pressed
		
        if (User::GetUserInstance()->getNickName()) {
            [_nickname setText:User::GetUserInstance()->getNickName()];
        }
        
        CGRect rect = CGRectMake(0, 0, 85, 44);
        UILabel* tmp = [[[UILabel alloc] initWithFrame:rect] autorelease ];
        tmp.backgroundColor = [UIColor clearColor];
        //tmp.font = [UIFont skinFontOfSize:16];
        [tmp setText:@"用户昵称:"];
        
        _nickname.leftView = tmp;
        _nickname.leftViewMode = UITextFieldViewModeAlways;
        
    }
    return _nickname;
}
-(UITextField*)hometown{
    if (_hometown == nil) {
        CGRect frame = CGRectMake(LeftMargin,8, TextFieldWidth, TextFieldHeight);
		_hometown = [[UITextField alloc] initWithFrame:frame];

		_hometown.borderStyle = UITextBorderStyleNone;//UITextBorderStyleRoundedRect;
		_hometown.textColor = [UIColor blackColor];
		_hometown.font = [UIFont systemFontOfSize:16.0];
        _hometown.textAlignment = UITextAlignmentLeft;
        _hometown.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		//_hometown.placeholder = @"请输入密码";
		_hometown.backgroundColor = [UIColor clearColor];
        
		_hometown.autocorrectionType = UITextAutocorrectionTypeNo;	// no auto correction support
		_hometown.autocapitalizationType = UITextAutocapitalizationTypeNone;
		//_hometown.keyboardType = UIKeyboardTypeASCIICapable;
        
        _pickerView1 =[[[UIPickerView alloc] init] autorelease];
        [_pickerView1 setTag:1];
        [_hometown setInputView:_pickerView1];
        [_pickerView1 setDelegate:self];
        [_pickerView1 setDataSource:self];
        [_pickerView1 setShowsSelectionIndicator:YES];

        
		_hometown.returnKeyType = UIReturnKeyDone;
		//_hometown.secureTextEntry = YES;
		_hometown.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x' button to the right
		
		_hometown.tag = ViewTag;		// tag this control so we can remove it later for recycled cells
		
		_hometown.delegate = self;	// let us be the delegate so we know when the keyboard's "Done" button is pressed
		
		// Add an accessibility label that describes what the text field is for.
		//[textFieldRounded setAccessibilityLabel:NSLocalizedString(@"RoundedTextField", @"")];
        
        if (User::GetUserInstance()->getHometown()) {
            [_hometown setText:User::GetUserInstance()->getHometown()];
        }
        
        CGRect rect = CGRectMake(0, 0, 85, 44);
        UILabel* tmp = [[[UILabel alloc] initWithFrame:rect] autorelease ];
        tmp.backgroundColor = [UIColor clearColor];
        //tmp.font = [UIFont skinFontOfSize:16];
        [tmp setText:@"家乡:"];
        _hometown.leftView = tmp;
        _hometown.leftViewMode = UITextFieldViewModeAlways;
    }
    return _hometown;
}
-(UITextField*)address{
    if (_address == nil) {
        CGRect frame = CGRectMake(LeftMargin,8, TextFieldWidth, TextFieldHeight);
		_address = [[UITextField alloc] initWithFrame:frame];
		//_address.enabled=NO;
		_address.borderStyle = UITextBorderStyleNone;//UITextBorderStyleRoundedRect;
		_address.textColor = [UIColor blackColor];
		_address.font = [UIFont systemFontOfSize:16.0];
        _address.textAlignment = UITextAlignmentLeft;
        _address.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		//_address.placeholder = @"";
		_address.backgroundColor = [UIColor clearColor];
		_address.autocorrectionType = UITextAutocorrectionTypeNo;	// no auto correction support
		_address.autocapitalizationType = UITextAutocapitalizationTypeNone;
		//_address.keyboardType = UIKeyboardTypeASCIICapable;
		//_address.returnKeyType = UIReturnKeyDone;
		//_address.secureTextEntry = YES;

        _pickerView2 =[[[UIPickerView alloc] init] autorelease];
        [_pickerView2 setTag:2];
        [_address setInputView:_pickerView2];
        [_pickerView2 setDelegate:self];
        [_pickerView2 setDataSource:self];
        [_pickerView2 setShowsSelectionIndicator:YES];
		_address.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x' button to the right
		
		_address.tag = ViewTag;		// tag this control so we can remove it later for recycled cells
		
		_address.delegate = self;	// let us be the delegate so we know when the keyboard's "Done" button is pressed
		
		// Add an accessibility label that describes what the text field is for.
		//[textFieldRounded setAccessibilityLabel:NSLocalizedString(@"RoundedTextField", @"")];
        if (User::GetUserInstance()->getAddress()) {
            [_address setText:User::GetUserInstance()->getAddress()];
        }
        
        CGRect rect = CGRectMake(0, 0, 85, 44);
        UILabel* tmp = [[[UILabel alloc] initWithFrame:rect] autorelease ];
        tmp.backgroundColor = [UIColor clearColor];
        //tmp.font = [UIFont skinFontOfSize:16];
        [tmp setText:@"现居地:"];
        _address.leftView = tmp;
        _address.leftViewMode = UITextFieldViewModeAlways;
    }
    return _address;
}-(UITextField*)birthday{
    if (_birthday == nil) {
        CGRect frame = CGRectMake(LeftMargin,8, TextFieldWidth, TextFieldHeight);
		_birthday = [[UITextField alloc] initWithFrame:frame];
		
		_birthday.borderStyle = UITextBorderStyleNone;//UITextBorderStyleRoundedRect;
		_birthday.textColor = [UIColor blackColor];
		_birthday.font = [UIFont systemFontOfSize:16.0];
        _birthday.textAlignment = UITextAlignmentLeft;
        _birthday.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		//_birthday.placeholder = @"";
		_birthday.backgroundColor = [UIColor clearColor];
		_birthday.autocorrectionType = UITextAutocorrectionTypeNo;	// no auto correction support
		_birthday.autocapitalizationType = UITextAutocapitalizationTypeNone;
		//_birthday.keyboardType = UIKeyboardTypeASCIICapable;
		//_birthday.returnKeyType = UIReturnKeyDone;
        dataPicker=[[[UIDatePicker alloc] init] autorelease];
        dataPicker.datePickerMode=UIDatePickerModeDate;
        [dataPicker addTarget:self action:@selector(onDataPicker) forControlEvents:UIControlEventValueChanged];
        _birthday.inputView=dataPicker;
		_birthday.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x' button to the right
		
		_birthday.tag = ViewTag;		// tag this control so we can remove it later for recycled cells
		
		_birthday.delegate = self;	// let us be the delegate so we know when the keyboard's "Done" button is pressed
		
		// Add an accessibility label that describes what the text field is for.
		//[textFieldRounded setAccessibilityLabel:NSLocalizedString(@"RoundedTextField", @"")];
        
        if (User::GetUserInstance()->getBirthday()) {
            [_birthday setText:User::GetUserInstance()->getBirthday()];
        }
        
        CGRect rect = CGRectMake(0, 0, 85, 44);
        UILabel* tmp = [[[UILabel alloc] initWithFrame:rect] autorelease ];
        tmp.backgroundColor = [UIColor clearColor];
        //tmp.font = [UIFont skinFontOfSize:16];
        [tmp setText:@"生日:"];
        _birthday.leftView = tmp;
        _birthday.leftViewMode = UITextFieldViewModeAlways;
    }
    return _birthday;
}
-(void)dealloc
{
    [super dealloc];
    [_tableView release];
    [_nickname release];
    [_hometown release];
    [_address release];
    [_birthday release];
    [_waitingDialog release];
}

@end