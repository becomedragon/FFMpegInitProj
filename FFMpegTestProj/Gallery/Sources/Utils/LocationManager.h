//
//  LocationManager.h
//  Lemon
//
//  Created by becomedragon on 2018/10/10.
//  Copyright © 2018 iqiyi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LocationManager : NSObject
@property(nonatomic, strong) CLLocationManager *locationManager;
@property(nonatomic, strong) CLLocation *latestLocation;

- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
