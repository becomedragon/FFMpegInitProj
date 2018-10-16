//
//  GifConverter.swift
//  FFMpegTestProj
//
//  Created by 程晓龙 on 2018/10/15.
//  Copyright © 2018 iqiyi. All rights reserved.
//

import UIKit
import MobileCoreServices

enum MediaConvertType {
    case video,livePhoto
}

enum GIFSize:Int {
    case veryLow  = 2
    case low      = 3
    case medium   = 5
    case high     = 7
    case original = 10
}

class GifConverter {
    static let shared = GifConverter()
    
    private let GifQuene = DispatchQueue(label: "me.becomedragon.gifconverter")
    private let tolerance = 0.01
    private let timeInterval:Int32 = 600
    
    func createGif(_ mediaAssetURL:URL,
                   mediaType:MediaConvertType,
                   frameCount InSeconds:Int = 4,
                   gifDelay:Double = 0.2,
                   loopCount:Int = 0, //0 means infinite
                   completion:@escaping (URL)->Void) {
        
        //properties of gif
        let frameProperties = [kCGImagePropertyGIFDelayTime:gifDelay] as [CFString : Any]
        let frameProperty = [kCGImagePropertyGIFDictionary:frameProperties]
        let gifProperties = [kCGImagePropertyGIFLoopCount:0,kCGImagePropertyGIFHasGlobalColorMap:false] as [CFString : Any]
        let gifProperty = [kCGImagePropertyGIFDictionary:gifProperties]
        
        let asset = AVURLAsset(url: mediaAssetURL)
        let videoSize = asset.tracks(withMediaType: .video)[0].naturalSize
        
        var optimalSize:GIFSize = .medium
        if  videoSize >= 1200 {
            optimalSize = .veryLow
        } else if videoSize >= 800 {
            optimalSize = .low
        } else if videoSize >= 400 {
            optimalSize = .medium
        } else if videoSize < 400 {
            optimalSize = .high
        }
        
        let videoSeconds = asset.videoLength()
        let framePreSeconds = InSeconds
        let totalFrameCount = videoSeconds * framePreSeconds
        let frameStride = 1.0 / Double(framePreSeconds)
        
        var timeStamps = [NSValue]()
        for currentFrame in 0..<totalFrameCount {
            let timeStamp = frameStride * Double(currentFrame)
            let cmTime = CMTimeMakeWithSeconds(timeStamp, preferredTimescale: timeInterval)
            timeStamps.append(NSValue(time: cmTime))
        }
        
        GifQuene.async {
            let gifURL = self.assembleFrame(timeStamps: timeStamps, videoURL: mediaAssetURL, gifProperty: gifProperty, frameProperty: frameProperty, totalFrameCount: totalFrameCount, gifSize: optimalSize)
            completion(gifURL)
        }
    }
    
    private func assembleFrame(timeStamps:[NSValue],videoURL:URL,gifProperty:[CFString:Any],frameProperty:[CFString:Any],totalFrameCount:Int,gifSize:GIFSize) -> URL {
        
        var path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last
        path?.append(contentsOf: "/gif.gif")
        let destination = CGImageDestinationCreateWithURL(NSURL(fileURLWithPath: path!), kUTTypeGIF, totalFrameCount, nil)
        CGImageDestinationSetProperties(destination!, gifProperty as CFDictionary)
        
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let tol = CMTimeMakeWithSeconds(tolerance, preferredTimescale: timeInterval)
        generator.requestedTimeToleranceAfter = tol
        generator.requestedTimeToleranceBefore = tol
        
        var previousImageCopy:CGImage? = nil
        for timeValue in timeStamps {
            var cgImage:CGImage? = nil
            do {
                cgImage = gifSize == .original ? createImage(cgImage: try generator.copyCGImage(at: timeValue.timeValue, actualTime: nil), scale: CGFloat(Float(gifSize.rawValue) / Float(10))) : try generator.copyCGImage(at: timeValue.timeValue, actualTime: nil)
            } catch {
                debugPrint("AVAssetImageGenerator Error")
            }
            
            if cgImage != nil {
                previousImageCopy = cgImage?.copy()!
            } else if previousImageCopy != nil {
                cgImage = previousImageCopy?.copy()
            } else {
                debugPrint("Error copying image and no previous frames to duplicate")
            }
            
            CGImageDestinationAddImage(destination!, cgImage!, frameProperty as CFDictionary)
        }
        
        CGImageDestinationFinalize(destination!)
        return URL(string: path!)!
    }
    
    private func createImage(cgImage:CGImage,scale:CGFloat) -> CGImage? {
        
        //high resolution image re-scale smaller
        let newSize = CGSize(width: CGFloat(cgImage.width) * scale, height: CGFloat(cgImage.height) * scale)
        let newRect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height).integral
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        let context = UIGraphicsGetCurrentContext()
        
        // Set the quality level to use when rescaling
        context?.interpolationQuality = .high
        let filpVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: newSize.height)
        
        context?.concatenate(filpVertical)
        context?.draw(cgImage, in: newRect)
        let scaledCgImage = context!.makeImage()
        UIGraphicsEndImageContext()
        
        return scaledCgImage ?? nil
    }
}
