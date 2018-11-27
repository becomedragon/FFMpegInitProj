//
//  ViewController.swift
//  CustomCamera
//
//  Created by Taras Chernyshenko on 6/27/17.
//  Copyright © 2017 Taras Chernyshenko. All rights reserved.
//

import UIKit

@available(iOS 10.0, *)
class CameraViewController: UIViewController {
    
    @IBOutlet private weak var topView: UIView?
    @IBOutlet private weak var middleView: UIView?
    @IBOutlet private weak var innerView: UIView?
    
    @IBAction private func recordingButton(_ sender: UIButton) {
        guard let cameraManager = self.cameraManager else { return }
        if cameraManager.isRecording {
            cameraManager.stopRecording()
            self.setupStartButton()
        } else {
            cameraManager.startRecording()
            self.setupStopButton()
        }
    }
   
    @IBAction private func flipButtonPressed(_ button: UIButton) {
        self.cameraManager?.flip()
    }
    
    private var cameraManager: TCCoreCamera?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.isNavigationBarHidden = true
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(zoomingGesture(gesture:)))
        self.view.addGestureRecognizer(gesture)
        self.topView?.layer.borderWidth = 1.0
        self.topView?.layer.borderColor = UIColor.darkGray.cgColor
        self.topView?.layer.cornerRadius = 32
        self.middleView?.layer.borderWidth = 4.0
        self.middleView?.layer.borderColor = UIColor.white.cgColor
        self.middleView?.layer.cornerRadius = 32
        self.innerView?.layer.borderWidth = 32.0
        self.innerView?.layer.cornerRadius = 32
        self.setupStartButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.cameraManager = TCCoreCamera(view: self.view)
        self.cameraManager?.videoCompletion = { (fileURL) in
            self.saveInPhotoLibrary(with: fileURL)
            print("finished writing to \(fileURL.absoluteString)")
        }
        self.cameraManager?.camereType = .video
        self.cameraManager?.flip()
        DispatchQueue.main.async {
            self.cameraManager?.startRecording()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.cameraManager?.stopRecording()
        }
    }
    
    @objc private func zoomingGesture(gesture: UIPanGestureRecognizer) {
        let velocity = gesture.velocity(in: self.view)
        if velocity.y > 0 {
            self.cameraManager?.zoomOut()
        } else {
            self.cameraManager?.zoomIn()
        }
    }
    private func setupStartButton() {
        self.topView?.backgroundColor = UIColor.clear
        self.middleView?.backgroundColor = UIColor.clear
        
        self.innerView?.layer.borderWidth = 32.0
        self.innerView?.layer.borderColor = UIColor.white.cgColor
        self.innerView?.layer.cornerRadius = 32
        self.innerView?.backgroundColor = UIColor.lightGray
        self.innerView?.alpha = 0.2
    }
    
    private func setupStopButton() {
        self.topView?.backgroundColor = UIColor.white
        self.middleView?.backgroundColor = UIColor.white
        
        self.innerView?.layer.borderColor = UIColor.red.cgColor
        self.innerView?.backgroundColor = UIColor.red
        self.innerView?.alpha = 1.0
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    private func saveInPhotoLibrary(with fileURL: URL) {
       
    }
}

