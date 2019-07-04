//
//  GrabInteraction.swift
//  SwiftDarts
//
//  Created by Wilson on 4/21/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import SceneKit

protocol Thrower: GameObject {
    var team: Team { get set }
    var player: Player? { get set }
    var isGrabbed: Bool { get set }
    
    func canThrow(cameraRay: Ray) -> Bool

    func move(cameraInfo: CameraInfo)
}

protocol ThrowInteractionDelegate: class {
    func didUpdateThrowers(throwers: [Int: Thrower])
    func shouldForceRelease(thrower: Thrower) -> Bool
    func onServerTryStartThrow(thrower: Thrower, cameraInfo: CameraInfo, player: Player)
    func onTrowStart(thrower: Thrower, cameraInfo: CameraInfo, player: Player)
    func onServerRelease(thrower: Thrower, cameraInfo: CameraInfo, player: Player)
    func onUpdateThrowStatus(thrower: Thrower, cameraInfo: CameraInfo)
}

class ThrowInteraction: Interaction {
    weak var delegate: InteractionDelegate?
    weak var throwDelegate: ThrowInteractionDelegate?
    
    private(set) var throwers = [Int: Thrower]() {
        didSet {
            guard let throwDelegate = throwDelegate else { return }
            throwDelegate.didUpdateThrowers(throwers: throwers)
        }
    }
    
    var isTouching = false
    var activeThrower: Thrower?
    
    required init(delegate: InteractionDelegate) {
        self.delegate = delegate
    }
    
    func addThrower(_ thrower: Thrower) {
        throwers[thrower.index] = thrower
    }
    
    func removeThrower(_ thrower: Thrower) {
        throwers.removeValue(forKey: thrower.index)
    }
    
    func handleTouch(_ type: TouchType, camera: Ray) {
        if type == .began {
            if throwerToThrow(cameraRay: camera) != nil {
                isTouching = true
            }
        } else if type == .ended {
            isTouching = false
        }
    }
    
    func update(cameraInfo: CameraInfo) {
        guard let delegate = delegate, let throwDelegate = throwDelegate else { fatalError("No Delegate") }

        if isTouching && activeThrower == nil {
            guard GameTime.frameCount % 3 == 0 else { return } // Only send messages at 20 fps to save bandwidth
            
            if let thrower = throwerToThrow(cameraRay: cameraInfo.ray) {
                let info = ThrowInfo(throwableID: thrower.index, cameraInfo: cameraInfo)
                delegate.dispatchActionToServer(gameAction: .throwTryStart(info))
            }
        }
        
        if let thrower = activeThrower {
            thrower.move(cameraInfo: cameraInfo)
            
            if !isTouching || throwDelegate.shouldForceRelease(thrower: thrower) {
                guard GameTime.frameCount % 3 == 0 else { return } // Only send messages at 20 fps to save bandwidth
                let data = ThrowInfo(throwableID: thrower.index, cameraInfo: cameraInfo)
                delegate.dispatchActionToServer(gameAction: .throwTryRelease(data))
                return
            }
            
            let data = ThrowInfo(throwableID: thrower.index, cameraInfo: cameraInfo)
            delegate.dispatchActionToServer(gameAction: .throwPositionMove(data))
        }
    }
    
    func throwerToThrow(cameraRay: Ray) -> Thrower? {
        // Find first thrower to throw
        for thrower in throwers.values where thrower.canThrow(cameraRay: cameraRay) {
            return thrower
        }
        return nil
    }
    
    func handle(gameAction: GameAction, player: Player) {
        guard let delegate = delegate else { fatalError("No delegate") }
        switch gameAction {
        case .throwTryStart(let data):
            handleThrowTryStartAction(data: data, player: player, delegate: delegate)
        case .throwStart(let data):
            handleThrowStart(data: data, player: player, delegate: delegate)
        case .throwPositionMove(let data):
            handleThrowPositionMove(data: data, player: player, delegate: delegate)
        case .throwTryRelease(let data):
            handleThrowTryReleaseAction(data: data, player: player, delegate: delegate)
        case .throwReleaseEnd(let data):
            handleThrowReleaseEndAction(data: data, player: player, delegate: delegate)
        case .throwStatus(let status):
            handleThrowStatusAction(status: status)
        default:
            return
        }
    }
    
    func handleThrowTryStartAction(data: ThrowInfo, player: Player, delegate: InteractionDelegate) {
        guard let throwDelegate = throwDelegate else { fatalError("ThrowDelegate not set") }
        
        guard delegate.isServer else { return }
        // TODO: Maybe we should add a thrower instance when it is unknown
        // Here we should get a fatal error
        let thrower = throwerByID(data.throwableID)
        throwDelegate.onServerTryStartThrow(thrower: thrower, cameraInfo: data.cameraInfo, player: player)
        
        let newData = ThrowInfo(throwableID: thrower.index, cameraInfo: data.cameraInfo)
        delegate.dispatchToPlayer(gameAction: .throwStart(newData), player: player)
        
        handleThrowStatusAction(status: newData)
        delegate.serverDispatchActionToAll(gameAction: .throwStatus(newData))
    }
    
    func handleThrowStart(data: ThrowInfo, player: Player, delegate: InteractionDelegate) {
        guard let throwDelegate = throwDelegate else { fatalError("ThrowDelegate not set") }
        let thrower = throwerByID(data.throwableID)
        activeThrower = thrower
        throwDelegate.onTrowStart(thrower: thrower, cameraInfo: data.cameraInfo, player: player)
    }
    
    func handleThrowTryReleaseAction(data: ThrowInfo, player: Player, delegate: InteractionDelegate) {
        guard let throwDelegate = throwDelegate else { fatalError("ThrowDelegate not set") }
        guard delegate.isServer else { return }
        
        // Launch if player already grabbed a grabbable
        let thrower = throwerByID(data.throwableID)
        guard thrower.isGrabbed else { return }
        
        throwDelegate.onServerRelease(thrower: thrower, cameraInfo: data.cameraInfo, player: player)
        
        let newData = ThrowInfo(throwableID: thrower.index, cameraInfo: data.cameraInfo)
        delegate.dispatchToPlayer(gameAction: .throwReleaseEnd(newData), player: player)
    }
    
    func handleThrowReleaseEndAction(data: ThrowInfo, player: Player, delegate: InteractionDelegate) {
        isTouching = false
    }
    
    func handleThrowPositionMove(data: ThrowInfo, player: Player, delegate: InteractionDelegate) {
        if let throwerID = data.throwableID, let thrower = throwers[throwerID] {
            thrower.move(cameraInfo: data.cameraInfo)
        }
    }
    
    func handleThrowStatusAction(status: ThrowInfo) {
        guard let throwDelegate = throwDelegate else { fatalError("ThrowDelegate not set") }
        guard let throwerID = status.throwableID, let thrower = throwers[throwerID] else {
            return
//            fatalError("No Thrower \(status.throwableID ?? -1)")
        }
        thrower.isGrabbed = true
        throwDelegate.onUpdateThrowStatus(thrower: thrower, cameraInfo: status.cameraInfo)
    }
    
    // MARK: - Helper
    private func throwerByID(_ throwerID: Int?) -> Thrower {
        guard let throwerID = throwerID, let thrower = throwers[throwerID] else {
            fatalError("Thrower not found")
        }
        return thrower
    }
}
