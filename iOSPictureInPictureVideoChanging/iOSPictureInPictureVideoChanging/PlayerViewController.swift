

import AVFoundation
import UIKit
import AVKit

class PlayerViewController: UIViewController, AVPictureInPictureControllerDelegate {
    
    private var playerViewControllerKVOContext = 0
    
    lazy var player = AVPlayer()
    var playerPreloader: AVPlayer? = AVPlayer()
    
    var pictureInPictureController: AVPictureInPictureController!
    
    private var observer: PlayerObserver?
    
    private var model = Model(urlStrings: ["http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4",
        "http://techslides.com/demos/sample-videos/small.mp4"])
    
    private var observersOfItems: [PlayerItemObserver] = []
    
    var playerView: PlayerView {
        return self.view as! PlayerView
    }
    
    var playerLayer: AVPlayerLayer? {
        return playerView.playerLayer
    }
    
    var playerItem: AVPlayerItem? = nil {
        didSet {
            player.replaceCurrentItem(with: playerItem)
            
            if playerItem == nil {
                cleanUpPlayerPeriodicTimeObserver()
            }
            else {
                setupObservers()
            }
        }
    }
    
    var timeObserverToken: AnyObject?
    
    var currentTime: Double {
        get {
            return CMTimeGetSeconds(player.currentTime())
        }
        
        set {
            let newTime = CMTimeMakeWithSeconds(newValue, 1)
            player.seek(to: newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        }
    }
    
    var duration: Double {
        guard let currentItem = player.currentItem else { return 0.0 }
        
        return CMTimeGetSeconds(currentItem.duration)
    }
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var playPauseButton: UIBarButtonItem!
    @IBOutlet weak var pictureInPictureButton: UIBarButtonItem!
    @IBOutlet weak var toolbar: UIToolbar!
    
    // MARK: - IBActions
    
    @IBAction func playPauseButtonAction(_ sender: Any) {
        if player.rate != 1.0 {
            
            if currentTime == duration {
                currentTime = 0.0
            }
            
            playAdVideo()
        }
        else {
            player.pause()
        }
    }
    
    @IBAction func togglePictureInPictureMode(_ sender: UIButton) {

        if pictureInPictureController.isPictureInPictureActive {
            pictureInPictureController.stopPictureInPicture()
        }
        else {
            pictureInPictureController.startPictureInPicture()
        }
    }
    
    @IBAction func timeSliderDidChange(_ sender: UISlider) {
        currentTime = Double(sender.value)
    }
    
    // MARK: - View Handling
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        model.items.forEach { (item) in
            var callbacks = PlayerItemObserver.Callbacks()
            let obs = PlayerItemObserver(callbacks: callbacks, playerItem: item)
            observersOfItems.append(obs)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        playerView.playerLayer?.player = player
        
        
        timeSlider.translatesAutoresizingMaskIntoConstraints = true
        timeSlider.autoresizingMask = .flexibleWidth
        
        let backingButton = pictureInPictureButton.customView as! UIButton
        let image = AVPictureInPictureController.pictureInPictureButtonStartImage(compatibleWith: nil)
        backingButton.setImage(image, for: UIControlState.normal)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        player.pause()
        
        cleanUpPlayerPeriodicTimeObserver()
    }
    
    private func playAdVideo() {
        
        playerItem = model.items.first
        player.play()
        
        playerPreloader?.replaceCurrentItem(with: model.items[1])
        
//        playerItem = model.items[0]
//        player.play()
    }
    
    private func playContentVideo() {
        

        playerPreloader?.replaceCurrentItem(with: nil)
        playerPreloader = nil
        
        let itemNew = AVPlayerItem(asset: model.items[1].asset)
        
        if let urlAsset = model.items[1].asset as? AVURLAsset {
            print(urlAsset.assetCache)
        }
        playerItem = itemNew
        player.play()

//        playerItem = model.items[1]
//        player.play()
    }
    
    private func setupObservers() {
        
        setupPlayerPeriodicTimeObserver()
        
        var callbacks = PlayerObserver.Callbacks()
        weak var this = self

        
//        callbacks.bufferedTimeUpdated = { time in
//            print("time = ", time)
//        }
        
        callbacks.readyState = { item in
            if this?.pictureInPictureController == nil {
                this?.setupPictureInPicturePlayback()
            }
        }
        callbacks.rateChanged = { newRate, old in
            
            let style: UIBarButtonSystemItem = newRate == 0.0 ? .play : .pause
            let newPlayPauseButton = UIBarButtonItem(barButtonSystemItem: style, target: self, action: #selector(PlayerViewController.playPauseButtonAction(_:)))
            
            var items = this?.toolbar.items!
            
            if let playPauseItemIndex = items?.index(of: (this?.playPauseButton)!) {
                items?[playPauseItemIndex] = newPlayPauseButton
                
                this?.playPauseButton = newPlayPauseButton
                
                this?.toolbar.setItems(items, animated: false)
            }
        }
        
        callbacks.durationChanged = { newDuration, item in
            
            let hasValidDuration = newDuration.isNumeric && newDuration.value != 0
            let newDurationSeconds = hasValidDuration ? CMTimeGetSeconds(newDuration) : 0.0
            
            this?.timeSlider.maximumValue = Float(newDurationSeconds)
            
            if let currentTime = this?.player.currentTime() {
                let currentTimeSeconds = CMTimeGetSeconds(currentTime)
                this?.timeSlider.value = hasValidDuration ? Float(currentTimeSeconds) : 0.0
            }
            
            this?.playPauseButton.isEnabled = hasValidDuration
            this?.timeSlider.isEnabled = hasValidDuration
        }

        callbacks.endOfVideo = {
            this?.playContentVideo()
        }

//        callbacks.playbackReady = {
//            print("playbackReady = \($0)")
//        }
        
        observer = PlayerObserver(
            callbacks: callbacks,
            player: player)
    }
    
    private func setupPlayerPeriodicTimeObserver() {
        guard timeObserverToken == nil else { return }
        
        let time = CMTimeMake(1, 1)
        
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: time, queue:DispatchQueue.main) {
            [weak self] time in
            self?.timeSlider.value = Float(CMTimeGetSeconds(time))
            } as AnyObject?
    }
    
    private func cleanUpPlayerPeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    private func setupPictureInPicturePlayback() {

        if AVPictureInPictureController.isPictureInPictureSupported() {

            pictureInPictureController = AVPictureInPictureController(playerLayer: playerView.playerLayer!)
            pictureInPictureController.delegate = self
        }
        else {
            pictureInPictureButton.isEnabled = false
        }
    }
    
    // MARK: - AVPictureInPictureControllerDelegate
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        toolbar.isHidden = true
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        toolbar.isHidden = false
    }
    
    func pictureInPictureControllerFailedToStartPictureInPicture(pictureInPictureController: AVPictureInPictureController, withError error: NSError) {
        toolbar.isHidden = false
        handle(error: error)
    }
    
    
    // MARK: - Error Handling
    
    func handle(error: NSError?) {
        let alertController = UIAlertController(title: "Error", message: error?.localizedDescription, preferredStyle: .alert)
        
        let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(alertAction)
        present(alertController, animated: true, completion: nil)
    }
}


class PlayerView: UIView {
    
    var player: AVPlayer? {
        get { return playerLayer?.player }
        set { playerLayer?.player = newValue }
    }
    
    var playerLayer: AVPlayerLayer? {
        return layer as? AVPlayerLayer
    }
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}

extension PlayerViewController {
    struct Model {
        private var currentUrlPlayingIndex: Int = 0
        let items: [AVPlayerItem]
        
        init(urlStrings: [String]) {
            
            items = urlStrings.flatMap {
                guard let videoUrl = URL(string: $0) else { return nil }
                return AVPlayerItem(url: videoUrl)
            }
        }
        
        mutating func nextItem() -> AVPlayerItem? {
            if currentUrlPlayingIndex + 1 < items.count {
                currentUrlPlayingIndex += 1
                return items[currentUrlPlayingIndex]
            } else if 0 < items.count {
                currentUrlPlayingIndex = 0
                return items[currentUrlPlayingIndex]
            }
            
            return nil
        }
    }
}
