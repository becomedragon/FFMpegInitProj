//
//  Buffer2YUV.h
//  FFMpegTestProj
//
//  Created by becomedragon on 2018/10/9.
//  Copyright © 2018 iqiyi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Buffer2YUV : NSObject
+ (NSData *)buffer2YUV:(CMSampleBufferRef )videoSample;
@end

NS_ASSUME_NONNULL_END
