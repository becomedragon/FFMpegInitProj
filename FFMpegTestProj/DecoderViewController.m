//
//  DecoderViewController.m
//  FFMpegTestProj
//
//  Created by becomedragon on 2018/9/25.
//  Copyright © 2018 iqiyi. All rights reserved.
//

#import "DecoderViewController.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>

@interface DecoderViewController ()
@property (nonatomic ,strong) UIButton *decode;
@property (nonatomic ,strong) UITextView *output;
@property (nonatomic ,strong) NSString *inputFilename;
@property (nonatomic ,strong) NSString *outputFilename;
@end

@implementation DecoderViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.inputFilename = @"sintel.mov";
    self.outputFilename = @"sintel.yuv";
    [self addSubviews];
    // Do any additional setup after loading the view from its nib.
}

- (void)addSubviews {
    self.decode = [[UIButton alloc] init];
    self.decode.frame = CGRectMake(0, 0, 200, 100);
    [self.decode setTitle:@"Decode" forState:UIControlStateNormal];
    [self.decode setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.decode addTarget:self action:@selector(decode2YUV:) forControlEvents:UIControlEventTouchUpInside];
    
    
    self.output = [[UITextView alloc] init];
    self.output.frame = CGRectMake(0, self.decode.frame.origin.y + 100, self.view.frame.size.width, 400);
    
    [self.view addSubview:self.decode];
    [self.view addSubview:self.output];
}

- (void)decode2YUV:(id)sender {
    AVFormatContext *pFormatCtx;
    int i,videoindex;
    AVCodecContext *pCodecCtx;
    AVCodec *pCodec;
    AVFrame *pFrame,*pFrameYUV;
    uint8_t *out_buffer;
    AVPacket *packet;
    int y_size;
    int ret,got_picture;
    struct SwsContext *img_convert_ctx;
    FILE *fp_yuv;
    int frame_cnt;
    clock_t time_start,time_finish;
    double time_duration = 0.0;
    
    char input_str_full[500] = {0};
    char output_str_full[500] = {0};
    char info[1000] = {0};
    
    NSString *input_str = [NSString stringWithFormat:@"resource.bundle/%@",self.inputFilename];
    NSString *output_str = self.outputFilename;
    
    NSString *documentDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *input_nsstr = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:input_str];
    NSString *output_nsstr = [NSString stringWithFormat:@"%@/%@",documentDir,output_str];
    
    sprintf(input_str_full,"%s",[input_nsstr UTF8String]);
    sprintf(output_str_full,"%s",[output_nsstr UTF8String]);
    
    NSLog(@"input file path %@",input_nsstr);
    NSLog(@"output file path %@",output_nsstr);
    
    av_register_all();
    avformat_network_init();
    pFormatCtx = avformat_alloc_context();
    
    if (avformat_open_input(&pFormatCtx, input_str_full, NULL, NULL) != 0) {
        NSLog(@"Couldnt open input stream");
        return;
    }
    
    if (avformat_find_stream_info(pFormatCtx, NULL) < 0) {
        NSLog(@"Couldnt find stream info");
        return;
    }
    
    videoindex = -1;
    for (i=0; i<pFormatCtx->nb_streams; i++) {
        if (pFormatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoindex = i;
            break;
        }
    }
    
    if (videoindex == -1) {
        NSLog(@"Couldnt find a video stream");
        return;
    }
    
    pCodecCtx = pFormatCtx->streams[videoindex]->codec;
    pCodec=avcodec_find_decoder(pCodecCtx->codec_id);
    if (pCodec==NULL) {
        NSLog(@"Couldnt find Codec");
        return;
    }
    
    if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        NSLog(@"Couldnt open Codec");
        return;
    }
    
    pFrame = av_frame_alloc();
    pFrameYUV = av_frame_alloc();
    out_buffer = (unsigned char *)av_malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P, pCodecCtx->width, pCodecCtx->height, 1));
    av_image_fill_arrays(pFrameYUV->data, pFrameYUV->linesize, out_buffer, AV_PIX_FMT_YUV420P, pCodecCtx->width, pCodecCtx->height, 1);
    packet = (AVPacket *)av_malloc(sizeof(AVPacket));
    img_convert_ctx = sws_getContext(pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height, AV_PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);
    
    sprintf(info,   "[Input     ]%s\n", [input_str UTF8String]);
    sprintf(info, "%s[Output    ]%s\n",info,[output_str UTF8String]);
    sprintf(info, "%s[Format    ]%s\n",info, pFormatCtx->iformat->name);
    sprintf(info, "%s[Codec     ]%s\n",info, pCodecCtx->codec->name);
    sprintf(info, "%s[Resolution]%dx%d\n",info, pCodecCtx->width,pCodecCtx->height);
    
    fp_yuv=fopen(output_str_full, "wb+");
    if (fp_yuv == NULL) {
        NSLog(@"Couldnt open output file");
        return;
    }
    
    frame_cnt = 0;
    time_start = clock();
    
    while (av_read_frame(pFormatCtx, packet) >= 0) {
        if (packet->stream_index==videoindex) {
            ret = avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, packet);
            if (ret < 0) {
                NSLog(@"Decode Error");
                return;
            }
            
            if (got_picture) {
                sws_scale(img_convert_ctx, (const uint8_t* const*)pFrame->data, pFrame->linesize, 0, pCodecCtx->height, pFrameYUV->data, pFrameYUV->linesize);
                
                y_size = pCodecCtx->width * pCodecCtx->height;
                fwrite(pFrameYUV->data[0], 1, y_size, fp_yuv);
                fwrite(pFrameYUV->data[1], 1, y_size / 4, fp_yuv);
                fwrite(pFrameYUV->data[2], 1, y_size / 4, fp_yuv);
                
                char pictype_str[10]={0};
                switch (pFrame->pict_type) {
                    case AV_PICTURE_TYPE_I:
                        sprintf(pictype_str, "I");
                        break;
                    case AV_PICTURE_TYPE_B:
                        sprintf(pictype_str, "B");
                        break;
                    case AV_PICTURE_TYPE_P:
                        sprintf(pictype_str, "P");
                        break;
                    default:
                        sprintf(pictype_str, "Other");
                        break;
                }
                
                NSLog(@"Frame Index : %5d, Type %s",frame_cnt,pictype_str);
                frame_cnt ++;
            }
        }
//        av_free_packet(packet);
        av_packet_unref(packet);
    }
    
    NSString *info_ns = [NSString stringWithFormat:@"%s",info];
    self.output.text = info_ns;
}

@end
