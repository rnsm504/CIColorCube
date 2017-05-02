//
//  ViewController.swift
//  CIColorCubeSample
//
//  Created by msnr on 2017/05/03.
//  Copyright © 2017年 msnr. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate  {
    
    var session : AVCaptureSession!
    
    var imageView : UIImageView!
    var _cifilter : CIFilter!
    var hue : Float = 0.1
    
    var isFilter : Bool = false
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        initCamera()
        _cifilter = filter()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidDisappear(_ animated: Bool) {
        // camera stop メモリ解放
        session.stopRunning()
        
        for output in session.outputs {
            session.removeOutput(output as? AVCaptureOutput)
        }
        
        for input in session.inputs {
            session.removeInput(input as? AVCaptureInput)
        }
        session = nil
    }
    
    func initCamera() {
        imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height))
        self.view.addSubview(self.imageView)
        
        imageView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.tap))
        imageView.addGestureRecognizer(tapGesture)

        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1.0
        slider.value = 0.5
        self.imageView.addSubview(slider)
        
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -40.0).isActive = true
        slider.widthAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.8).isActive = true
        slider.centerXAnchor.constraint(equalTo: imageView.centerXAnchor).isActive = true
        slider.addTarget(self, action: #selector(ViewController.changedFilter), for: .valueChanged)


        
        session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetHigh
        
        let camera = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back)
        
        var inputDevice : AVCaptureDeviceInput!
        do {
            inputDevice = try AVCaptureDeviceInput(device: camera)
        } catch let error as NSError {
            print(error)
        }
        
        if(session.canAddInput(inputDevice)){
            session.addInput(inputDevice)
        }
        
        let output = AVCaptureVideoDataOutput()
        if(session.canAddOutput(output)){
            session.addOutput(output)
        }
        
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)]
        output.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        output.alwaysDiscardsLateVideoFrames = true
        
        session.startRunning()
        
        do {
            try camera?.lockForConfiguration()
            camera?.activeVideoMinFrameDuration = CMTimeMake(1, 30)
            camera?.unlockForConfiguration()
        } catch let error as NSError {
            print(error)
        }
        
    }
    
    func RGBtoHSV(_ r : Float, g : Float, b : Float) -> (h : Float, s : Float, v : Float) {
        var h : CGFloat = 0
        var s : CGFloat = 0
        var v : CGFloat = 0
        let col = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
        col.getHue(&h, saturation: &s, brightness: &v, alpha: nil)
        return (Float(h), Float(s), Float(v))
    }
    
    func HSVtoRGB(_ h : Float, s : Float, v : Float) -> (r : Float, g : Float, b : Float) {
        var r : Float = 0
        var g : Float = 0
        var b : Float = 0
        let C = s * v
        let HS = h * 6.0
        let X = C * (1.0 - fabsf(fmodf(HS, 2.0) - 1.0))
        if (HS >= 0 && HS < 1) {
            r = C
            g = X
            b = 0
        } else if (HS >= 1 && HS < 2) {
            r = X
            g = C
            b = 0
        } else if (HS >= 2 && HS < 3) {
            r = 0
            g = C
            b = X
        } else if (HS >= 3 && HS < 4) {
            r = 0
            g = X
            b = C
        } else if (HS >= 4 && HS < 5) {
            r = X
            g = 0
            b = C
        } else if (HS >= 5 && HS < 6) {
            r = C
            g = 0
            b = X
        }
        let m = v - C
        r += m
        g += m
        b += m
        return (r, g, b)
    }
    
    func filter() -> CIFilter {
        
        let size = 64
        let defaultHue: Float = 0 //default color of blue truck
        let hueRange: Float = 60 //hue angle that we want to replace
        
        let centerHueAngle: Float = defaultHue/360.0
        var destCenterHueAngle: Float = hue
        let minHueAngle: Float = (defaultHue - hueRange/2.0) / 360
        let maxHueAngle: Float = (defaultHue + hueRange/2.0) / 360
        let hueAdjustment = centerHueAngle - destCenterHueAngle
        if destCenterHueAngle == 0  {
            destCenterHueAngle = 1 //force red if slider angle is 0
        }
        
        var cubeData = [Float](repeating: 0, count: (size * size * size * 4))
        var offset = 0
        var x : Float = 0, y : Float = 0, z : Float = 0, a :Float = 1.0
        
        for b in 0..<size {
            x = Float(b)/Float(size)
            for g in 0..<size {
                y = Float(g)/Float(size)
                for r in 0..<size {
                    z = Float(r)/Float(size)
                    var hsv = RGBtoHSV(z, g: y, b: x)
                    
                    if (hsv.h > minHueAngle && hsv.h < maxHueAngle) {
                        hsv.h = destCenterHueAngle == 1 ? 0 : hsv.h - hueAdjustment //force red if slider angle is 360
                        let newRgb = HSVtoRGB(hsv.h, s:hsv.s, v:hsv.v)
                        
                        cubeData[offset] = newRgb.r
                        cubeData[offset+1] = newRgb.g
                        cubeData[offset+2] = newRgb.b
                    } else {
                        cubeData[offset] = z
                        cubeData[offset+1] = y
                        cubeData[offset+2] = x
                    }
                    cubeData[offset+3] =  a
                    offset += 4
                }
            }
        }
        
        let b = cubeData.withUnsafeBufferPointer{ Data(buffer:$0) }
        let data = b as NSData
        let colorCube = CIFilter(name: "CIColorCube", withInputParameters: ["inputCubeDimension": size, "inputCubeData" : data])
        return colorCube!
    }

    func tap(sender: UITapGestureRecognizer) {
        isFilter = !isFilter
    }
    
    func changedFilter(sender: UISlider) {
        hue = sender.value
        print(hue)
        _cifilter = filter()
    }
    
    
    //MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let opaqueBuffer = Unmanaged<CVImageBuffer>.passUnretained(imageBuffer!).toOpaque()
        let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(opaqueBuffer).takeUnretainedValue()
        let outputImage = CIImage(cvPixelBuffer: pixelBuffer, options: nil)
        var outputCGImage : CGImage! = nil
        
        connection.videoOrientation = .portrait
        
        if isFilter {
            let cifilter = _cifilter
            cifilter?.setValue(outputImage, forKey: kCIInputImageKey)
            
            let ciContext:CIContext = CIContext(options: nil)
            outputCGImage = ciContext.createCGImage(cifilter!.outputImage!, from:cifilter!.outputImage!.extent)!
        }
        
        let image = isFilter ? UIImage(cgImage: outputCGImage) : UIImage(ciImage: outputImage)
        
        DispatchQueue.main.async {
            self.imageView.image = image
        }
        
    }
    

}

