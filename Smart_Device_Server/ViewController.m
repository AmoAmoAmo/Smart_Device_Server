//
//  ViewController.m
//  Smart_Device_Server
//
//  Created by Josie on 2017/9/18.
//  Copyright © 2017年 Josie. All rights reserved.
//
//  服务端，如果点击重置，则阻塞等待接收UDP广播包


#import "ViewController.h"
#import "HJUDPServer.h"

@interface ViewController ()

/*
  1. 未连接
  2. 等待连接
  3. 已连接
 */
@property (weak, nonatomic) IBOutlet UILabel *label1;
@property (weak, nonatomic) IBOutlet UILabel *label2;
@property (weak, nonatomic) IBOutlet UIImageView *imgView1;
@property (weak, nonatomic) IBOutlet UIImageView *imgView2;

@property (nonatomic, retain) HJUDPServer   *server;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)clickResetBtn:(id)sender {
    
    self.label1.text = @"未联网";
    self.label2.text = @"未连接";
    self.imgView1.image = [UIImage imageNamed:@"未连接"];
    self.imgView2.image = [UIImage imageNamed:@"未连接"];
    
    if (self.server) {
        [self stopUDP];
    }
    [self startUDP];
}

// 阻塞等待接收UDP广播包
-(void)startUDP
{
    
    
    self.server = [[HJUDPServer alloc] init];
    [self.server startUDPSearchServiceWithBlock:^(BOOL isRecv) {
        
        printf("---- 已接收 -----\n");
        self.imgView1.image = [UIImage imageNamed:@"准备"];
        self.label1.text = @"准备";
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.imgView1.image = [UIImage imageNamed:@"已连接"];
            self.label1.text = @"已联网"; // 模拟smart config
        });
    }];
    
}

-(void)stopUDP
{
    [self.server stopUDPService];
}




@end
