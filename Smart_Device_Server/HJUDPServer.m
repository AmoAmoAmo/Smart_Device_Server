//
//  HJUDPServer.m
//  Smart_Device_Server
//
//  Created by Josie on 2017/9/19.
//  Copyright © 2017年 Josie. All rights reserved.
//
//  服务器不会主动向客户端发送消息
//  接收广播包时，服务器和客户端都必须已连接在同一个局域网内

#import "HJUDPServer.h"
#import "UnixInterfaceDefine.h"
#import "UDPSearchDefine.h"
#import "HeaderDefine.h"

@interface HJUDPServer()
{
    BOOL                m_recvSignal;
    int                 m_sockfd;
//    struct sockaddr_in  m_serveraddr ;
    struct sockaddr_in  m_clientaddr ;
}
@end

@implementation HJUDPServer

- (instancetype)init
{
    self = [super init];
    if (self) {
        m_recvSignal = true;
        m_sockfd = -1;
    }
    return self;
}


-(int)startUDPSearchServiceWithBlock:(ReturnRecvDataBlock)block
{
    self.returnDataBlock = block;
    m_recvSignal = true;
    
    
    // 1. socket
    int  ret = -1;
    struct sockaddr_in serveraddr = {0};
    
    m_sockfd = socket(AF_INET, SOCK_DGRAM, 0);  // *** SOCK_DGRAM -> UDP ****
    if (m_sockfd < 0) {
        perror("sockfd error :");
        return -1;
    }
    
    
    // 2. bind
    bzero(&serveraddr, sizeof(serveraddr));
    serveraddr.sin_family = AF_INET;
    serveraddr.sin_port = htons(MY_PORT);
    serveraddr.sin_addr.s_addr = htonl(INADDR_ANY); // 也可直接 = INADDR_BROADCAST
    
    ret = bind(m_sockfd, (const struct sockaddr *)&serveraddr, sizeof(serveraddr));
    if (ret < 0) {
        perror("bind error :");
        return -1;
    }
    printf("bind success, 准备就绪\n");
    
    // 开一个线程 去阻塞client来连接
    [NSThread detachNewThreadSelector:@selector(startServiceThread) toTarget:self withObject:nil];
    printf("startUDPService, socketfd = %d.......\n",m_sockfd);
    
    return 0;
}

-(void)stopUDPService
{
    m_recvSignal = false;
    m_sockfd = -1;
}

-(void)startServiceThread
{
    // 首先一直在阻塞等待client主动来连接
    [self recvDataAndProcess];
    
    // 3. 回复客户端
    [self sendMsgtoClient];
}



// 收到数据包，开始处理它
-(void)recvDataAndProcess
{
    HJ_MsgHeader msgHead;
    memset (&msgHead,0,sizeof(msgHead));
    
    if ([self recvData:(char *)&msgHead length:sizeof(msgHead)]) {
        
        if (msgHead.controlMask==CONTROLLCODE_SEARCH_BROADCAST_REQUEST) {
            
            NSLog(@"RECV:::::IPADDR: %s Port: %d",inet_ntoa(m_clientaddr.sin_addr),htons(m_clientaddr.sin_port));
            
            // 回调
            self.returnDataBlock(true);
        }
    }
}

-(BOOL)sendMsgtoClient
{
    HJ_SearchReply reply;
    memset (&reply,0,sizeof(reply));
    int replyLen = sizeof(reply);
    
    reply.header.controlMask = CONTROLLCODE_SEARCH_BROADCAST_REPLY;
    reply.type = CAMERA_TYPE;
    reply.devID = CAMERA_ID;
    
    if ([self sendData:(char *)&reply length:replyLen]) {
        return true;
    }
    
    return false;
}




-(BOOL)sendData:(char*)pBuf length:(int)length
{
    int sendLen = 0;
    ssize_t nRet = 0;
    socklen_t addrlen = 0;
    
    addrlen = sizeof(m_clientaddr);
    while (sendLen < length) {
        nRet = sendto(m_sockfd, pBuf, length, 0, (struct sockaddr*)&m_clientaddr, addrlen);
        
        if (nRet == -1) {
            perror("sendto error:\n");
            return false;
        }
        printf("发送了%ld个字符\n", nRet);
        sendLen += nRet;
        pBuf += nRet;
    }
    return true;
}

-(BOOL)recvData:(char*)pBuf length:(int)length
{
    int readLen=0;
    long nRet=0;
    socklen_t addrlen = sizeof(m_clientaddr);
    
    while(readLen<length)
    {
        nRet=recvfrom(m_sockfd,pBuf,length-readLen,0,(struct sockaddr*)&m_clientaddr,(socklen_t*)&addrlen);// 一直在搜索 阻塞，直到 接收到服务器的回复，即搜索到设备
        
        if(nRet==-1){
            perror("recvfrom error: \n");
            return false;
        }
        readLen+=nRet;
        pBuf+=nRet;
    }
    return true;
}

@end








