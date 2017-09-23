//
//  HJH264Encoder.h
//  Smart_Device_Server
//
//  Created by Josie on 2017/9/21.
//  Copyright © 2017年 Josie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef void (^ReturnDataBlock)(NSData *data);

@interface HJH264Encoder : NSObject

@property (nonatomic, copy) ReturnDataBlock returnDataBlock;



-(void)startH264EncodeWithSampleBuffer:(CMSampleBufferRef)sampleBuffer andReturnData:(ReturnDataBlock)block;
-(void)stopH264Encode;

@end
