//
//  CaptureViewController.swift
//  FFMpegTestProj
//
//  Created by becomedragon on 2018/10/9.
//  Copyright © 2018 iqiyi. All rights reserved.
//

import UIKit
import AVFoundation
import VideoToolbox
import GLKit

class CaptureViewController: UIViewController {

    //front & back camera
    var frontCamera:AVCaptureDeviceInput?
    var backCamera:AVCaptureDeviceInput?
    
    //audio & video input
    var videoInput:AVCaptureDeviceInput?
    var audioInput:AVCaptureDeviceInput?
    
    //video & audio output
    var videoOutput:AVCaptureVideoDataOutput?
    var audioOutput:AVCaptureAudioDataOutput?
    
    //session
    var captureSession:AVCaptureSession?
    
    //preview layer
    var previewLayer:AVCaptureVideoPreviewLayer?
    
    //filter needed
    var videoPreview:GLKView?
    var ciContext:CIContext?
    var eaglContext:EAGLContext?
    var videoPreviewBounds:CGRect?
    
    //switch button
    var switchButton:UIButton?
    
    
    @objc func switchCamera() {
        captureSession?.beginConfiguration()
        captureSession?.removeInput(videoInput!)
        
        if videoInput!.isEqual(frontCamera) {
            videoInput = backCamera
        } else {
            videoInput = frontCamera
        }
        
        captureSession?.addInput(videoInput!)
        setVideoOutputConfig()
        captureSession?.commitConfiguration()
    }
    
    func onInit() {
        createGLK()
        createCI()
        createCaptureDevice()
        createOutput()
        createCaptureSession()
//        createPreviewLayer()
    }
    
    func createSwitchButton() {
        switchButton = UIButton(frame: CGRect(x: 100, y: 100, width: 200, height: 100))
        switchButton?.setTitle("Switch", for: .normal)
        switchButton?.setTitleColor(.green, for: .normal)
        switchButton?.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        
        view.addSubview(switchButton!)
    }
    
    func createGLK() {
        eaglContext = EAGLContext(api: .openGLES2)
        videoPreview = GLKView(frame: UIScreen.main.bounds, context: eaglContext!)
        videoPreview?.enableSetNeedsDisplay = false
        
//        back camera
//        videoPreview?.transform = CGAffineTransform.init(rotationAngle: .pi / 2)
        videoPreview?.frame = UIScreen.main.bounds
        
        view.addSubview(videoPreview!)
       
        videoPreview?.bindDrawable()
        videoPreviewBounds = CGRect.zero
        videoPreviewBounds?.size.height = CGFloat((videoPreview?.drawableHeight)!)
        videoPreviewBounds?.size.width = CGFloat((videoPreview?.drawableWidth)!)
        
    }
    
    func createCI() {
        ciContext = CIContext(eaglContext: eaglContext!, options: [CIContextOption.workingColorSpace:NSNull.init()])
    }
    
    
    func createCaptureDevice() {
        //camera init
        let cameraDevices = AVCaptureDevice.devices(for: .video)
        do {
            frontCamera = try AVCaptureDeviceInput(device: cameraDevices.last!)
            backCamera = try AVCaptureDeviceInput(device: cameraDevices.first!)
        } catch {
            print("camera is not work")
        }
        
        //Mic init,
        let audioDevice = AVCaptureDevice.default(for: .audio)
        do {
            audioInput = try AVCaptureDeviceInput(device: audioDevice!)
        } catch {
            print("audio is not work")
        }
        videoInput = frontCamera
    }
    
    func createOutput() {
        let captureQuene = DispatchQueue.init(label: "qy.capture.queue")
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput!.setSampleBufferDelegate(self, queue: captureQuene)
        videoOutput!.alwaysDiscardsLateVideoFrames = true
        videoOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]
//        videoOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        audioOutput = AVCaptureAudioDataOutput()
        audioOutput!.setSampleBufferDelegate(self, queue: captureQuene)
    }
    
    func createCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession!.beginConfiguration()
        
        if captureSession!.canAddInput(videoInput!) {
            captureSession!.addInput(videoInput!)
        }
        
        if captureSession!.canAddInput(audioInput!) {
            captureSession!.addInput(audioInput!)
        }
        
        if captureSession!.canAddOutput(videoOutput!) {
            captureSession!.addOutput(videoOutput!)
            setVideoOutputConfig()
        }
        
        if captureSession!.canAddOutput(audioOutput!) {
            captureSession!.addOutput(audioOutput!)
        }
        
        if captureSession!.canSetSessionPreset(.hd1280x720) {
            captureSession!.sessionPreset = .hd1280x720
        }
        
        captureSession!.commitConfiguration()
        captureSession!.startRunning()
    }
    
    func createPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer!.frame = view.bounds
        view.layer.addSublayer(previewLayer!)
    }
    
    func setVideoOutputConfig() {
        for conn in videoOutput!.connections {
            if conn.isVideoStabilizationSupported {
                conn.preferredVideoStabilizationMode = .auto
            }
            if conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
            conn.isVideoMirrored = true
        }
    }
    
    func destroyCaptureSession() {
        captureSession!.removeInput(audioInput!)
        captureSession!.removeInput(videoInput!)
        captureSession!.removeOutput(audioOutput!)
        captureSession!.removeOutput(videoOutput!)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        onInit()
        createSwitchButton()
        // Do any additional setup after loading the view.
    }
}

extension CaptureViewController:AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate{
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if self.videoOutput!.isEqual(output) {
//            let videoYUVData = Buffer2YUV.buffer2YUV(sampleBuffer)
            
            //add two filter
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            let sourceImage = CIImage(cvPixelBuffer:imageBuffer as! CVPixelBuffer)
            let sourceExtent = sourceImage.extent
            
            let vignetteFilter = CIFilter(name: "CIVignetteEffect")
            vignetteFilter?.setValue(sourceImage, forKey: kCIInputImageKey)
            vignetteFilter?.setValue(CIVector(x: sourceExtent.size.width/2, y: sourceExtent.size.height/2), forKey: kCIInputCenterKey)
            vignetteFilter?.setValue(sourceExtent.size.width/2, forKey: kCIInputRadiusKey)
            var filteredImage = vignetteFilter?.outputImage
            
            let effectFilter = CIFilter(name: "CIPhotoEffectInstant")
            effectFilter?.setValue(filteredImage, forKey: kCIInputImageKey)
            filteredImage = effectFilter?.outputImage
            
            //display new image
            let sourceAspect = sourceExtent.size.width / sourceExtent.size.height
            let previewAspect = videoPreviewBounds!.size.width / videoPreviewBounds!.size.height
            
            var drawRect = sourceExtent
            if sourceAspect > previewAspect {
                drawRect.origin.x += (drawRect.size.width - drawRect.size.height * previewAspect) / 2.0
                drawRect.size.width = drawRect.size.height * previewAspect
            } else {
                drawRect.origin.y += (drawRect.size.height - drawRect.size.width / previewAspect) / 2.0
                drawRect.size.height = drawRect.size.width / previewAspect
            }
            
            videoPreview?.bindDrawable()
            
            if eaglContext != EAGLContext.current() {
                EAGLContext.setCurrent(eaglContext)
            }
            
            //clear eagl view to gary
            glClearColor(0.5, 0.5, 0.5, 1.0)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            
            //set the blend mode to "source over" so that CI will use that
            glEnable(GLenum(GL_BLEND))
            glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
            
            if (filteredImage != nil) {
                ciContext?.draw(filteredImage!, in: videoPreviewBounds!, from: drawRect)
            }
            videoPreview?.display()
            
        } else if self.audioOutput!.isEqual(output) {
            
        }
    }
}
