//
//  EncoderViewController.m
//  FFMpegTestProj
//
//  Created by becomedragon on 2018/9/30.
//  Copyright © 2018 iqiyi. All rights reserved.
//

#import "EncoderViewController.h"
#include <libavutil/opt.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>

@interface EncoderViewController ()
@property (nonatomic ,strong) UIButton *encoderButton;
@end

@implementation EncoderViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.encoderButton = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 200, 100)];
    [self.encoderButton setTitle:@"Encoder" forState:UIControlStateNormal];
    [self.encoderButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.encoderButton addTarget:self action:@selector(encoder:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.encoderButton];
}

- (int)flush_encoder:(AVFormatContext *)fmt_ctx index:(unsigned int)stream_index {
    int ret;
    int got_frame;
    AVPacket enc_pkt;
    
    if (!(fmt_ctx->streams[stream_index]->codec->codec->capabilities & CODEC_CAP_DELAY)) {
        return 0;
    }
    
    while (1) {
        enc_pkt.data = NULL;
        enc_pkt.size = 0;
        av_init_packet(&enc_pkt);
        ret = avcodec_encode_video2(fmt_ctx->streams[stream_index]->codec, &enc_pkt, NULL, &got_frame);
        av_frame_unref(NULL);
        if (ret < 0) {
            break;
        }
        if (!got_frame) {
            ret = 0;
            break;
        }
        
        NSLog(@"flush encoder:success to encode 1 frame\tsize:%5d",enc_pkt.size);
        ret = av_write_frame(fmt_ctx, &enc_pkt);
        if (ret < 0) {
            break;
        }
    }
    return ret;
}

- (void)encoder:(id)sender {
    AVFormatContext *pFormatCtx;
    AVOutputFormat *fmt;
    AVStream *video_st;
    AVCodecContext *pCodecCtx;
    AVCodec *pCodec;
    AVPacket pkt;
    uint8_t *picture_buf;
    AVFrame *pFrame;
    int picture_size;
    int y_size;
    int framecnt = 0;
    
    char in_file_char[500] = {0};
    char out_file[500] = {0};
    
    NSString *input_str = @"resource.bundle/sintel.yuv";
    NSString *output_str = @"sintel.h264";
    
    NSString *documentDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *input_nsstr = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:input_str];
    NSString *output_nsstr = [NSString stringWithFormat:@"%@/%@",documentDir,output_str];
    
    sprintf(in_file_char,"%s" , [input_nsstr UTF8String]);
    sprintf(out_file,"%s", [output_nsstr UTF8String]);
    
    FILE *in_file = fopen(in_file_char, "rb");
    int in_w = 848,in_h=480;
    int framenum = 649;
    
    av_register_all();
    
    
    //method1
    pFormatCtx = avformat_alloc_context();
    fmt = av_guess_format(NULL, out_file, NULL);
    pFormatCtx->oformat = fmt;
    
    //method2
//    avformat_alloc_output_context2(&pFormatCtx, NULL, NULL, out_file);
//    fmt = pFormatCtx->oformat;
    
    //open output url
    if (avio_open(&pFormatCtx->pb, out_file, AVIO_FLAG_READ_WRITE) < 0) {
        NSLog(@"failed to open output file");
        return;
    }
    
    video_st = avformat_new_stream(pFormatCtx, 0);
    
    if (video_st == NULL) {
        return;
    }
    
    pCodecCtx = video_st->codec;
    pCodecCtx->codec_id = fmt->video_codec;
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    pCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P;
    pCodecCtx->width = in_w;
    pCodecCtx->height = in_h;
    pCodecCtx->bit_rate = 400000;
    pCodecCtx->gop_size = 250;
    
    pCodecCtx->time_base.num = 1;
    pCodecCtx->time_base.den = 25;
    
    pCodecCtx->qmin = 10;
    pCodecCtx->qmax = 51;
    
    pCodecCtx->max_b_frames = 3;
    
    //set option
    AVDictionary *param = 0;
    
    if (pCodecCtx->codec_id == AV_CODEC_ID_H264) {
        av_dict_set(&param, "preset", "slow", 0);
        av_dict_set(&param, "tune", "zerolatency", 0);
    }
    
    if (pCodecCtx->codec_id == AV_CODEC_ID_H265) {
        av_dict_set(&param, "preset", "ultrafast", 0);
        av_dict_set(&param, "tune", "zero-latency", 0);
    }
    
    av_dump_format(pFormatCtx, 0, out_file, 1);
    
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (!pCodec) {
        NSLog(@"can not find encoder");
        return;
    }
    if (avcodec_open2(pCodecCtx, pCodec, &param) < 0) {
        NSLog(@"failed to open encoder");
        return;
    }
    
    pFrame = av_frame_alloc();
    picture_size = avpicture_get_size(pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    picture_buf = (uint8_t *)av_malloc(picture_size);
    avpicture_fill((AVPicture *)pFrame, picture_buf, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    
    //writer file header
    avformat_write_header(pFormatCtx, NULL);
    av_new_packet(&pkt, picture_size);
    y_size = pCodecCtx->width * pCodecCtx->height;
    
    for (int i = 0; i < framenum; i++) {
        if (fread(picture_buf, 1, y_size * 3/2, in_file) <= 0) {
            NSLog(@"failed to read raw data");
            return;
        } else if (feof(in_file)) {
            break;
        }
        
        pFrame -> data[0] = picture_buf;                 //Y
        pFrame -> data[1] = picture_buf + y_size;        //U
        pFrame -> data[2] = picture_buf + y_size * 5/4;  //V
        
        pFrame->pts = i*(video_st->time_base.den) / ((video_st->time_base.num) * 25);
        int got_picture = 0;
        
        //encode
        int ret = avcodec_encode_video2(pCodecCtx, &pkt, pFrame, &got_picture);
        if (ret < 0) {
            NSLog(@"failed to encode");
            return;
        }
        if (got_picture == 1) {
            NSLog(@"success to encode frame %5d\tsize:%5d",framecnt,pkt.size);
            framecnt ++;
            pkt.stream_index = video_st->index;
            ret = av_write_frame(pFormatCtx, &pkt);
            av_packet_unref(&pkt);
        }
    }
    
    //flush encoder
    int ret = [self flush_encoder:pFormatCtx index:0];
    if (ret < 0) {
        NSLog(@"flushing encder failed");
        return;
    }
    
    av_write_trailer(pFormatCtx);
    
    //clean
    if (video_st) {
        avcodec_close(video_st->codec);
        av_free(pFrame);
        av_free(picture_buf);
    }
    
    avio_close(pFormatCtx->pb);
    avformat_free_context(pFormatCtx);
    
    fclose(in_file);
}

@end
