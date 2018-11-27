//
//  Image2Mov.h
//  FFMpegTestProj
//
//  Created by 程晓龙 on 2018/10/22.
//  Copyright © 2018 iqiyi. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface Image2Mov : NSObject
+ (instancetype)shared;
@property (nonatomic ,strong) NSMutableArray *array;
+ (void)writeImageAsMovie:(UIImage*)image toPath:(NSString*)path size:(CGSize)size duration:(int)duration;
@end

NS_ASSUME_NONNULL_END
