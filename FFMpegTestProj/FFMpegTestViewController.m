//
//  FFMpegTestViewController.m
//  FFMpegTestProj
//
//  Created by becomedragon on 2018/9/21.
//  Copyright © 2018 iqiyi. All rights reserved.
//

#import "FFMpegTestViewController.h"
//#import "FFmpeg-iOS/include/libavutil/opt.h"
//#import "FFmpeg-iOS/include/libavcodec/avcodec.h"
//#import "FFmpeg-iOS/include/libavformat/avformat.h"
//#import "FFmpeg-iOS/include/libswscale/swscale.h"

#ifdef __cplusplus
extern "C" {
#endif

#include "libavutil/opt.h"
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"

#ifdef __cplusplus
};
#endif

@interface FFMpegTestViewController ()

@end

@implementation FFMpegTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    av_register_all();
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
