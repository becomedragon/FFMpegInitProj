//
//  Asset+Property.swift
//  FFMpegTestProj
//
//  Created by 程晓龙 on 2018/10/15.
//  Copyright © 2018 iqiyi. All rights reserved.
//

import Foundation
extension AVURLAsset {
    func videoLength() -> Int {
        return Int(duration.value / Int64(duration.timescale))
    }
}
