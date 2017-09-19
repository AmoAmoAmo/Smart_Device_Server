//
//  HeaderDefine.h
//  Smart_Device_Client
//
//  Created by Josie on 2017/9/18.
//  Copyright © 2017年 Josie. All rights reserved.
//

#ifndef HeaderDefine_h
#define HeaderDefine_h

#define     INT8           unsigned char
#define     INT16          unsigned short
#define     INT32          unsigned int


#define SCREENWIDTH [UIScreen mainScreen].bounds.size.width
#define SCREENHEIGHT [UIScreen mainScreen].bounds.size.height

#define CELLWIDTH 120


static INT16        CURTAIN_TYPE        = 1  ; // 窗帘type
static INT16        CAMERA_TYPE         = 0  ; // 监控
static INT16        LIGHT_TYPE          = 2  ; // 电灯
static INT16        AIRCONDITION_TYPE   = 3  ; // 空调
static INT16        SOCKET_TYPE         = 4  ; // 插座

// 假设已添加摄像头ID为12345
static INT16        CAMERA_ID = 12345;


#endif /* HeaderDefine_h */
