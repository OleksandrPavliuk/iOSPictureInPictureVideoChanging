
import Foundation
import AVFoundation

public final class PlayerItemObserver: NSObject {
    public struct Callbacks {
        public var playbackReady: Action<Bool>?
        public var bufferedTimeUpdated: Action<CMTime>?
        
        public init() {}
    }
    
    private let callbacks: Callbacks
    private var removeObserver: (PlayerItemObserver) -> ()
    
    //swiftlint:disable function_body_length
    public init(callbacks: Callbacks, playerItem: AVPlayerItem) {
        self.callbacks = callbacks
        removeObserver = { _ in }
        
        super.init()
        
        playerItem.addObserver(
            self,
            forKeyPath: "playbackBufferFull",
            options: [.initial, .new, .old],
            context: &Context.buffer)
        playerItem.addObserver(
            self,
            forKeyPath: "playbackLikelyToKeepUp",
            options: [.initial, .new, .old],
            context: &Context.buffer)
        playerItem.addObserver(
            self,
            forKeyPath: "loadedTimeRanges",
            options: [.initial, .new, .old],
            context: &Context.buffer)
        
        removeObserver = { playerItemObserver in
            playerItem.removeObserver(playerItemObserver,
                                  forKeyPath: "playbackLikelyToKeepUp",
                                  context: &Context.buffer)
            playerItem.removeObserver(playerItemObserver,
                                  forKeyPath: "playbackBufferFull",
                                  context: &Context.buffer)
            playerItem.removeObserver(playerItemObserver,
                                  forKeyPath: "loadedTimeRanges",
                                  context: &Context.buffer)
        }
    }
    //swiftlint:enable function_body_length
    
    private struct Context {
        static var buffer = 0
    }
    
    //swiftlint:disable cyclomatic_complexity
    override public func observeValue(forKeyPath keyPath: String?,
                                      of object: Any?,
                                      change: [NSKeyValueChangeKey : Any]?,
                                      context: UnsafeMutableRawPointer?) {
        
        guard let change = change else { fatalError("Change should not be nil!") }
        guard let context = context else { fatalError("Added observer without context!") }
        
        switch context {
        case &Context.buffer:
            guard let item = object as? AVPlayerItem else { fatalError("\(object) is not a player item") }
            
            let isReady = item.isPlaybackBufferFull || item.isPlaybackLikelyToKeepUp
            callbacks.playbackReady?(isReady)
            
            let ranges = item.loadedTimeRanges.map { $0.timeRangeValue }
            if let range = ranges.last {
                callbacks.bufferedTimeUpdated?(range.end)
                print("Asset \(item.asset) has ragne = \(Float(range.duration.value)/Float(range.duration.timescale))")
            } else {
                print("Asset \(item.asset) has no ranges")
            }
            
        default:
            super.observeValue(
                forKeyPath: keyPath,
                of: object,
                change: change,
                context: context)
        }
        
    }
    
    deinit {
        removeObserver(self)
    }
}
