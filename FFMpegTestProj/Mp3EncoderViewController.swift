//
//  Mp3EncoderViewController.swift
//  FFMpegTestProj
//
//  Created by 程晓龙 on 2018/10/19.
//  Copyright © 2018 iqiyi. All rights reserved.
//

import UIKit

class Mp3EncoderViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        
        let encodeBtn = UIButton(frame: CGRect(x: 100, y: 100, width: 200, height: 100))
        encodeBtn.setTitle("Encode Mp3", for: .normal)
        encodeBtn.setTitleColor(.black, for: .normal)
        encodeBtn.addTarget(self, action: #selector(encodeMp3), for: .touchUpInside)
        // Do any additional setup after loading the view.
    }
    
    @objc func encodeMp3() {
        let encoder = Mp3Encoder()
        let pcmPath = Bundle.main.path(forResource: "demo", ofType: "pcm")
        let mp3Path = NSTemporaryDirectory() + "demo.mp3"
        encoder.encode(pcmPath, mp3Path: mp3Path)
    }
}
