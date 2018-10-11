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

class CaptureViewController: UIViewController,ImageSource {
    public let targets = TargetContainer()
    
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
    
    //native filter needed
    var videoPreview:GLKView?
    var ciContext:CIContext?
    var eaglContext:EAGLContext?
    var videoPreviewBounds:CGRect?
    
    //switch button
    var switchButton:UIButton?
    
    //capture type
    var captureAsYUV = true    //true use opengl filter , false use native filter
    var supportsFullYUVRange = false
    
    //shader program
    var yuvConversionShader:ShaderProgram?
    
    //frame capture controller
    let frameRenderingSemaphore = DispatchSemaphore(value:1)
    
    //opengl preview
    var renderView:RenderView?
    
    func transmitPreviousImage(to target: ImageConsumer, atIndex: UInt) {
        
    }
    
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
        if captureAsYUV {
            createRenderView()
        } else {
            createGLK()
            createCI()
        }
        createCaptureDevice()
        createOutput()
        createCaptureSession()
//        createPreviewLayer()
    }
    
    func createRenderView() {
        renderView = RenderView()
        view.addSubview(renderView!)
        renderView!.frame = UIScreen.main.bounds
        
        let filter = BasicOperation(fragmentShader: LuminanceFragmentShader, numberOfInputs: 1)
        self-->filter-->renderView!
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
            for device in cameraDevices {
                if device.position == .back {
                    backCamera = try AVCaptureDeviceInput(device: device)
                } else {
                    frontCamera = try AVCaptureDeviceInput(device: device)
                }
            }
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
        
        if captureAsYUV {
            supportsFullYUVRange = false
            let supportedPixelFormats = videoOutput!.availableVideoPixelFormatTypes
            for currentPixelFormat in supportedPixelFormats {
                if ((currentPixelFormat as NSNumber).int32Value == Int32(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)) {
                    supportsFullYUVRange = true
                }
            }
            
            if (supportsFullYUVRange) { //YUV色彩的取值范围，有些广播系统为了防止信号变动过载，从而在数值范围两边[0,255]增加“保护带”。
                yuvConversionShader = crashOnShaderCompileFailure("Camera")
                {
                    try sharedImageProcessingContext.programForVertexShader(defaultVertexShaderForInputs(2), fragmentShader:YUVConversionFullRangeFragmentShader)
                    
                }
                
                videoOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                
            } else {
                yuvConversionShader = crashOnShaderCompileFailure("Camera")
                {
                    try sharedImageProcessingContext.programForVertexShader(defaultVertexShaderForInputs(2), fragmentShader:YUVConversionVideoRangeFragmentShader)
                    
                }
                
                videoOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
            }
        } else {
            videoOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]
        }
        
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
            if captureAsYUV {
                openGLFilter(output, didOutput: sampleBuffer, from: connection)
            } else {
                nativeFilter(output, didOutput: sampleBuffer, from: connection)
            }
            
        } else if self.audioOutput!.isEqual(output) {
            
        }
    }
}

extension CaptureViewController {
    func openGLFilter(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard (frameRenderingSemaphore.wait(timeout:DispatchTime.now()) == DispatchTimeoutResult.success) else { return }
        
        let cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let bufferWidth = CVPixelBufferGetWidth(cameraFrame)
        let bufferHeight = CVPixelBufferGetHeight(cameraFrame)
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        CVPixelBufferLockBaseAddress(cameraFrame, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))
        
        sharedImageProcessingContext.runOperationAsynchronously {
            let cameraFramebuffer:Framebuffer
//            self.delegate?.didCaptureBuffer(sampleBuffer)
            
            let luminanceFramebuffer:Framebuffer     //Y frame
            let chrominanceFramebuffer:Framebuffer   //UV frame
            if sharedImageProcessingContext.supportsTextureCaches() {
                var luminanceTextureRef:CVOpenGLESTexture? = nil
                let _ = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, sharedImageProcessingContext.coreVideoTextureCache, cameraFrame, nil, GLenum(GL_TEXTURE_2D), GL_LUMINANCE, GLsizei(bufferWidth), GLsizei(bufferHeight), GLenum(GL_LUMINANCE), GLenum(GL_UNSIGNED_BYTE), 0, &luminanceTextureRef)
                let luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef!)
                glActiveTexture(GLenum(GL_TEXTURE4))
                glBindTexture(GLenum(GL_TEXTURE_2D), luminanceTexture)
                glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
                glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
                luminanceFramebuffer = try! Framebuffer(context:sharedImageProcessingContext, orientation:ImageOrientation.portrait, size:GLSize(width:GLint(bufferWidth), height:GLint(bufferHeight)), textureOnly:true, overriddenTexture:luminanceTexture)
                
                var chrominanceTextureRef:CVOpenGLESTexture? = nil
                let _ = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, sharedImageProcessingContext.coreVideoTextureCache, cameraFrame, nil, GLenum(GL_TEXTURE_2D), GL_LUMINANCE_ALPHA, GLsizei(bufferWidth / 2), GLsizei(bufferHeight / 2), GLenum(GL_LUMINANCE_ALPHA), GLenum(GL_UNSIGNED_BYTE), 1, &chrominanceTextureRef)
                let chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef!)
                glActiveTexture(GLenum(GL_TEXTURE5))
                glBindTexture(GLenum(GL_TEXTURE_2D), chrominanceTexture)
                glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
                glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
                chrominanceFramebuffer = try! Framebuffer(context:sharedImageProcessingContext, orientation:ImageOrientation.portrait, size:GLSize(width:GLint(bufferWidth / 2), height:GLint(bufferHeight / 2)), textureOnly:true, overriddenTexture:chrominanceTexture)
            } else {
                glActiveTexture(GLenum(GL_TEXTURE4))
                luminanceFramebuffer = sharedImageProcessingContext.framebufferCache.requestFramebufferWithProperties(orientation:ImageOrientation.portrait, size:GLSize(width:GLint(bufferWidth), height:GLint(bufferHeight)), textureOnly:true)
                luminanceFramebuffer.lock()
                
                glBindTexture(GLenum(GL_TEXTURE_2D), luminanceFramebuffer.texture)
                glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_LUMINANCE, GLsizei(bufferWidth), GLsizei(bufferHeight), 0, GLenum(GL_LUMINANCE), GLenum(GL_UNSIGNED_BYTE), CVPixelBufferGetBaseAddressOfPlane(cameraFrame, 0))
                
                glActiveTexture(GLenum(GL_TEXTURE5))
                chrominanceFramebuffer = sharedImageProcessingContext.framebufferCache.requestFramebufferWithProperties(orientation:ImageOrientation.portrait, size:GLSize(width:GLint(bufferWidth / 2), height:GLint(bufferHeight / 2)), textureOnly:true)
                chrominanceFramebuffer.lock()
                glBindTexture(GLenum(GL_TEXTURE_2D), chrominanceFramebuffer.texture)
                glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_LUMINANCE_ALPHA, GLsizei(bufferWidth / 2), GLsizei(bufferHeight / 2), 0, GLenum(GL_LUMINANCE_ALPHA), GLenum(GL_UNSIGNED_BYTE), CVPixelBufferGetBaseAddressOfPlane(cameraFrame, 1))
            }
            
            cameraFramebuffer = sharedImageProcessingContext.framebufferCache.requestFramebufferWithProperties(orientation:.portrait, size:luminanceFramebuffer.sizeForTargetOrientation(.portrait), textureOnly:false)
            
            let conversionMatrix:Matrix3x3
            if (self.supportsFullYUVRange) {
                conversionMatrix = colorConversionMatrix601FullRangeDefault
            } else {
                conversionMatrix = colorConversionMatrix601Default
            }
            convertYUVToRGB(shader:self.yuvConversionShader!, luminanceFramebuffer:luminanceFramebuffer, chrominanceFramebuffer:chrominanceFramebuffer, resultFramebuffer:cameraFramebuffer, colorConversionMatrix:conversionMatrix)
            
            CVPixelBufferUnlockBaseAddress(cameraFrame, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))
            
            cameraFramebuffer.timingStyle = .videoFrame(timestamp:Timestamp(currentTime))
            self.updateTargetsWithFramebuffer(cameraFramebuffer)
            
            self.frameRenderingSemaphore.signal()
        }
    }
    
    func nativeFilter(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)  {
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
    }
}


public extension Timestamp {
    public init(_ time:CMTime) {
        self.value = time.value
        self.timescale = time.timescale
        self.flags = TimestampFlags(rawValue:time.flags.rawValue)
        self.epoch = time.epoch
    }
    
    public var asCMTime:CMTime {
        get {
            return CMTimeMakeWithEpoch(value: value, timescale: timescale, epoch: epoch)
        }
    }
}
