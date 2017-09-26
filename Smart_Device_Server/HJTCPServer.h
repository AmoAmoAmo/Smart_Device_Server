//
//  HJTCPServer.h
//  Smart_Device_Server
//
//  Created by Josie on 2017/9/20.
//  Copyright © 2017年 Josie. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^ReturnReadySignalBlock) (BOOL isReady); // 可以准备编码了

@interface HJTCPServer : NSObject

@property (nonatomic, copy) ReturnReadySignalBlock readyBlock;

-(void)startTCPTransmissionServiceAndReturnReadySignal:(ReturnReadySignalBlock)block;
-(void)sendDataToClientWithData:(NSData*)data; // 收到编码后的数据，发送给客户端
-(void)stopTCPTransmissionService;

@end
