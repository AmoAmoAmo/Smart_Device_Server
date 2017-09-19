//
//  HJH264Encoder.h
//  Smart_Device_Server
//
//  Created by Josie on 2017/9/21.
//  Copyright © 2017年 Josie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface HJH264Encoder : NSObject

-(void)startH264EncodeWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;
-(void)stopH264Encode;

@end
