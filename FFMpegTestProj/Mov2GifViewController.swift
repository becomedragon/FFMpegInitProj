//
//  Mov2GifViewController.swift
//  FFMpegTestProj
//
//  Created by 程晓龙 on 2018/10/15.
//  Copyright © 2018 iqiyi. All rights reserved.
//

import UIKit
import WebKit
import Photos
import PhotosUI
import MobileCoreServices

class Mov2GifViewController: UIViewController {

    var webView:WKWebView?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        webView = WKWebView(frame: UIScreen.main.bounds)
        webView?.backgroundColor = .white
        
        view.addSubview(webView!)
        
        let videoBtn = UIButton(frame: CGRect(x: 100, y: 100, width: 200, height: 100))
        videoBtn.setTitle("Video", for: .normal)
        videoBtn.setTitleColor(.black, for: .normal)
        videoBtn.addTarget(self, action: #selector(choseVideo), for: .touchUpInside)
        view.addSubview(videoBtn)
        
        let cameraBtn = UIButton(frame: CGRect(x: 100, y: 200, width: 200, height: 100))
        cameraBtn.setTitle("Camera", for: .normal)
        cameraBtn.setTitleColor(.black, for: .normal)
        cameraBtn.addTarget(self, action: #selector(choseCamera), for: .touchUpInside)
        view.addSubview(cameraBtn)
        
        let livePhotoBtn = UIButton(frame: CGRect(x: 100, y: 300, width: 200, height: 100))
        livePhotoBtn.setTitle("LivePhoto", for: .normal)
        livePhotoBtn.setTitleColor(.black, for: .normal)
        livePhotoBtn.addTarget(self, action: #selector(choseLivePhoto), for: .touchUpInside)
        view.addSubview(livePhotoBtn)
        
        // Do any additional setup after loading the view.
    }
    
    @objc func choseVideo() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.mediaTypes = [kUTTypeMovie,kUTTypeVideo] as [String]
        present(imagePicker, animated: true, completion: nil)
    }
    
    @objc func choseCamera() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.mediaTypes = [kUTTypeMovie,kUTTypeVideo] as [String]
        present(imagePicker, animated: true, completion: nil)
    }
    
    @objc func choseLivePhoto() {
        if #available(iOS 9.1, *) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .savedPhotosAlbum
            imagePicker.mediaTypes = [kUTTypeImage,kUTTypeLivePhoto] as [String]
            present(imagePicker, animated: true, completion: nil)
        } else {
//            imagePicker.mediaTypes = [kUTTypeImage] as [String];
        }
    }
}

extension Mov2GifViewController:UIImagePickerControllerDelegate,UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let groupQuene = DispatchGroup()
        groupQuene.enter()
        
        let type = info[.mediaType] as! CFString
        var mediaURL:URL?
        
        //            let url = info[.referenceURL] as! URL
        //            let results = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil)
        //            let asset = results.firstObject
        //            let resource = PHAssetResource.assetResources(for: asset!).first
        //            let resource = PHAssetResource.assetResources(for: livePhoto).first
        
        if #available(iOS 9.1, *) {
            
            if type == kUTTypeMovie {
                mediaURL = info[.mediaURL] as? URL
                picker.dismiss(animated: true, completion: nil)
                groupQuene.leave()
            } else if type == kUTTypeLivePhoto {
                let livePhoto = info[.livePhoto] as! PHLivePhoto
                let results = PHAssetResource.assetResources(for: livePhoto)
                var movieResourceAsset:PHAssetResource?
                var photoResourceAsset:PHAssetResource?
                
                for asset in results {
                    if asset.type == .photo {
                        photoResourceAsset = asset
                    } else if asset.type == .pairedVideo {
                        movieResourceAsset = asset
                    }
                }
                
                var nsString = NSTemporaryDirectory() as NSString
                nsString = nsString.appendingPathComponent("tmp.mov") as NSString
                mediaURL = URL(fileURLWithPath: nsString as String)
                
                do {
                    try FileManager.default.removeItem(at: mediaURL!)
                } catch {
                    
                }
                
                PHAssetResourceManager.default().writeData(for:movieResourceAsset!, toFile:mediaURL!, options: nil) { (error) in
                    if error == nil {
                        debugPrint("Success convert live photo 2 mov")
                        groupQuene.leave()
                    }
                }
            }
            picker.dismiss(animated: true, completion: nil)
            
            groupQuene.notify(queue: DispatchQueue.global()) {
                GifConverter.shared.createGif(mediaURL!, mediaType: .video) {[weak self] (url) in
                    DispatchQueue.main.async {
                        let data = NSData(contentsOfFile: url.absoluteString)
                        self?.webView?.load(data! as Data, mimeType: "image/gif", characterEncodingName: "UTF-8", baseURL:NSURL() as URL)
                    }
                }
            }
        }
    }
}
