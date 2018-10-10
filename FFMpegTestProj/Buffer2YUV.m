//
//  Buffer2YUV.m
//  FFMpegTestProj
//
//  Created by becomedragon on 2018/10/9.
//  Copyright © 2018 iqiyi. All rights reserved.
//

#import "Buffer2YUV.h"
#import "aw_common.h"

@implementation Buffer2YUV
+ (NSData *)buffer2YUV:(CMSampleBufferRef)videoSample {
    // 获取yuv数据
    // 通过CMSampleBufferGetImageBuffer方法，获得CVImageBufferRef。
    // 这里面就包含了yuv420数据的指针
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(videoSample);
    
    //表示开始操作数据
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    //图像宽度（像素）
    size_t pixelWidth = aw_stride(CVPixelBufferGetWidth(pixelBuffer));
    //图像高度（像素）
    size_t pixelHeight = CVPixelBufferGetHeight(pixelBuffer);
    //yuv中的y所占字节数
    size_t y_size = pixelWidth * pixelHeight;
    //yuv中的u和v分别所占的字节数
    size_t uv_size = y_size / 4;
    
    uint8_t *yuv_frame = aw_alloc(uv_size * 2 + y_size);
    
    //获取CVImageBufferRef中的y数据
    uint8_t *y_frame = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    memcpy(yuv_frame, y_frame, y_size);
    
    //获取CMVImageBufferRef中的uv数据
    uint8_t *uv_frame = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    memcpy(yuv_frame + y_size, uv_frame, uv_size * 2);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    NSData *nv12Data = [NSData dataWithBytesNoCopy:yuv_frame length:y_size + uv_size * 2];
    
    //旋转
//    return [Buffer2YUV rotateNV12Data:nv12Data];
    return nv12Data;
}

@end
