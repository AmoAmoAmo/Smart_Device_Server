//
//  HJTCPServer.m
//  Smart_Device_Server
//
//  Created by Josie on 2017/9/20.
//  Copyright © 2017年 Josie. All rights reserved.
//
//  client 用双socket通道的话，server也要用两个socketfd

#import "HJTCPServer.h"
#import "UnixInterfaceDefine.h"
#import "TCPSocketDefine.h"

pthread_mutex_t  mutex_cRecv=PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t  mutex_cSend=PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t  mutex_dRecv=PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t  mutex_dSend=PTHREAD_MUTEX_INITIALIZER;


@interface HJTCPServer()
{
    int     m_connectfd;
    BOOL    canSendData;
    
    struct sockaddr_in m_clientaddr;
}
@end

@implementation HJTCPServer

- (instancetype)init
{
    self = [super init];
    if (self) {
        m_connectfd = -1;
        canSendData = false;
    }
    return self;
}

-(void)startTCPTransmissionServiceAndReturnReadySignal:(ReturnReadySignalBlock)block
{
    self.readyBlock = block;
    
    int ret = [self initSocket];
    if (ret == 0) {
        
        // 阻塞，直到客户端来连接
        if ([self recvTransRequest]) {
            printf("------- 准备..传输音视频数据 ---------\n");
            canSendData = true;
            // block
            self.readyBlock(true);
        }
    }
}

-(int)initSocket
{
    struct sockaddr_in my_serveraddr = {0};
    bzero(&m_clientaddr,sizeof(struct sockaddr_in));
    socklen_t len = 0;
    
    
    // 1. 打开文件描述符
    int listenfd = -1, ret = -1;
    listenfd = socket(AF_INET, SOCK_STREAM, 0);
    
    if (listenfd < 0 ) {
        perror("sockfd error:");
        return -1;
    }
    printf("tcp listenfd = %d\n", listenfd);
    
    
    
    
    
    // 2. bind
    
    my_serveraddr.sin_family = AF_INET;                   // IPV4
    my_serveraddr.sin_port = htons(MY_PORT);              // 服务器端口号 数字 正整数 保证在当前电脑中是唯一的，是自己定义的，大于5000就可以; 考虑字节序
    my_serveraddr.sin_addr.s_addr = htonl(INADDR_ANY);
    ret = bind(listenfd, (const struct sockaddr *)&my_serveraddr, sizeof(my_serveraddr));
    if (ret < 0) {
        perror("tcp bind error:");
        return -1;
    }
    printf("tcp bind success\n");
    
    
    
    // 3. listen 监听端口
    ret =  listen(listenfd, BACKLOG);  // BACKLOG 挂起连接队列的最大长度
    if (ret < 0) {
        perror("tcp listen error:");
        return -1;
    }
    printf("****** tcp listen *********\n");
    
    
    
    // 4. accept 阻塞等待客户
    m_connectfd = accept(listenfd, (struct sockaddr *)&m_clientaddr, &len); // 阻塞，直到客户端来连接
    if (m_connectfd < 0) {
        perror("tcp listen error:");
        return -1;
    }
    printf("------- tcp accept成功 -------, fd = %d\n", m_connectfd);
    // 连接成功后会返回，通过my_clientaddr变量就可知道是哪个来连接服务器, 进而建立通信。通过connectfd来和客户端进行读写操作
//    printf("======= tcp accept--------- Address:%s\n",inet_ntoa(m_clientaddr.sin_addr));
    
    
    
    struct timeval timeout = {10,0};
    
    if(setsockopt(m_connectfd, SOL_SOCKET, SO_SNDTIMEO, (const char *)&timeout, sizeof(struct timeval)))
    {
        return -1;
    }
    if(setsockopt(m_connectfd, SOL_SOCKET, SO_RCVTIMEO, (const char *)&timeout, sizeof(struct timeval) ))
    {
        return -1;
    }
    
    
    return 0;
}



-(void)stopTCPTransmissionService
{
    canSendData = false;
    if (m_connectfd > 0) {
        close(m_connectfd);
    }
    printf("---------- TCP已断开 -----------\n");
}


-(void)sendVideoDataToClientWithData:(NSData*)data
{
    // NSData 转Byte
    Byte *myByte = (Byte *)[data bytes];
    printf("=== send video dataLen = %d\n", (int)[data length]);
    
//    NSUInteger len = [data length];
//    for (int i=0; i<len; i++){
//        printf("%02x", myByte[i]);
//    }
//    printf("\n");
    
    if (canSendData) {
        
        // 打包成一个结构体
        HJ_VideoDataContent dataContent;
        memset((void *)&dataContent, 0, sizeof(dataContent));
        
        dataContent.msgHeader.controlMask = CODECONTROLL_VIDEOTRANS_REPLY;
        dataContent.msgHeader.protocolHeader[0] = 'H';
        dataContent.msgHeader.protocolHeader[1] = 'M';
        dataContent.msgHeader.protocolHeader[2] = '_';
        dataContent.msgHeader.protocolHeader[3] = 'D';
        
        dataContent.videoLength = (unsigned int)[data length];
        
        int dataLen = (int)[data length];
        int contentLen = sizeof(dataContent);
        int totalLen = contentLen + dataLen;
        
        char *sendBuf = (char*)malloc(totalLen * sizeof(char));
        memcpy(sendBuf, &dataContent, contentLen);
        memcpy(sendBuf + contentLen, myByte, dataLen); // myByte是指针，所以不用再取地址了，注意
        
        // 开始发送给client
        [self sendDataSocketData:sendBuf dataLength:totalLen];
        
    }
}

// 音频数据
-(void)sendAudioDataToClientWithData:(NSData *)data
{
    // NSData 转Byte
    Byte *myByte = (Byte *)[data bytes];
    printf("=== send audio dataLen = %d\n", (int)[data length]);
    
    if (canSendData) {
        
        // 打包成一个结构体
        HJ_AudioDataContent dataContent;
        memset((void *)&dataContent, 0, sizeof(dataContent));
        
        dataContent.msgHeader.controlMask = CONTROLLCODE_AUDIOTRANS_REPLY;
        dataContent.msgHeader.protocolHeader[0] = 'H';
        dataContent.msgHeader.protocolHeader[1] = 'M';
        dataContent.msgHeader.protocolHeader[2] = '_';
        dataContent.msgHeader.protocolHeader[3] = 'D';
        
        dataContent.dataLength = (unsigned int)[data length];
        
        int dataLen = (int)[data length];
        int contentLen = sizeof(dataContent);
        int totalLen = contentLen + dataLen;
        
        char *sendBuf = (char*)malloc(totalLen * sizeof(char));
        memcpy(sendBuf, &dataContent, contentLen);
        memcpy(sendBuf + contentLen, myByte, dataLen); // myByte是指针，所以不用再取地址了，注意
        
        // 开始发送给client
        [self sendDataSocketData:sendBuf dataLength:totalLen];
    }
}





-(BOOL)recvTransRequest
{
    // 收到客户端发来的视频请求
    HJ_VideoAndAudioDataRequest request;
    memset(&request, 0, sizeof(request));
    
    printf("---- sizeof request = %ld\n",sizeof(request));
    
//    // 打印结构体
//    char *tempBuf = (char *)malloc(sizeof(request));
//    memcpy(tempBuf, &request, sizeof(request));
//    for (int i = 0; i < sizeof(request); i++) {
//        printf("%02x", tempBuf[i]);
//    }
//    printf("\n");
    
    
    // 阻塞，直到客户端来连接
    if([self recvDataSocketData:(char*)&request dataLength:sizeof(request)]){
        
        
        char tempMsgHeader[5]={0};
        memcpy(tempMsgHeader, &request.msgHeader.protocolHeader, sizeof(tempMsgHeader));
        memset(tempMsgHeader+4, 0, 1);
        NSString* headerStr=[NSString stringWithCString:tempMsgHeader encoding:NSASCIIStringEncoding];
        if ([headerStr compare:@"HM_D"] == NSOrderedSame) {
            if (request.msgHeader.controlMask == CODECONTROLL_DATATRANS_REQUEST) {
                
                // 开始准备传输音视频数据
                return true;
            }
        }
    }

    return false;
}


- (BOOL)sendDataSocketData:(char*)pBuf dataLength: (int)aLength
{
    
    signal(SIGPIPE, SIG_IGN);
    
    pthread_mutex_lock(&mutex_dSend);
    
    int sendLen=0;
    long nRet=0;
    
    while(sendLen<aLength)
    {
        if(m_connectfd>0)
        {
            nRet=send(m_connectfd,pBuf,aLength-sendLen,0);
            
            if(-1==nRet || 0==nRet)
            {
                pthread_mutex_unlock(&mutex_dSend);
                printf("cSocket send error\n");
                printf("收到TCP连接断开消息..., fd = %d\n", m_connectfd);
                [self stopTCPTransmissionService];
                return false;
            }
            
            sendLen+=nRet;
            pBuf+=nRet;
            
            printf("SEND LEN: %d %d\n",aLength,sendLen);
        }
        else
        {
            printf("dSocket fd error %d\n",m_connectfd);
            pthread_mutex_unlock(&mutex_dSend);
            return false;
        }
        
    }
    
    pthread_mutex_unlock(&mutex_dSend);
    
    return true;
}



- (BOOL)recvDataSocketData: (char*)pBuf dataLength: (int)aLength
{
    //
    signal(SIGPIPE, SIG_IGN);  // 防止程序收到SIGPIPE后自动退出

    pthread_mutex_lock(&mutex_dRecv);
    
    int recvLen=0;
    long nRet=0;
    
    while(recvLen<aLength)
    {

        nRet=recv(m_connectfd,pBuf,aLength-recvLen,0);
        if(-1==nRet || 0==nRet)
        {
            pthread_mutex_unlock(&mutex_dRecv);
            printf("DSocket recv error\n");
            if (0 == nRet) {
                [self stopTCPTransmissionService];
            }
            return false;
        }
        
        recvLen+=nRet;
        pBuf+=nRet;
    }
    
    pthread_mutex_unlock(&mutex_dRecv);
    
    return true;
}

@end
