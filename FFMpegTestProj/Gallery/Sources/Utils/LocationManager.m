//
//  LocationManager.m
//  Lemon
//
//  Created by becomedragon on 2018/10/10.
//  Copyright © 2018 iqiyi. All rights reserved.
//

#import "LocationManager.h"

@interface LocationManager()<CLLocationManagerDelegate>

@end

@implementation LocationManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        [self.locationManager requestWhenInUseAuthorization];
    }
    return self;
}

- (void)start {
    [self.locationManager startUpdatingLocation];
}

- (void)stop {
    [self.locationManager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *bestLocation = locations.firstObject;
    for (CLLocation *location in locations) {
        if (location.horizontalAccuracy < bestLocation.horizontalAccuracy) {
            bestLocation = location;
        }
    }
    self.latestLocation = bestLocation;
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [self.locationManager startUpdatingLocation];
    } else {
        [self.locationManager stopUpdatingLocation];
    }
}

@end
