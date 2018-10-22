//
//  Encoder.h
//  FFMpegTestProj
//
//  Created by 程晓龙 on 2018/10/19.
//  Copyright © 2018 iqiyi. All rights reserved.
//

#include <Foundation/Foundation.h>
@interface Mp3Encoder:NSObject
- (instancetype)shared;
- (void)encode:(NSString *)pcmPath mp3Path:(NSString *)mp3FilePath;
@end

