//
//  LivePushViewController.m
//  FFMpegTestProj
//
//  Created by becomedragon on 2018/9/26.
//  Copyright © 2018 iqiyi. All rights reserved.
//

#import "LivePushViewController.h"
#include <libavformat/avformat.h>
#include <libavutil/mathematics.h>
#include <libavutil/time.h>

@interface LivePushViewController ()
@property (nonatomic ,strong) UIButton *push;
@property (nonatomic ,strong) NSString *pushVideo;
@property (nonatomic ,strong) NSString *pushURL;
@end

@implementation LivePushViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.pushVideo = @"war3end.mp4";
//    self.pushURL = @"rtmp://stream.ssh101.com/becomedragon";
    self.pushURL = @"rtmp://10.127.22.149:6994/rtmplive/room2";
//    self.pushURL = @"rtmp://127.0.0.1/live/SJmuoW9KX";
    
    [self addSubviews];
    // Do any additional setup after loading the view.
}

- (void)addSubviews {
    self.push = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 200, 100)];
    [self.push setTitle:@"Push" forState:UIControlStateNormal];
    [self.push setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.push addTarget:self action:@selector(didPush) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.push];
}

- (void)didPush {
    char input_str_full[500] = {0};
    char output_str_full[500] = {0};
    
    NSString *input_str = [NSString stringWithFormat:@"resource.bundle/%@",self.pushVideo];
    NSString *input_nsstr = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:input_str];
    
    sprintf(input_str_full,"%s", [input_nsstr UTF8String]);
    sprintf(output_str_full, "%s",[self.pushURL UTF8String]);
    
    NSLog(@"Input Path %@",input_nsstr);
    NSLog(@"output path%@",self.pushURL);
    
    AVOutputFormat *ofmt = NULL;
    AVFormatContext *ifmt_ctx = NULL,*ofmt_ctx = NULL;
    AVPacket pkt;
    
    char in_filename[500]={0};
    char out_filename[500]={0};
    int ret,i;
    int videoindex = -1;
    int frame_index = 0;
    int64_t start_time = 0;
    
    strcpy(in_filename, input_str_full);
    strcpy(out_filename, output_str_full);
    
    av_register_all();
    avformat_network_init();
    
    if ((ret = avformat_open_input(&ifmt_ctx, in_filename, 0, 0)) < 0) {
        NSLog(@"couldnt open input file");
        goto end;
    }
    
    if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0) {
        NSLog(@"Failed to retrieve input stream information");
        goto end;
    }
    
    for (i=0; i<ifmt_ctx->nb_streams; i++) {
        if (ifmt_ctx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoindex=i;
            break;
        }
    }
    
    NSLog(@"input dump information");
    av_dump_format(ifmt_ctx, 0, in_filename, 0);
    
    avformat_alloc_output_context2(&ofmt_ctx, NULL, "flv", out_filename);//RTMP
//    avformat_alloc_output_context2(&ofmt_ctx, NULL, "mpegts", out_filename); //UDP
    
    if (!ofmt_ctx) {
        NSLog(@"couldnt create output context");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    
    ofmt = ofmt_ctx->oformat;
    for (i=0; i<ifmt_ctx->nb_streams; i++) {
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_stream->codec->codec);
        if (!out_stream) {
            NSLog(@"Failed allocating output stream");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        
        ret = avcodec_copy_context(out_stream->codec, in_stream->codec);
        if (ret < 0) {
            NSLog(@"Failed to copy context from input to output stream codec");
            goto end;
        }
        
        out_stream->codec->codec_tag = 0;
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
            out_stream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
        }
    }
    
    NSLog(@"output dump information");
    av_dump_format(ofmt_ctx, 0, out_filename, 1);
    
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        ret = avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE);
        if (ret < 0) {
            NSLog(@"couldnt open output url");
            goto end;
        }
    }
    
    ret = avformat_write_header(ofmt_ctx, NULL);
    if (ret < 0) {
        NSLog(@"Error occured when opening output URL");
        goto end;
    }
    
    start_time = av_gettime();
    while (1) {
        AVStream *in_streeam,*out_stream;
        
        ret = av_read_frame(ifmt_ctx, &pkt);
        if (ret < 0) {
            break;
        }
        
        if (pkt.pts == AV_NOPTS_VALUE) {
            //PTS
            AVRational time_basel = ifmt_ctx->streams[videoindex]->time_base;
            //Duration between 2 frames
            int64_t calc_duration = (double)AV_TIME_BASE / av_q2d(ifmt_ctx->streams[videoindex]->r_frame_rate);
            //Parameters
            pkt.pts = (double)(frame_index * calc_duration) / (double)(av_q2d(time_basel) * AV_TIME_BASE);
            pkt.dts = pkt.pts;
            pkt.duration = (double)calc_duration / (double)(av_q2d(time_basel) * AV_TIME_BASE);
        }
        
        if (pkt.stream_index==videoindex) {
            AVRational time_base = ifmt_ctx->streams[videoindex]->time_base;
            AVRational time_base_q = {1,AV_TIME_BASE};
            int64_t pts_time = av_rescale_q(pkt.dts, time_base, time_base_q);
            int64_t now_time = av_gettime() - start_time;
            if (pts_time > now_time) {
                av_usleep(pts_time - now_time);
            }
        }
        
        in_streeam = ifmt_ctx -> streams[pkt.stream_index];
        out_stream = ofmt_ctx->streams[pkt.stream_index];
        
        pkt.pts = av_rescale_q_rnd(pkt.dts, in_streeam->time_base, out_stream->time_base, (AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX));
        pkt.dts =av_rescale_q_rnd(pkt.dts, in_streeam->time_base, out_stream->time_base, (AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX));
        pkt.pos = -1;
        
        //print screen
        if (pkt.stream_index == videoindex) {
            NSLog(@"send %8d video frame to output utl",frame_index);
            frame_index ++;
        }
        
        ret = av_interleaved_write_frame(ofmt_ctx, &pkt);
        
        if (ret < 0) {
            NSLog(@"Error muxing packet");
            break;
        }
        
        av_packet_unref(&pkt);
    }
    
    av_write_trailer(ofmt_ctx);
    
end:
    avformat_close_input(&ifmt_ctx);
    //close output
    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE)) {
        avio_close(ofmt_ctx->pb);
    }
    avformat_free_context(ofmt_ctx);
    if (ret < 0 && ret != AVERROR_EOF) {
        NSLog(@"Error occurred");
        return;
    }
    return;
}

@end
