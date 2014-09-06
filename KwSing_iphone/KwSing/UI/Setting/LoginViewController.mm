//
//  LoginViewController.m
//  KwSing
//
//  Created by 改 熊 on 12-8-2.
//  Copyright (c) 2012年 酷我音乐. All rights reserved.
//

#import "LoginViewController.h"

#import "User.h"
#import "ImageMgr.h"
#import "KSAppDelegate.h"
#import "ImageMgr.h"
#import "globalm.h"
#import "FooterTabBar.h"
#import "KSOtherLoginViewController.h"
#import "RegexKitLite.h"
#import "MessageManager.h"
#import "IUserStatusObserver.h"
#import "RegistViewController.h"
#import "KwConfig.h"
#import "HttpRequest.h"
#import "KwConfigElements.h"
#import "iToast.h"
#import "KwTools.h"

@implementation KSLoginViewController
@synthesize userName = _userName;
@synthesize passWord = _passWord;
@synthesize checkPWD=_checkPWD;
@synthesize dataSource;
@synthesize myTableView;

const int ViewTag=1;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}
-(void)viewDidLoad
{
    [super viewDidLoad];
    
    [[self view] setBackgroundColor:[UIColor whiteColor]];
    self.dataSource=[NSArray arrayWithObjects:self.userName,self.passWord, nil];
    
    UIView* view_title = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)] autorelease];
    [view_title setBackgroundColor:UIColorFromRGBValue(0x0a63a7)];
    [self.view addSubview:view_title];
    
    UILabel* label_title = [[[UILabel alloc] initWithFrame:CGRectMake(112.5, 8, 95, 28)] autorelease];
    [label_title setBackgroundColor:[UIColor clearColor]];
    [label_title setTextAlignment:(NSTextAlignmentCenter)];
    [label_title setTextColor:[UIColor whiteColor]];
    [label_title setFont:[UIFont systemFontOfSize:18]];
    [label_title setText:@"登录"];
    [view_title addSubview:label_title];
    
    UIButton* btn_ret = [UIButton buttonWithType:UIButtonTypeCustom];
    btn_ret.frame = CGRectMake(0, 0, 44, 44);
    [btn_ret setBackgroundColor:[UIColor clearColor]];
    btn_ret.imageEdgeInsets = UIEdgeInsetsMake(10, 14.5, 10, 14.5);
    [btn_ret setImage:CImageMgr::GetImageEx("KgeReturnBtn.png") forState:(UIControlStateNormal)];
    [btn_ret addTarget:self action:@selector(ReturnBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [view_title addSubview:btn_ret];

    
    UIButton* registerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [registerButton setTag:1];
    [registerButton setTitle:@"注册" forState: UIControlStateNormal];
    [[registerButton titleLabel] setShadowColor:[UIColor blackColor]];
    [[registerButton titleLabel] setShadowOffset:CGSizeMake(0, 1)];
    [registerButton setBackgroundImage:CImageMgr::GetImageEx("topReturnBtn_6.png") forState:UIControlStateNormal];
    [registerButton setBackgroundImage:CImageMgr::GetImageEx("topReturnBtnDown_6.png") forState:UIControlStateHighlighted];
    [registerButton.titleLabel setFont:[UIFont systemFontOfSize:14]];
    registerButton.frame = CGRectMake(260, 9, 47,28);
    [registerButton addTarget:self action:@selector(RegisterBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [[self view] addSubview:registerButton];
    
    UILabel* lable = [[UILabel alloc]initWithFrame:CGRectMake(60, 15, self.navigationController.navigationBar.bounds.size.width-120,18)];
    lable.textAlignment = UITextAlignmentCenter;
    lable.text = [self title];
    lable.Font = [UIFont systemFontOfSize:18];
    [lable setShadowColor:UIColorFromRGBAValue(0x000000,50)];
    [lable setShadowOffset:CGSizeMake(1, 1)];
    lable.backgroundColor = [UIColor clearColor];
    lable.textColor = [UIColor whiteColor];
    [[self view] addSubview:lable];
    [lable release];

    
    UIImageView * topshadow=[[[UIImageView alloc] init] autorelease];
    CGRect rcshadow=ROOT_NAVAGATION_CONTROLLER_BOUNDS;
    rcshadow.origin.y+=rcshadow.size.height;
    rcshadow.size.height=5;
    [topshadow setFrame:rcshadow];
    [topshadow setImage:CImageMgr::GetImageEx("topShadow.png")];
    [[self view] addSubview:topshadow];
    
    CGRect rc=[self view].bounds;
    CGRect rcna=ROOT_NAVAGATION_CONTROLLER_BOUNDS;
    rc=BottomRect(rc, rc.size.height-rcna.size.height,0);
    
    myTableView=[[UITableView alloc] initWithFrame:rc style:UITableViewStyleGrouped];
    myTableView.delegate=self;
    myTableView.dataSource=self;
    myTableView.backgroundColor=[UIColor clearColor];
    myTableView.backgroundView.alpha=0;
    myTableView.scrollEnabled=NO;
    myTableView.sectionFooterHeight=100;
    [[self view] addSubview:myTableView];
    
    self.checkPWD=[UIButton buttonWithType:UIButtonTypeCustom];
    self.checkPWD.backgroundColor=[UIColor clearColor];
    self.checkPWD.titleLabel.font=[UIFont systemFontOfSize:16.0];
    [self.checkPWD setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.checkPWD setFrame:CGRectMake(10, 170, 120, 40)];
    [self.checkPWD setImage:CImageMgr::GetImageEx("checkboxUnchecked.png") forState:UIControlStateNormal];
    [self.checkPWD setImage:CImageMgr::GetImageEx("checkboxChecked.png") forState:UIControlStateSelected];
    [self.checkPWD  setTitle:@"记住密码" forState:UIControlStateNormal];
    [self.checkPWD setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [[self.checkPWD titleLabel] setFont:[UIFont systemFontOfSize:15]];
    [self.checkPWD setSelected:YES];
    [self.checkPWD addTarget:self action:@selector(pwdcheckboxClik:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton * loginButton=[UIButton buttonWithType:UIButtonTypeRoundedRect];
    [loginButton setFrame:CGRectMake(140, 170, 170, 40)];
    [loginButton setTitle:@"登录" forState:UIControlStateNormal];
    [[loginButton titleLabel] setFont:[UIFont systemFontOfSize:20]];
    [loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [loginButton setBackgroundImage:CImageMgr::GetImageEx("loginButton.png") forState:UIControlStateNormal];
    [loginButton setBackgroundImage:CImageMgr::GetImageEx("loginButtonDown.png") forState:UIControlStateHighlighted];
    loginButton.titleLabel.shadowOffset=CGSizeMake(0, -1);
    loginButton.titleLabel.shadowColor=UIColorFromRGBValue(0x000000);
    [loginButton addTarget:self action:@selector(loginClicked) forControlEvents:UIControlEventTouchUpInside];
    
    [[self view] addSubview:self.checkPWD];
    [[self view] addSubview:loginButton];
    

    
    _waitingDialog=[[UIAlertView alloc] initWithTitle:@"正在登录,请稍后..." message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:nil, nil];
    
    UIActivityIndicatorView *activity=[[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite] autorelease];
    [activity setCenter:CGPointMake(150, 50)];
    [activity startAnimating];
    [_waitingDialog addSubview:activity];
    
    [[self view] bringSubviewToFront:topshadow];
    
    [[self view] setBackgroundColor:UIColorFromRGBValue(0xededed)];
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    _userName=nil;
    _passWord=nil;
    _checkPWD=nil;
    myTableView=nil;
    _waitingDialog=nil;
}
-(void)doLoginWithIndex:(NSIndexPath*)indexPath
{
    LOGIN_TYPE type;
    switch (indexPath.row) {
        case 0:
            type=SINA;
            break;
        case 1:
            type=QQ;
            break;
        case 2:
            type=RENREN;
            break;
        default:
            break;
    }
    if (_checkPWD.selected) {
        KwConfig::GetConfigureInstance()->SetConfigBoolValue(USER_GROUP, USER_AUTOLOGIN, true);
    }
    else {
        KwConfig::GetConfigureInstance()->SetConfigBoolValue(USER_GROUP, USER_AUTOLOGIN, false);
    }
    
    KSOtherLoginViewController *ologinController=[[[KSOtherLoginViewController alloc] initWithType:type] autorelease];
    [ROOT_NAVAGATION_CONTROLLER pushViewController:ologinController animated:true];
}
-(void)ReturnBtnClick:(id)sender
{
    [self.navigationController popViewControllerAnimated:true];
}
-(void)pwdcheckboxClik:(UIButton*)btn
{
    btn.selected=!btn.selected;
}
-(void)RegisterBtnClick:(id)sender
{
    RegistViewController *registController=[[RegistViewController alloc] init];
    [ROOT_NAVAGATION_CONTROLLER pushViewController:registController animated:YES];
    [registController release];
}
#pragma 
#pragma mark tableViewDataSource

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger num(0);
    switch (section) {
        case 0:
            num=2;
            break;
        case 1:
            num=3;
            break;
        default:
            break;
    }
    return num;
}
-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger sec=indexPath.section;
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"LoginCell"];
    switch (sec) {
        case 0:
        {
            if (cell==nil) {
                cell=[[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LoginCell"] autorelease];
                cell.selectionStyle=UITableViewCellSelectionStyleNone;
            }
            else {
                UIView * viewToCheck=[cell.contentView viewWithTag:ViewTag];
                if (viewToCheck) {
                    [viewToCheck removeFromSuperview];
                }
            }
            UITextField *textField=[dataSource objectAtIndex:[indexPath row]];
            [cell.contentView addSubview:textField];

        }
            break;
        case 1:
        {
            if (cell==nil) {
                cell=[[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LoginCell"] autorelease];
                cell.selectionStyle=UITableViewCellSelectionStyleNone;
            }
            else {
                UIView * viewToCheck=[cell.contentView viewWithTag:ViewTag];
                if (viewToCheck) {
                    [viewToCheck removeFromSuperview];
                }
            }
            UIImageView *image=[[[UIImageView alloc] initWithFrame:CGRectMake(10, 5, 30, 30)] autorelease];
            UILabel *label=[[[UILabel alloc] initWithFrame:CGRectMake(80, 0, 200, 40)] autorelease];
            [label setBackgroundColor:[UIColor clearColor]];
            [label setFont:[UIFont systemFontOfSize:18.0]];
            if (indexPath.row == 0) {
                //sina
                [image setImage:CImageMgr::GetImageEx("sinaImage")];
                [label setText:@"用新浪微博登录"];
            }
            else if(indexPath.row == 1){
                [image setImage:CImageMgr::GetImageEx("qqImage")];
                [label setText:@"用QQ账号登录"];
            }
//            else if (indexPath.row == 2){
//                [image setImage:CImageMgr::GetImageEx("tencentShare.png")];
//                [label setText:@"用腾讯微博登录"];
//            }
            else if(indexPath.row == 2){
                [image setImage:CImageMgr::GetImageEx("renrenShare.png")];
                [label setText:@"用人人账号登录"];
            }
            [cell.contentView addSubview:image];
            [cell.contentView addSubview:label];
        }
            break;
        default:
            break;
    }
    return cell;
}
-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == 0) {
        return 100;
    }
    else
        return 0;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1) {
        [self doLoginWithIndex:indexPath];
    }
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 43.5;
}
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    [self.userName resignFirstResponder];
    [self.passWord resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
	return YES;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(UITextField*)userName{
    if (_userName == nil) {
        CGRect frame = CGRectMake(10,10, 285, 30);
		_userName = [[UITextField alloc] initWithFrame:frame];
		
		_userName.borderStyle = UITextBorderStyleNone;//UITextBorderStyleLine;
		_userName.textColor = [UIColor blackColor];
		_userName.font = [UIFont systemFontOfSize:16.0];
        _userName.textAlignment = UITextAlignmentLeft;
        _userName.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		_userName.placeholder = @"请输入酷我账号";
		_userName.backgroundColor = [UIColor clearColor];
		_userName.autocorrectionType = UITextAutocorrectionTypeNo;	// no auto correction support
		_userName.autocapitalizationType = UITextAutocapitalizationTypeNone;
		_userName.keyboardType = UIKeyboardTypeDefault;
		_userName.returnKeyType = UIReturnKeyDone;
		
		_userName.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x' button to the right
		
		_userName.tag = ViewTag;		// tag this control so we can remove it later for recycled cells
		
		_userName.delegate = self;	// let us be the delegate so we know when the keyboard's "Done" button is pressed
		

        CGRect rect = CGRectMake(0, 0, 85, 44);
        UILabel* tmp = [[[UILabel alloc] initWithFrame:rect] autorelease ];
        tmp.backgroundColor = [UIColor clearColor];
        //tmp.font = [UIFont skinFontOfSize:16];
        [tmp setText:@"酷我账号:"];
        
        _userName.leftView = tmp;
        _userName.leftViewMode = UITextFieldViewModeAlways;
        
        string setName;
        int lastLogin(0);
        KwConfig::GetConfigureInstance()->GetConfigStringValue(USER_GROUP, USER_NAME, setName);
        KwConfig::GetConfigureInstance()->GetConfigIntValue(USER_GROUP, USER_LASTLOGIN, lastLogin);
        if(setName.length() > 0 && lastLogin == KUWO)
        {
            [_userName setText:[NSString stringWithUTF8String:setName.c_str()]];
        }

    }
    return _userName;
}
-(UITextField*)passWord{
    if (_passWord == nil) {
        CGRect frame = CGRectMake(10 ,10, 285, 30);
		_passWord = [[UITextField alloc] initWithFrame:frame];
		
		_passWord.borderStyle = UITextBorderStyleNone;//UITextBorderStyleRoundedRect;
		_passWord.textColor = [UIColor blackColor];
		_passWord.font = [UIFont systemFontOfSize:16.0];
        _passWord.textAlignment = UITextAlignmentLeft;
        _passWord.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		_passWord.placeholder = @"请输入密码";
		_passWord.backgroundColor = [UIColor clearColor];
		_passWord.autocorrectionType = UITextAutocorrectionTypeNo;	// no auto correction support
		_passWord.autocapitalizationType = UITextAutocapitalizationTypeNone;
		_passWord.keyboardType = UIKeyboardTypeASCIICapable;
		_passWord.returnKeyType = UIReturnKeyDone;
		_passWord.secureTextEntry = YES;
		_passWord.clearButtonMode = UITextFieldViewModeWhileEditing;	// has a clear 'x' button to the right
		
		_passWord.tag = ViewTag;		// tag this control so we can remove it later for recycled cells
		
		_passWord.delegate = self;	// let us be the delegate so we know when the keyboard's "Done" button is pressed
		

        CGRect rect = CGRectMake(0, 0, 85, 44);
        UILabel* tmp = [[[UILabel alloc] initWithFrame:rect] autorelease ];
        tmp.backgroundColor = [UIColor clearColor];
        //tmp.font = [UIFont skinFontOfSize:16];
        [tmp setText:@"酷我密码:"];
        _passWord.leftView = tmp;
        _passWord.leftViewMode = UITextFieldViewModeAlways;
        
        string base64Pwd;
        int lastLogin(0);
        KwConfig::GetConfigureInstance()->GetConfigStringValue(USER_GROUP, USER_PWD, base64Pwd);
        KwConfig::GetConfigureInstance()->GetConfigIntValue(USER_GROUP, USER_LASTLOGIN, lastLogin);
        //decode pwd
        int nLength=KwTools::Base64::Base64DecodeLength(base64Pwd.length());
        char *pDecodePwd=new char[nLength];
        memset(pDecodePwd, 0, nLength);
        KwTools::Base64::Base64Decode(base64Pwd.c_str(), base64Pwd.length(), pDecodePwd, nLength);
        string password(pDecodePwd,nLength);
        delete []pDecodePwd;

        if (password.length()>0 && lastLogin == KUWO) {

            [_passWord setText:[NSString stringWithUTF8String:password.c_str()]];
        }
    }
    return _passWord;
}

-(void)loginClicked
{
    if (CHttpRequest::GetNetWorkStatus() == NETSTATUS_NONE) {
        UIAlertView * alertView=[[[UIAlertView alloc] initWithTitle:@"提示" message:@"没有网络连接" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil] autorelease];
        [alertView show];
        return;
    }
    
    if (_checkPWD.selected) {
        KwConfig::GetConfigureInstance()->SetConfigBoolValue(USER_GROUP, USER_AUTOLOGIN, true);
    }
    else {
        KwConfig::GetConfigureInstance()->SetConfigBoolValue(USER_GROUP, USER_AUTOLOGIN, false);
    }
    
    NSString* name=[[self userName] text];
    NSString* pwd=[[self passWord] text];
    if ([name length]==0) {
        UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"提示" message:@"请输入账号" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] autorelease];
        [alert show];
        [self.userName becomeFirstResponder];
        return;
    }
    if ([pwd length]==0) {
        UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"提示" message:@"请输入密码" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] autorelease];
        [alert show];
        [self.passWord becomeFirstResponder];
        return;
    }
//    NSString* regEx = @"^[a-zA-Z0-9\\u4e00-\\u9fa5]+$";//汉字，字母，数字
//    if(![self.userName.text isMatchedByRegex:regEx] || 
//       [self.userName.text length] > 20 || 
//       [self.userName.text length] <2)
//    {
//        UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"提示" message:@"请输入正确账号" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] autorelease];
//        [alert show];
//        [self.userName becomeFirstResponder];
//        return;
//    }
//    NSString * numRegEx = @"^\\d";//数字开头
//    if([self.userName.text isMatchedByRegex:numRegEx])
//    {
//        UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"提示" message:@"请输入正确账号" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] autorelease];
//        [alert show];
//        [self.userName becomeFirstResponder];
//        return;
//    }
    if( [self.passWord.text length] < 6 || [self.passWord.text length] > 16)
    {
        UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"提示" message:@"请输入6-16位密码" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] autorelease];
        [alert show];
        [self.passWord becomeFirstResponder];
        return;
    }

    [_waitingDialog show];
    
    NSString *uName=[[self userName] text];
    NSString *uPwd=[[self passWord] text];
    KS_BLOCK_DECLARE
    {
        User::GetUserInstance()->setUserName(uName);
        User::GetUserInstance()->setUserPwd(uPwd);
        LOGIN_RES res=User::GetUserInstance()->Login();
        KS_BLOCK_DECLARE{
            [_waitingDialog dismissWithClickedButtonIndex:0 animated:NO];
            if (res == SUCCESS) {
                [[[[iToast makeText:NSLocalizedString(@"登录成功", @"")]setGravity:iToastGravityCenter] setDuration:2000] show];
                [self.navigationController popViewControllerAnimated:YES];
            }
            else if(res == USER_NOT_EXIST)
            {
                UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"登录结果" message:@"用户名不存在" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] autorelease];
                [alert show];
                [self.userName becomeFirstResponder];
            }
            else if (res == PWD_ERROE) {
                UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"登录结果" message:@"密码错误" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] autorelease];
                [alert show];
                [self.passWord becomeFirstResponder];
            }
            else if (res == LINK_ERROE) {
                UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"登录结果" message:@"连接失败,请稍后再试" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] autorelease];
                [alert show];
            }
            else if (res == OTHER_ERROE){
                UIAlertView *alert=[[[UIAlertView alloc] initWithTitle:@"登录结果" message:@"系统错误,请稍后再试" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil] autorelease];
                [alert show];
            }
        }
        KS_BLOCK_SYNRUN();
    }
    KS_BLOCK_RUN_THREAD();
}

-(void)dealloc
{
    [dataSource release];
    [_userName release];
    [_passWord release];
    [_checkPWD release];
    [myTableView release];
    [_waitingDialog release];
    [super dealloc];
}
@end
