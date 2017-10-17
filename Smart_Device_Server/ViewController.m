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
#import "AACEncoder.h"

typedef enum : NSUInteger {
    NOTCONNECT,
    WAITING,
    CONNECTED,
} DeviceStatusEnum;

@interface ViewController ()<AVCaptureAudioDataOutputSampleBufferDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>
{
    dispatch_queue_t mEncodeQueue;
}
@property (weak, nonatomic) IBOutlet UILabel *label1;
@property (weak, nonatomic) IBOutlet UILabel *label2;
@property (weak, nonatomic) IBOutlet UIImageView *imgView1;
@property (weak, nonatomic) IBOutlet UIImageView *imgView2;

@property (nonatomic, retain) HJUDPServer   *server;

@property (nonatomic, retain) HJTCPServer   *tcpServer;

@property (nonatomic, assign) DeviceStatusEnum  devStatueEnum;

@property (nonatomic, retain) HJH264Encoder *videoEncoder;

@property (nonatomic , strong) AACEncoder *audioEncoder;

@property (nonatomic, strong)   AVCaptureSession            *avSession;

@property (nonatomic , strong)  AVCaptureVideoDataOutput    *videoOutput; //

@property (nonatomic, strong)   AVCaptureVideoPreviewLayer  *previewLayer;


@property (weak, nonatomic) IBOutlet UIView *captureView;

@property (nonatomic, assign) BOOL isReadyToEncode;


@property (nonatomic, strong) NSFileHandle *fileHandle;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // 程序一开始默认TCP没有连接，直到UDP被搜索到 -> self.devStatueEnum = CONNECTED;
    // ***** 测试代码 *****
    self.devStatueEnum = CONNECTED;
    
    self.isReadyToEncode = false;
    
    [self initSession];
    
    [self startDataTransmissionByTCP];
    
    
//    [self outputTest];
}



-(void)outputTest
{
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"abc.h264"];
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
}


- (IBAction)clickResetBtn:(id)sender {
    
    self.devStatueEnum = NOTCONNECT;
    
    self.label1.text = @"未联网";
    self.label2.text = @"未连接";
    self.imgView1.image = [UIImage imageNamed:@"未连接"];
    self.imgView2.image = [UIImage imageNamed:@"未连接"];
    
    // reset时，停止capture
    [self.avSession stopRunning];
    
    // reset时，TCP应该被停止
    if (self.tcpServer) {
        [self stopTCP];
        self.tcpServer = nil;
    }
//    // 编码也应该停止
//    if (self.videoEncoder) {
//        [self.videoEncoder stopH264Encode];
//        self.videoEncoder = nil;
//    }
    
    if (self.server) {
        [self stopUDP];
    }
    
    [self startUDP];
    // 连接成功就断开UDP
    [self stopUDP];
    // UDP结束后，应该开启TCP传送数据
    [self startDataTransmissionByTCP];
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
    
    
}

-(void)stopUDP
{
    [self.server stopUDPService];
}


#pragma mark - TCP
-(void)startDataTransmissionByTCP
{
    // 在子线程里面操作TCP
    [NSThread detachNewThreadSelector:@selector(startTCPServiceThread) toTarget:self withObject:nil];
    
    // 一开始就开始捕获视频
    [self startCapture];
}


-(void)startTCPServiceThread
{
//    NSLog(@"---- status = %ld ", (unsigned long)self.devStatueEnum);
    if (self.devStatueEnum == CONNECTED) {
        self.tcpServer = [[HJTCPServer alloc] init];
        // 收到client的视频请求
        [self.tcpServer startTCPTransmissionServiceAndReturnReadySignal:^(BOOL isReady) {
            if (isReady) {
                // 可以开始编码的信号
                self.isReadyToEncode = true;
            }
        }];
    }
}
-(void)stopTCP
{
    [self.tcpServer stopTCPTransmissionService];
}

// 初始化Session
-(void)initSession
{
    mEncodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    self.avSession = [[AVCaptureSession alloc] init];
    self.avSession.sessionPreset = AVCaptureSessionPreset640x480;
    
    
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
    AVCaptureDevice *inputCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == AVCaptureDevicePositionBack)
        {
            inputCamera = device;
        }
    }
    
    AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:inputCamera error:nil];
    
    if ([self.avSession canAddInput:videoInput]) {
        [self.avSession addInput:videoInput];
    }
    
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoOutput setAlwaysDiscardsLateVideoFrames:NO];  // 是否抛弃延迟的帧：NO
    
    [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [self.videoOutput setSampleBufferDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    if ([self.avSession canAddOutput:self.videoOutput]) {
        [self.avSession addOutput:self.videoOutput];
    }
    AVCaptureConnection *connection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight]; // 因为要横屏，所以让输出视频图像旋转90°
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.avSession];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [[self.previewLayer connection] setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];// 预览层也让它右转90°
    [self.previewLayer setFrame:self.captureView.bounds];
    [self.captureView.layer insertSublayer:self.previewLayer above:0];
    

    
    self.videoEncoder = [[HJH264Encoder alloc] init];
    self.audioEncoder = [[AACEncoder alloc] init];
}

-(void)startCapture
{
    [self.avSession startRunning];
}




#pragma mark - AVCapture-输出流-Delegate

// 默认情况下，为30 fps，意味着该函数每秒调用30次
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
    // 获取输入设备数据，有可能是音频有可能是视频
    if (captureOutput == self.videoOutput) {

//        // 测试代码
//        [self.videoEncoder startH264EncodeWithSampleBuffer:sampleBuffer andReturnData:^(NSData *data) {
//            
//            [_fileHandle writeData:data];
//        }];
        
        
        
        
//        // 当TCP需要开始传输数据时，开始编码
//        if (self.isReadyToVideoEncode) {
//            // 收到数据，开始编码
//            [self.videoEncoder startH264EncodeWithSampleBuffer:sampleBuffer andReturnData:^(NSData *data) {
//                
//                // 返回一个编码后的数据 data,传给TCP 开始发送给client
//                [self.tcpServer sendVideoDataToClientWithData:data];
//                
//            }];
//        }
        
        
        // ---------- test ---------
        // 收到数据，开始编码
        [self.videoEncoder startH264EncodeWithSampleBuffer:sampleBuffer andReturnData:^(NSData *data) {

            // 当TCP需要开始传输数据时，开始传编码后的数据
            if (self.isReadyToEncode) {
                // 返回一个编码后的数据 data,传给TCP 开始发送给client
                [self.tcpServer sendVideoDataToClientWithData:data];
            }
        }];
        

    }
    else
    {
        // 音频
        dispatch_sync(mEncodeQueue, ^{
            // block回调 返回编码后的音频数据
//            printf("----- audio -------\n");
            [self.audioEncoder encodeSampleBuffer:sampleBuffer completionBlock:^(NSData *encodedData, NSError *error) {
                printf("----- Audio encodedData length = %d ----- \n", (int)[encodedData length]);
                // 写入socket
                if (self.isReadyToEncode) {
                    [self.tcpServer sendAudioDataToClientWithData:encodedData];
                }
            }];
        });
        
        
        
    }
}



#pragma mark - 懒加载


//-(HJH264Encoder *)videoEncoder
//{
//    if (!_videoEncoder) {
//        _videoEncoder = [[HJH264Encoder alloc] init];
//    }
//    return _videoEncoder;
//}



@end
