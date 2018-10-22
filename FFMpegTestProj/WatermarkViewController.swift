//
//  WatermarkViewController.swift
//  FFMpegTestProj
//
//  Created by 程晓龙 on 2018/10/16.
//  Copyright © 2018 iqiyi. All rights reserved.
//

import UIKit
import WebKit
import Photos

class WatermarkViewController: UIViewController {

    var gallery:GalleryController!
    var webView:WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        webView = WKWebView(frame: UIScreen.main.bounds)
        webView.backgroundColor = .white
        view.addSubview(webView!)
        
        let videoBtn = UIButton(frame: CGRect(x: 100, y: 100, width: 200, height: 100))
        videoBtn.setTitle("Video", for: .normal)
        videoBtn.setTitleColor(.black, for: .normal)
        videoBtn.addTarget(self, action: #selector(pickImage), for: .touchUpInside)
        view.addSubview(videoBtn)
        
        let albumeBtn = UIButton(frame: CGRect(x: 100, y: 200, width: 200, height: 100))
        albumeBtn.setTitle("Albume", for: .normal)
        albumeBtn.setTitleColor(.black, for: .normal)
        albumeBtn.addTarget(self, action: #selector(filterAlbume), for: .touchUpInside)
        view.addSubview(albumeBtn)
        
        // Do any additional setup after loading the view.
    }
    
    @objc func pickImage() {
        gallery = GalleryController()
        gallery.delegate = self
        Config.tabsToShow = [.imageTab,.videoTab,.cameraTab]
        Config.Camera.imageLimit = 9;
        
        present(gallery, animated: true, completion: nil)
    }
    
    @objc func filterAlbume() {
//        let option = PHFetchOptions()
//        option.predicate = NSPredicate(format: "mediaType == %ld", PHAssetMediaType.video as! CVarArg)
//        option.sortDescriptors = NSSortDescriptor(key: "creationDate", ascending: false)
        
//        PHAssetCollectionSubtype
//        PHCollectionList
    }
}

extension WatermarkViewController:GalleryControllerDelegate {
    func galleryController(_ controller: GalleryController, didSelectImages images: [Image]) {
        dismissGallery()
    }
    
    func galleryController(_ controller: GalleryController, didSelectVideo video: Video) {
        dismissGallery()
        let bundlePath = Bundle.main.path(forResource: "demoFrame", ofType: "bundle")
        let image1 = UIImage(contentsOfFile:"\(bundlePath!)/1.jpg")
        let image2 = UIImage(contentsOfFile:"\(bundlePath!)/2.jpg")
        let image3 = UIImage(contentsOfFile:"\(bundlePath!)/3.jpg")
        
        video.asset.getURL { (url) in
            VideoWatermarker.shared.addOverlay(url: url!, frames: [image1!,image2!,image3!], framesToSkip: 4, complete: { (url) in
                DispatchQueue.main.async {
                    let videoTags = "<video controls> <source src=\"\(url!)\"> </video>"
                    self.webView.loadHTMLString(videoTags, baseURL: url!)
                }
            })
        }
    }
    
    func galleryController(_ controller: GalleryController, requestLightbox images: [Image]) {
        dismissGallery()
    }
    
    func galleryControllerDidCancel(_ controller: GalleryController) {
        dismissGallery()
    }
    
    func dismissGallery() {
        gallery.dismiss(animated: true, completion: nil)
        gallery = nil
    }
}
