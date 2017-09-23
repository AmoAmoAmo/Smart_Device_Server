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
#import "HJTCPServer.h"
#import <AVFoundation/AVFoundation.h>
#import "HJH264Encoder.h"


typedef enum : NSUInteger {
    NOTCONNECT,
    WAITING,
    CONNECTED,
} DeviceStatusEnum;

@interface ViewController ()<AVCaptureAudioDataOutputSampleBufferDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>

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

@property (nonatomic, retain) HJTCPServer   *tcpServer;

@property (nonatomic, assign) DeviceStatusEnum  devStatueEnum;



@property (nonatomic, strong)   AVCaptureSession            *avSession;

@property (nonatomic , strong)  AVCaptureVideoDataOutput    *videoOutput; //

@property (nonatomic, strong)   AVCaptureVideoPreviewLayer  *previewLayer;


@property (weak, nonatomic) IBOutlet UIView *captureView;



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // 程序一开始默认TCP没有连接，直到UDP被搜索到 -> self.devStatueEnum = CONNECTED;
    // ***** 测试代码 *****
    self.devStatueEnum = CONNECTED;
    
    // 在子线程里面操作TCP
    [NSThread detachNewThreadSelector:@selector(startTCPServiceThread) toTarget:self withObject:nil];
}

- (IBAction)clickResetBtn:(id)sender {
    
    self.devStatueEnum = NOTCONNECT;
    
    self.label1.text = @"未联网";
    self.label2.text = @"未连接";
    self.imgView1.image = [UIImage imageNamed:@"未连接"];
    self.imgView2.image = [UIImage imageNamed:@"未连接"];
    
    if (self.server) {
        [self stopUDP];
    }
    [self startUDP];
    
    // reset时，TCP应该被停止
    if (self.tcpServer) {
        [self stopTCP];
        self.tcpServer = nil;
    }
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
            
            self.devStatueEnum = CONNECTED;
        });
    }];
    
    // 连接成功就断开UDP
    [self stopUDP];
}

-(void)stopUDP
{
    [self.server stopUDPService];
}


#pragma mark - TCP

-(void)startTCPServiceThread
{
    NSLog(@"---- status = %ld ", self.devStatueEnum);
    if (self.devStatueEnum == CONNECTED) {
        self.tcpServer = [[HJTCPServer alloc] init];
        [self.tcpServer startTCPTransmissionService];
        
//        // $$$$ 测试代码 ￥￥￥￥NSString *str = @"hello world";
//        NSString *str = @"hello world";
//        NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
//        [self.tcpServer sendDataToClientWithData:data];
    }
}
-(void)stopTCP
{
    [self.tcpServer stopTCPTransmissionService];
}


-(void)startCapture
{
    // 显示采集数据的层
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.avSession];
    //    NSLog(@"---- capture width = %f, height = %f ", self.captureView.frame.size.width, self.captureView.frame.size.height);
    self.previewLayer.frame = self.captureView.bounds;
    // 保留纵横比
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [self.captureView.layer insertSublayer:self.previewLayer above:0];    //设置layer插入的位置为above0，也就是图层的最底层的上一层
    
    [self.avSession startRunning];
}






#pragma mark - AVCapture-输出流-Delegate

// 默认情况下，为30 fps，意味着该函数每秒调用30次
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
    // 获取输入设备数据，有可能是音频有可能是视频
    if (captureOutput == self.videoOutput) {
        //捕获到视频数据
        /*
         mediaType:'vide'
         mediaSubType:'420v'     // videoOutput设置成什么类型就是什么类型
         */
        NSLog(@"视频 ---");
        NSLog(@"---- sampleBuffer = %@--", sampleBuffer);
        NSLog(@"==========================================================");
        // 简单打印摄像头输出数据的信息
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        OSType videoType =  CVPixelBufferGetPixelFormatType(pixelBuffer);
        NSLog(@"***** videoType = %d *******",videoType);
        if (CVPixelBufferIsPlanar(pixelBuffer)) {
            NSLog(@"kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange -> planar buffer");
        }
        CMVideoFormatDescriptionRef desc = NULL;
        CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &desc);
        CFDictionaryRef extensions = CMFormatDescriptionGetExtensions(desc);
        NSLog(@"extensions = %@", extensions);
        /*
         extensions = {
         CVBytesPerRow = 964;
         CVImageBufferColorPrimaries = "ITU_R_709_2";
         CVImageBufferTransferFunction = "ITU_R_709_2";
         CVImageBufferYCbCrMatrix = "ITU_R_709_2";      // ITU_R_709_2是HD视频的方案，一般用于YUV422,YUV至RGB的转换矩阵和SD视频（一般是ITU_R_601_4）并不相同。   ******* MacBook摄像头参数为： 720p FaceTime HD摄像头
         Version = 2;
         }
         */
        
        
        
        
    
        
        
        
        
        // 收到数据，开始编码
        HJH264Encoder *videoEncoder = [[HJH264Encoder alloc] init];
        [videoEncoder startH264EncodeWithSampleBuffer:sampleBuffer andReturnData:^(NSData *data) {
            
            // 返回一个编码后的数据 data,传给TCP 开始发送给client
            [self.tcpServer sendDataToClientWithData:data];
        }];
        
        
        
    }
    else
    {
        // 音频
        /*
         mediaType:'soun'
         mediaSubType:'lpcm'
         */
        NSLog(@"--- 音频 ----");
        
        
        
    }
}



#pragma mark - 懒加载

-(AVCaptureSession *)avSession
{
    if (!_avSession) {
        
        _avSession = [[AVCaptureSession alloc] init];
        _avSession.sessionPreset = AVCaptureSessionPreset640x480;
        
        // 设备对象 (audio)
        AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        // 输入流
        AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
        // 输出流
        AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
        [audioOutput setSampleBufferDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        // 添加输入输出流
        if ([_avSession canAddInput:audioInput]) {
            [_avSession addInput:audioInput];
        }
        if ([_avSession canAddOutput:audioOutput]) {
            [_avSession addOutput:audioOutput];
        }
        
        
        
        
        // 设备对象 (video)
        AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        
        // 输入流
        AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
        
        // 输出流
        self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        
        [self.videoOutput setAlwaysDiscardsLateVideoFrames:NO];
        
        //        [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        
        // 帧的大小在这里设置才有效
        self.videoOutput.videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,
                                          [NSNumber numberWithInt: 640], (id)kCVPixelBufferWidthKey,
                                          [NSNumber numberWithInt: 480], (id)kCVPixelBufferHeightKey,
                                          nil];
        /*
         调用次数       CVBytesPerRow
         kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;      （420f）                       1924
         kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ;      420v                        1924            964
         kCVPixelFormatType_422YpCbCr8_yuvs;                    yuvs            30          2560
         kCVPixelFormatType_422YpCbCr8                          2vuy            30          2560
         */
        [self.videoOutput setSampleBufferDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        
        
        
        
        
        // 获取当前设备支持的像素格式
        NSLog(@"-- videoDevice.formats = %@", videoDevice.formats);
        
        //根据设备输出获得连接
        AVCaptureConnection *connection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
        [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
        
        
        
//        // 前置摄像头翻转
//        AVCaptureDevicePosition currentPosition=[[videoInput device] position];
//        if (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionFront) {
//            connection.videoMirrored = YES;
//        } else {
//            connection.videoMirrored = NO;
//        }
        
        
        
        if ([_avSession canAddInput:videoInput]) {
            [_avSession addInput:videoInput];
        }
        if ([_avSession canAddOutput:self.videoOutput]) {
            [_avSession addOutput:self.videoOutput];
        }
        
        
        
    }
    return _avSession;
}

@end
