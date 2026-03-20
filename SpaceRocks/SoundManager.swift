//
//  SoundManager.swift
//  SpaceRocks
//
//  Created by Kevin DeKorte on 3/18/26.
//


import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    var thrustPlayer: AVAudioPlayer?
    var backgroundMusicPlayer: AVAudioPlayer?
    
    func preloadSounds() {
        preloadThrust()
        preloadBackgroundMusic()
    }
    
    func preloadThrust() {
        if let url = Bundle.main.url(forResource: "thrust", withExtension: "caf") {
            thrustPlayer = try? AVAudioPlayer(contentsOf: url)
            thrustPlayer?.prepareToPlay() // loads into memory
        }
    }
    
    func preloadBackgroundMusic() {
        if let url = Bundle.main.url(forResource: "bg_heartbeat", withExtension: "caf") {
            backgroundMusicPlayer = try? AVAudioPlayer(contentsOf: url)
            backgroundMusicPlayer?.prepareToPlay() 
        }
    }
    
    func startThrust() {
        thrustPlayer?.numberOfLoops = -1
        thrustPlayer?.play()
    }
    
    func stopThrust() {
        thrustPlayer?.stop()
    }
    
    func startBackgroundMusic() {
        backgroundMusicPlayer?.numberOfLoops = -1
        //backgroundMusicPlayer?.volume = 0.2
        backgroundMusicPlayer?.play()
    }
    
    func stopBackgroundMusic() {
        backgroundMusicPlayer?.stop()
    }
    
    func setBackgroundMusicSpeed(_ rate: Float) {
        backgroundMusicPlayer?.enableRate = true
        backgroundMusicPlayer?.rate = rate
    }
}
