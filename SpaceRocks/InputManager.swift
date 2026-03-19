//
//  InputManager.swift
//  SpaceRocks
//
//  Created by Kevin DeKorte on 3/19/26.
//


import Foundation
import AppKit
import GameController

class InputManager {
    
    static let shared = InputManager()
    
    private init() {
        setupGamepad()
    }
    
    // MARK: - Public State
    
    var rotation: Float = 0.0       // -1 (left) to 1 (right)
    var isThrusting: Bool = false
    var isFiring: Bool = false
    var isShieldActive: Bool = false
    
    // MARK: - Keyboard State
    
    private var keysPressed: Set<UInt16> = []
    
    // Key codes
    private let leftKey: UInt16 = 123
    private let rightKey: UInt16 = 124
    private let thrustKey: UInt16 = 126   // up arrow
    private let shieldKey: UInt16 = 125   // down arrow
    private let fireKey: UInt16 = 49      // space
    
    // MARK: - Keyboard Input
    
    func keyDown(event: NSEvent) {
        keysPressed.insert(event.keyCode)
        updateKeyboardState()
    }
    
    func keyUp(event: NSEvent) {
        keysPressed.remove(event.keyCode)
        updateKeyboardState()
    }
    
    private func updateKeyboardState() {
        // Rotation
        if keysPressed.contains(leftKey) {
            rotation = 1
        } else if keysPressed.contains(rightKey) {
            rotation = -1
        } else {
            rotation = 0
        }
        
        // Thrust
        isThrusting = keysPressed.contains(thrustKey)
        
        // Shield
        isShieldActive = keysPressed.contains(shieldKey)
        
        // Fire
        isFiring = keysPressed.contains(fireKey)
    }
    
    // MARK: - Gamepad
    
    private func setupGamepad() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerConnected),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        // Handle already connected
        for controller in GCController.controllers() {
            setupController(controller)
        }
    }
    
    @objc private func controllerConnected(notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        setupController(controller)
    }
    
    private func setupController(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        
        // 🎮 Rotation (left stick X)
        gamepad.leftThumbstick.xAxis.valueChangedHandler = { [weak self] _, value in
            guard let self = self else { return }
            self.rotation = abs(value) > 0.1 ? -value : 0
        }
        
        // 🚀 Thrust (right trigger)
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
            self?.isThrusting = value > 0.1
        }
        
        // 🔥 Fire (A button)
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.isFiring = pressed
        }
        
        // 🛡️ Shield (B button)
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.isShieldActive = pressed
        }
    }
}
