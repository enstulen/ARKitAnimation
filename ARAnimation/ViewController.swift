//
//  ViewController.swift
//  ARAnimation
//
//  Created by Esteban Herrera on 7/11/17.
//  Copyright © 2017 Esteban Herrera. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import SwiftCharts
import Speech
import Alamofire
import SwiftyJSON


class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    var animations = [String: CAAnimation]()
    var idle:Bool = true
    var infoNode: SCNNode!
    var chart: BarsChart!
    
    var lat: Double!
    var long: Double!
    
    var isProccessing = false
    let audioEngine = AVAudioEngine()
    var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    var request = SFSpeechAudioBufferRecognitionRequest()
    var recognitionTask: SFSpeechRecognitionTask?
    var node:AVAudioInputNode?
    
    var lastestSpeach:Date?
    var stopTimer:Timer = Timer()
    
    var isActive = false
    var textBuffer:String = ""
    
    let synth = AVSpeechSynthesizer()
    var myUtterance = AVSpeechUtterance(string: "")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Louder voice
        let audioSession = AVAudioSession.sharedInstance()
        try! audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
        
        synth.delegate = self
        recordAndRecognizeSpeech()
        
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true

        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        //Lighting
        sceneView.autoenablesDefaultLighting = true
        
        //Add infoScreen
        infoNode = SCNNode(geometry: SCNBox(width: 1, height: 1.5, length: 0, chamferRadius: 0))
        infoNode.position = SCNVector3(-1, -1, -3.5)
        infoNode.name = "infoNode"
        sceneView.scene.rootNode.addChildNode(infoNode)
        
        // Load the DAE animations
        loadAnimations()
        
    }
    
    func addChartView(bars: Array<Any>){
        let chartConfig = BarsChartConfig(
            valsAxisConfig: ChartAxisConfig(from: 0, to: 8, by: 2)
        )
        
        let frame = CGRect(x: 0, y: 0, width: 300, height: 450)
        let chart = BarsChart(
            frame: frame,
            chartConfig: chartConfig,
            xTitle: "X axis",
            yTitle: "Y axis",
            bars: bars as! [(String, Double)],
            color: UIColor.red,
            barWidth: 20
        )
        addViewToInfoScreen(view: chart.view)
        self.chart = chart

    }

    
    func addMapView(lat: Double, long: Double){
        self.lat = lat
        self.long = long
        
        let staticMapUrl: String = "https://maps.googleapis.com/maps/api/staticmap?center=\(lat),\(long)&markers=color:red%7Clabel:%7C\(lat),\(long)&zoom=12&size=300x450&key=AIzaSyCOEpaOXyJQdMhSunPFmy_LGyrexUblryk"
        
        let url = URL(string: staticMapUrl)
        let data = NSData(contentsOf: url!)
        let image = UIImage(data: data! as Data)
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 450))
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 300, height: 450))
        imageView.image = image
        view.addSubview(imageView)
        addViewToInfoScreen(view: view)
     
    }
    
    func addImageToInfoScreen(image: UIImage){
        let imageView = UIImageView(frame: CGRect(x: 100, y: 100, width: 100, height: 100))
        imageView.image = image
        self.view.addSubview(imageView)
        
        let (min, max) = infoNode.boundingBox
        let height = max.y - min.y
        let width = max.x - min.x
        
        let imagePlane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
        imagePlane.firstMaterial?.diffuse.contents = image
        imagePlane.firstMaterial?.lightingModel = .phong
        let planeNode = SCNNode(geometry: imagePlane)
        planeNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
        }
        self.infoNode.addChildNode(planeNode)
   
    }
    
    
    
    func addViewToInfoScreen(view: UIView){
        let (min, max) = infoNode.boundingBox
        let height = max.y - min.y
        let width = max.x - min.x
        
        let imagePlane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
        imagePlane.firstMaterial?.diffuse.contents = UIImage(view: view)
        //imagePlane.firstMaterial?.lightingModel = .constant
        let planeNode = SCNNode(geometry: imagePlane)
        infoNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
        }
        self.infoNode.addChildNode(planeNode)
    }
    

    
    func loadAnimations () {
        // Load the character in the idle animation
        let idleScene = SCNScene(named: "art.scnassets/Idle2.dae")!
        
        // This node will be parent of all the animation models
        let node = SCNNode()
        
        // Add all the child nodes to the parent node
        for child in idleScene.rootNode.childNodes {
            node.addChildNode(child)
        }
        
        // Set up some properties

        node.position = SCNVector3(0, -1, -2)
        node.scale = SCNVector3(0.2, 0.2, 0.2)
        
        // Add the node to the scene
        sceneView.scene.rootNode.addChildNode(node)
        
//        // Create a LookAt constraint, point at the cameras POV
//        let constraint = SCNLookAtConstraint(target: sceneView.pointOfView)
//        // Keep the rotation on the horizon
//        constraint.isGimbalLockEnabled = true
//        // Slow the constraint down a bit
//        constraint.influenceFactor = 0.01
//        // Finally add the constraint to the node
//        node.constraints = [constraint]
        
        //node.constraints = [SCNBillboardConstraint()]

        
        // Load all the DAE animations
        loadAnimation(withKey: "talking", sceneName: "art.scnassets/talkingFixed", animationIdentifier: "talkingFixed-1")
    }
    
    
    func loadAnimation(withKey: String, sceneName:String, animationIdentifier:String) {
        let sceneURL = Bundle.main.url(forResource: sceneName, withExtension: "dae")
        let sceneSource = SCNSceneSource(url: sceneURL!, options: nil)
        
        if let animationObject = sceneSource?.entryWithIdentifier(animationIdentifier, withClass: CAAnimation.self) {
            // The animation will only play once
            animationObject.repeatCount = 1
            // To create smooth transitions between animations
            animationObject.fadeInDuration = CGFloat(1)
            animationObject.fadeOutDuration = CGFloat(0.5)
            
            // Store the animation for later use
            animations[withKey] = animationObject
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: sceneView)
        
        // Let's test if a 3D Object was touch
        var hitTestOptions = [SCNHitTestOption: Any]()
        hitTestOptions[SCNHitTestOption.boundingBoxOnly] = true
        
        let hitResults: [SCNHitTestResult]  = sceneView.hitTest(location, options: hitTestOptions)
        
        if hitResults.first?.node.name == "infoNode" {

//            UIApplication.shared.openURL(URL(string:"http://maps.apple.com/?ll=\(lat),\(long)")!)

            let urlString: String = "comgooglemaps://?center=\(lat),\(long)&zoom=12"
            let url = URL(string: urlString)
            if (UIApplication.shared.canOpenURL(URL(string:"comgooglemaps://")!)) {
                UIApplication.shared.open(url!, options: [:], completionHandler: nil)
            } else {
                print("Can't use comgooglemaps://");
            }
        }
        else if hitResults.first != nil {
            if(idle) {
                playAnimation(key: "talking")
            } else {
                stopAnimation(key: "talking")
            }
            idle = !idle
            return
        }


    }
    
    
    func playAnimation(key: String) {
        // Add the animation to start playing it right away
        sceneView.scene.rootNode.addAnimation(animations[key]!, forKey: key)
    }
    
    func stopAnimation(key: String) {
        // Stop the animation with a smooth transition
        sceneView.scene.rootNode.removeAnimation(forKey: key, blendOutDuration: CGFloat(0.5))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}



extension ViewController: SFSpeechRecognitionTaskDelegate, AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        synth.stopSpeaking(at: AVSpeechBoundary.immediate)
//        var utterance = AVSpeechUtterance(string: "")
//        synth.speak(utterance)
//        synth.stopSpeaking(at: AVSpeechBoundary.immediate)
        stopAnimation(key: "talking")
        
        print("all done")
    }
    
    
    @objc func updateTimer(){
        
        guard let lastestSpeachUnwrapped = lastestSpeach else{
            return
        }
        
        if (Date().timeIntervalSince(lastestSpeachUnwrapped) > 1){
            lastestSpeach = nil
            isProccessing = false
            restartSpeechProccesser()
        }
    }
    
    func recordAndRecognizeSpeech(){
        
        
        stopTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector:#selector(ViewController.updateTimer), userInfo: nil, repeats: true)
        
        
        node = audioEngine.inputNode
        let recordingFormat = node!.outputFormat(forBus: 0)
        node!.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat, block: {buffer, _ in
            self.request.append(buffer)
        })
        
        audioEngine.prepare()
        do{
            try audioEngine.start()
        }
        catch{
            return print(error)
        }
        
        
        guard let myRecongnizer = SFSpeechRecognizer() else {
            return
        }
        if !myRecongnizer.isAvailable{
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request, resultHandler: {result, error in
            if let resultUnwrapped = result{
                self.textBuffer = resultUnwrapped.bestTranscription.formattedString
                self.processText()
                self.lastestSpeach = Date()
                
                if (resultUnwrapped.isFinal){
                    
                    self.restartSpeechProccesser()
                }
            }
            else {
                print(error)
            }
        })
        
        
    }
    
    func restartSpeechProccesser(){
        
        stopTimer.invalidate()
        
        self.audioEngine.stop()
        
        if let nodeUnwrapped = node{
            nodeUnwrapped.removeTap(onBus: 0)
        }
        
        self.speechRecognizer = SFSpeechRecognizer()
        self.request = SFSpeechAudioBufferRecognitionRequest()
        self.recognitionTask = nil
        
        self.recordAndRecognizeSpeech()
    }
    
    
    
    func processText(){
        print(textBuffer)
//        if (textBuffer.lowercased().contains("hi bank buddy") ||
//            textBuffer.lowercased().contains("hi but it") ||
//            textBuffer.lowercased().contains("hi bank but") ){
//            isActive = true
//        }
        
        if (textBuffer.lowercased().contains("spending") && isProccessing == false){
            print("==============================")
            //Add chart view\
            isProccessing = true
            addChartView(bars: [
                ("A", Double(2)),
                ("B", Double(4.5)),
                ("C", Double(3)),
                ("D", Double(5.4)),
                ("E", Double(6.8)),
                ("F", Double(0.5))
                ])
            Alamofire.request("52.59.225.216/atm").responseJSON { response in
                
            }
            restartSpeechProccesser()
        }
        else if (textBuffer.lowercased().contains("atm") && isProccessing == false){
            
            isProccessing = true
            //Add mapView
            print("==============================2")
            addMapView(lat: Double(42.585444), long: Double(13.007813))
            
            let url = URL(string: "http://52.59.225.216/atm")
            
            Alamofire.request(url!).responseJSON { response in
                let json = JSON(data: response.data!)

                self.lat = json["latitude"].doubleValue
                self.long = json["longitude"].doubleValue

                self.speakAndAnimate(string: "Here is the closest ATM, you can click on the map to open the Google Maps app")
            }
            restartSpeechProccesser()
        }
    }
    func speakAndAnimate(string: String) {
        playAnimation(key: "talking")
        speak(string: string)
    }
    
    func speak(string: String){
        myUtterance = AVSpeechUtterance(string: string)
        myUtterance.rate = 0.45
        myUtterance.volume = 1
        myUtterance.voice  = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(myUtterance)
    }
}


extension UIImage {
    convenience init(view: UIView) {
        UIGraphicsBeginImageContext(view.frame.size)
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(cgImage: (image?.cgImage)!)
    }
}


//        let text = SCNText(string: "Hello", extrusionDepth: 0.1)
//        let blackMaterial = SCNMaterial()
//        blackMaterial.diffuse.contents = UIColor.black
//        text.firstMaterial = blackMaterial
//        text.font = UIFont(name: "San Francisco", size: 0.1)
//
//        let textNode = SCNNode(geometry: SCNBox(width: 1, height: 1.5, length: 0, chamferRadius: 0))
//        textNode.position = SCNVector3(-1, -1, -3)
//        textNode.scale = SCNVector3Make(0.01, 0.01, 0.01)
//        textNode.geometry = text
//        sceneView.scene.rootNode.addChildNode(textNode)
