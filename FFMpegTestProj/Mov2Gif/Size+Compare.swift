//
//  Size+Compare.swift
//  FFMpegTestProj
//
//  Created by 程晓龙 on 2018/10/15.
//  Copyright © 2018 iqiyi. All rights reserved.
//

import Foundation

extension CGSize {
    static func >= (lhs:CGSize,rhs:CGFloat) -> Bool {
        if lhs.width >= rhs || lhs.height >= rhs {
            return true
        }
        return false
    }
    
    static func < (lhs:CGSize,rhs:CGFloat) -> Bool {
        if lhs.width < rhs || lhs.height < rhs {
            return true
        }
        return false
    }
}
