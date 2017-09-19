//
//  HJUDPServer.h
//  Smart_Device_Server
//
//  Created by Josie on 2017/9/19.
//  Copyright © 2017年 Josie. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^ReturnRecvDataBlock) (BOOL isRecv);

@interface HJUDPServer : NSObject

@property (nonatomic, copy) ReturnRecvDataBlock returnDataBlock;

-(int)startUDPSearchServiceWithBlock:(ReturnRecvDataBlock)block;
-(void)stopUDPService;

@end
