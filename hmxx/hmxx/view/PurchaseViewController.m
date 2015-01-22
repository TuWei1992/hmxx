//
//  PurchaseViewController.m
//  hmxx
//
//  Created by yons on 15-1-19.
//  Copyright (c) 2015年 hmzl. All rights reserved.
//

#import "PurchaseViewController.h"
#import "MKNetworkKit.h"
#import "Utils.h"
#import "MBProgressHUD.h"
#import "SRRefreshView.h"
#import "UIImageView+AFNetworking.h"
#import "PurchaseTableViewCell.h"
#import "AddPuchaseViewController.h"
#import "PurchaseTypeViewController.h"

@interface PurchaseViewController ()<MBProgressHUDDelegate,SRRefreshDelegate>{
    MBProgressHUD *HUD;
    MKNetworkEngine *engine;
    NSNumber *totalpage;
    NSNumber *page;
    NSNumber *rows;
    
    BOOL isLoading;
    NSString *schoolid;
}
@property (nonatomic, strong) SRRefreshView *slimeView;
@end

@implementation PurchaseViewController
@synthesize mytableview;
@synthesize dataSource;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.title = @"采买报表";
//    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] init];
//    self.navigationItem.backBarButtonItem = backItem;
//    backItem.title = @"返回";
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
    
    //初始化tableview
    CGRect cg;
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1){
        self.automaticallyAdjustsScrollViewInsets = NO;
        cg = CGRectMake(0, 64, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height-64);
    }else{
        cg = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height-64);
    }
    mytableview = [[UITableView alloc] initWithFrame:cg style:UITableViewStylePlain];
    mytableview.dataSource = self;
    mytableview.delegate = self;
    [self.view addSubview:mytableview];
    [mytableview addSubview:self.slimeView];
    mytableview.separatorStyle = UITableViewCellSeparatorStyleNone;
//    if ([mytableview respondsToSelector:@selector(setSeparatorInset:)]) {
//        [mytableview setSeparatorInset:UIEdgeInsetsZero];
//    }
//    if ([mytableview respondsToSelector:@selector(setLayoutMargins:)]) {
//        [mytableview setLayoutMargins:UIEdgeInsetsZero];
//    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadData)
                                                 name:@"reloadPurchase"
                                               object:nil];
    
    
    UIImage* image= [UIImage imageNamed:@"ic_bwgg_011.png"];
    CGRect frame= CGRectMake(0, 0, 30, 30);
    UIButton* someButton= [[UIButton alloc] initWithFrame:frame];
    [someButton addTarget:self action:@selector(action1) forControlEvents:UIControlEventTouchUpInside];
    [someButton setBackgroundImage:image forState:UIControlStateNormal];
    [someButton setShowsTouchWhenHighlighted:NO];
    UIBarButtonItem *buttonItem1 = [[UIBarButtonItem alloc] initWithCustomView:someButton];
    [self.navigationItem setRightBarButtonItem:buttonItem1];
    
    isLoading = NO;
    
    //添加加载等待条
    HUD = [[MBProgressHUD alloc] initWithView:self.view];
    HUD.labelText = @"加载中...";
    [self.view addSubview:HUD];
    HUD.delegate = self;
    [HUD show:YES];
    
    engine = [[MKNetworkEngine alloc] initWithHostName:[Utils getHostname] customHeaderFields:nil];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    schoolid = [userDefaults objectForKey:@"schoolid"];
    self.dataSource = [[NSMutableArray alloc] init];
    
    //初始化数据
    [self loadData];
}

#pragma mark - getter

- (SRRefreshView *)slimeView
{
    if (!_slimeView) {
        _slimeView = [[SRRefreshView alloc] init];
        _slimeView.delegate = self;
        _slimeView.upInset = 0;
        _slimeView.slimeMissWhenGoingBack = YES;
        _slimeView.slime.bodyColor = [UIColor grayColor];
        _slimeView.slime.skinColor = [UIColor grayColor];
        _slimeView.slime.lineWith = 1;
        _slimeView.slime.shadowBlur = 4;
        _slimeView.slime.shadowColor = [UIColor grayColor];
        _slimeView.backgroundColor = [UIColor whiteColor];
    }
    
    return _slimeView;
}

//加载数据
- (void)loadData{
    
    page = [NSNumber numberWithInt:1];
    rows = [NSNumber numberWithInt:10];
    
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setValue:schoolid forKey:@"schoolId"];
    [dic setValue:page forKey:@"page"];
    [dic setValue:rows forKey:@"rows"];
    //    [dic setValue:classId forKey:@"classId"];
    MKNetworkOperation *op = [engine operationWithPath:@"/purchase/purchaseList.do" params:dic httpMethod:@"GET"];
    [op addCompletionHandler:^(MKNetworkOperation *operation) {
        NSString *result = [operation responseString];
        NSError *error;
        NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
        if (resultDict == nil) {
            NSLog(@"json parse failed \r\n");
        }
        NSNumber *success = [resultDict objectForKey:@"success"];
        NSString *msg = [resultDict objectForKey:@"msg"];
        if ([success boolValue]) {
            NSDictionary *data = [resultDict objectForKey:@"data"];
            if (data != nil) {
                NSArray *arr = [data objectForKey:@"rows"];
                self.dataSource = [NSMutableArray arrayWithArray:arr];
                NSNumber *total = [data objectForKey:@"total"];
                if ([total intValue] % [rows intValue] == 0) {
                    totalpage = [NSNumber numberWithInt:[total intValue] / [rows intValue]];
                }else{
                    totalpage = [NSNumber numberWithInt:[total intValue] / [rows intValue] + 1];
                }
                [mytableview reloadData];
            }
            [HUD hide:YES];
        }else{
            [HUD hide:YES];
            [self alertMsg:msg];
            
        }
    }errorHandler:^(MKNetworkOperation *errorOp, NSError* err) {
        NSLog(@"MKNetwork request error : %@", [err localizedDescription]);
        [HUD hide:YES];
        [self alertMsg:@"连接失败"];
    }];
    [engine enqueueOperation:op];
}

- (void)loadMore{
    isLoading = YES;
    if ([page intValue] < [totalpage intValue]) {
        page = [NSNumber numberWithInt:[page intValue] +1];
    }
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setValue:schoolid forKey:@"schoolId"];
    [dic setValue:page forKey:@"page"];
    [dic setValue:rows forKey:@"rows"];
    
    MKNetworkOperation *op = [engine operationWithPath:@"/purchase/purchaseList.do" params:dic httpMethod:@"GET"];
    [op addCompletionHandler:^(MKNetworkOperation *operation) {
        NSString *result = [operation responseString];
        NSError *error;
        NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
        if (resultDict == nil) {
            NSLog(@"json parse failed \r\n");
        }
        NSNumber *success = [resultDict objectForKey:@"success"];
        NSString *msg = [resultDict objectForKey:@"msg"];
        if ([success boolValue]) {
            NSDictionary *data = [resultDict objectForKey:@"data"];
            if (data != nil) {
                NSArray *arr = [data objectForKey:@"rows"];
                [self.dataSource addObjectsFromArray:arr];
                NSNumber *total = [data objectForKey:@"total"];
                if ([total intValue] % [rows intValue] == 0) {
                    totalpage = [NSNumber numberWithInt:[total intValue] / [rows intValue]];
                }else{
                    totalpage = [NSNumber numberWithInt:[total intValue] / [rows intValue] + 1];
                }
                [mytableview reloadData];
            }
            isLoading = NO;
            [HUD hide:YES];
        }else{
            isLoading = NO;
            [HUD hide:YES];
            [self alertMsg:msg];
            
        }
    }errorHandler:^(MKNetworkOperation *errorOp, NSError* err) {
        NSLog(@"MKNetwork request error : %@", [err localizedDescription]);
        isLoading = NO;
        [HUD hide:YES];
        [self alertMsg:@"连接失败"];
    }];
    [engine enqueueOperation:op];
}

//成功
- (void)okMsk:(NSString *)msg{
    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
    [self.navigationController.view addSubview:hud];
    hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
    hud.mode = MBProgressHUDModeCustomView;
    hud.delegate = self;
    hud.labelText = msg;
    [hud show:YES];
    [hud hide:YES afterDelay:1.5];
}


//提示
- (void)alertMsg:(NSString *)msg{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.labelText = msg;
    hud.margin = 10.f;
    hud.removeFromSuperViewOnHide = YES;
    [hud hide:YES afterDelay:1.5];
}


#pragma mark - UITableViewDatasource Methods
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (page != totalpage && [self.dataSource count] != 0) {
        return [[self dataSource] count] + 1;
    }else{
        return [[self dataSource] count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if ([self.dataSource count] == indexPath.row) {
        static NSString *cellIdentifier = @"morecell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.textLabel.text = @"显示下10条";
            [cell.textLabel setFont:[UIFont systemFontOfSize:15]];
            [cell.textLabel setTextColor:[UIColor grayColor]];
        }
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        return cell;
        
    }else{
        static NSString *cellIdentifier = @"purchasecell";
        PurchaseTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[[NSBundle mainBundle] loadNibNamed:@"PurchaseTableViewCell" owner:self options:nil] lastObject];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        NSDictionary *info = [self.dataSource objectAtIndex:indexPath.row];
        NSString *purchaseDate = [info objectForKey:@"purchaseDate"];
        
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        NSDate *date = [dateFormatter dateFromString:purchaseDate];
        NSDateFormatter *dateFormatter2 = [[NSDateFormatter alloc] init];
        [dateFormatter2 setDateFormat:@"yyyy年MM月dd日"];
        NSString *date2 = [dateFormatter2 stringFromDate:date];
        
        NSString *creator = [info objectForKey:@"creator"];
//        NSString *create_date = [info objectForKey:@"createDate"];
        NSNumber *total_price = [info objectForKey:@"total_price"];
        
        cell.dateLabel.text = date2;
        cell.createrLabel.text = [NSString stringWithFormat:@"%@",creator];
        
        cell.moneyLabel.text = [NSString stringWithFormat:@"￥%.2f",[total_price doubleValue]];
        return cell;
    }

}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    if ([self.dataSource count] == indexPath.row) {
        return 55;
    }else{
        return 53;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
//
//    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
//        [cell setSeparatorInset:UIEdgeInsetsZero];
//    }
//    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
//        [cell setLayoutMargins:UIEdgeInsetsZero];
//    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
        if ([self.dataSource count] == indexPath.row) {
            if (page == totalpage) {
    
            }else{
                [HUD show:YES];
                [self loadMore];
            }
    
        }else{
    if (indexPath.row < [self.dataSource count]) {
        NSDictionary *info = [self.dataSource objectAtIndex:indexPath.row];
        NSString *purchaseDate = [info objectForKey:@"purchaseDate"];
        PurchaseTypeViewController *vc = [[PurchaseTypeViewController alloc] init];
        vc.purchaseDate = purchaseDate;
        vc.title = purchaseDate;
        [self.navigationController pushViewController:vc animated:YES];
    }
    
        }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - scrollView delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [_slimeView scrollViewDidScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [_slimeView scrollViewDidEndDraging];
}

#pragma mark - slimeRefresh delegate
//刷新消息列表
- (void)slimeRefreshStartRefresh:(SRRefreshView *)refreshView
{
    [HUD show:YES];
    [self loadData];
    [_slimeView endRefresh];
}

-(void)action1{
    AddPuchaseViewController *vc = [[AddPuchaseViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
