//
//  HJTCPServer.h
//  Smart_Device_Server
//
//  Created by Josie on 2017/9/20.
//  Copyright © 2017年 Josie. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HJTCPServer : NSObject

-(void)startTCPTransmissionService;
-(void)sendDataToClientWithData:(NSData*)data; // 收到编码后的数据，发送给客户端
-(void)stopTCPTransmissionService;

@end
