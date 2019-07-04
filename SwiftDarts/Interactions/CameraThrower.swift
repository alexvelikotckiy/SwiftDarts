//
//  DartCatapult.swift
//  SwiftDarts
//
//  Created by Wilson on 4/22/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import SceneKit
import simd
import AVFoundation
import GameplayKit
import os.log

struct CameraThrowerProps {
    
    var minStretchTime = 0.3
    var maxStretchTime = 1.5
    
    // when launched, the pull distance is normalized and scaled to this (linear not exponential power)
    var minVelocity = 40.0
    var maxVelocity = 60.0
    
    // these animations play with these times
    var growAnimationTime = 0.2
    var dropAnimationTime = 0.3
    var grabAnimationTime = 0.15 // don't set to 0.2, ball/sling separate
    
    // before another ball appears, there is a cooldown and the grow/drop animation
    var cooldownTime = 0.5
}

protocol CameraThrowerDelegate: class {
    func cameraThrowerDidBeginGrap(_ cameraThrower: CameraThrower)
    func cameraThrowerDidMove(_ cameraThrower: CameraThrower)
    func cameraThrowerDidLaunch(_ cameraThrower: CameraThrower)
}

class CameraThrower: GameObject, Thrower {
    
    // This is the thrower base (just empty node)
    let base: SCNNode
        
    var isGrabbed: Bool = false
    
    var player: Player?
    var team: Team = .none
    
    private var dartCanBeThrowed = false
    private var lastStretch: Double = 0.0
    
    private(set) var disabled = false
    
    // Last cameraInfo used to computed premature release (such as when other ball hit the catapult)
    private(set) var lastCameraInfo = CameraInfo(transform: .identity)
    
    // Track the start of the grab.  Can use for time exceeded auto-launch.
    private var firstGrabTime: Double = 0
    // Stores the last launch of a projectile.  Cooldown while sling animates and bounces back.
    private var lastLaunchTime: Double = 0
    
    // Return scaled stretch value between 0 and 1
    private var stretch: Double {
        let stretchTime = GameTime.time - firstGrabTime
        let seconds = clamp(stretchTime, props.minStretchTime, props.maxStretchTime)
        let scaled = (seconds - props.minStretchTime) / (props.maxStretchTime - props.minStretchTime)
        return scaled
    }
    
    // This a placeholder that we make visible/invisible for the pull that represents the projectile to launch.
    // That way it can be tested against the stretch of the sling.
    private(set) var projectile: SCNNode?
    private(set) var projectileType = ProjectileType.none
    private var projectileScale: float3 = float3(repeating: 1)
    
    private var props = CameraThrowerProps()
    var coolDownTime: TimeInterval { return props.cooldownTime }
    
    weak var delegate: CameraThrowerDelegate?
    
    // Whether the ball in the sling is visible or partially visible.
    var dartVisible: DartVisible = .hidden {
        didSet {
            updateFakeProjectileVisibility()
        }
    }
    
    enum DartVisible {
        case hidden
        case partial
        case visible
    }
    
    private func updateFakeProjectileVisibility() {
        switch dartVisible {
        case .hidden:
            projectile?.opacity = 1.0
            projectile?.isHidden = true
            projectile?.simdWorldPosition = base.simdWorldPosition
            projectile?.simdScale = float3(repeating: 0.01)

        case .partial:
            projectile?.opacity = 1.0
            projectile?.isHidden = false
            animateSpawnDart()

        case .visible:
            projectile?.opacity = 1.0
            projectile?.isHidden = false
            // it's in the strap fromn .partial animation
        }
    }
    
    private func animateSpawnDart() {
        // the block is the total time of the transcation, so sub-blocks are limited by that too
        SCNTransaction.animate(duration: props.growAnimationTime, animations: {
            
            projectile?.simdScale = projectileScale
        }, completion: {
            SCNTransaction.animate(duration: self.props.dropAnimationTime, animations: {
                guard let _ = self.projectile else { return }
                self.projectile?.simdWorldPosition = self.base.simdWorldPosition
            }, completion: {
                // only allow the ball to be grabbed after animation completes
                self.dartCanBeThrowed = true
            })
        })
    }
    
    init(prototypeNode: SCNNode, identifier: Int?,
         player: Player? = nil, team: Team? = nil, gamedefs: [String: Any]) {
        
        base = prototypeNode.clone()
        base.copyGeometryAndMaterials()
        base.name = "CameraThrower"
        
        self.player = player
        self.team = team ?? .none
        
        super.init(node: base, index: identifier, gamedefs: gamedefs, alive: false, server: false)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setProjectileType(projectileType: ProjectileType, projectile: SCNNode) {
        self.projectile?.removeFromParentNode()
        self.projectile = projectile
        self.projectileType = projectileType
        projectileScale = projectile.simdScale
        
        dartVisible = .hidden
        updateFakeProjectileVisibility()
    }
    
    func updateProps() {
        
        let obj = self
        
        props.minStretchTime = obj.propDouble("minStretchTime")!
        props.maxStretchTime = obj.propDouble("maxStretchTime")!

        props.minVelocity = obj.propDouble("minVelocity")!
        props.maxVelocity = obj.propDouble("maxVelocity")!

        props.cooldownTime = obj.propDouble("cooldownTime")!
    }
    
    func canThrow(cameraRay: Ray) -> Bool {
        if player != UserDefaults.standard.myself {
            return false
        }
        if isGrabbed {
            return false
        }
        if disabled {
            return false
        }
        if !dartCanBeThrowed {
            return false
        }
        return true
    }
    
    func onServerStartTryThrow() {
        guard !isGrabbed else { os_log(.error, "Trying to grab already grabed thrower"); return }
        os_log(.debug, "(Server) Thrower%d grabbed by player", index)
        dartCanBeThrowed = false
    }
    
    func onStartThrow() {
        guard !isGrabbed else { os_log(.error, "Trying to grab already grabed thrower"); return }
        os_log(.debug, "(Server) Throwert%d grabbed by player", index)
        
        dartCanBeThrowed = true
        
        // do local effects/haptics if this event was generated by the current player
        delegate?.cameraThrowerDidBeginGrap(self)
    }
    
    func onGrab(_ cameraInfo: CameraInfo) {
        firstGrabTime = GameTime.time
        
        dartVisible = .visible
        
        alignThrower(cameraInfo: cameraInfo)
        animateGrab(basePosition)
    }
    
    func animateGrab(_ ballPosition: float3) {
        // here we want to animate the rotation of the current yaw to the new yaw
        // and also animate the strap moving to the center of the view

        // drop from ballOriginInactiveAbove to ballOriginInactive in a transaction
        SCNTransaction.animate(duration: props.grabAnimationTime, animations: {

            // animate the ball to the player
            projectile?.simdWorldPosition = ballPosition
        })
    }
    
    private func alignThrower(cameraInfo: CameraInfo) {
        let cameraRay = cameraInfo.ray
        
        let distancePullToCamera: Float = 6
        let throwerShiftDown: Float = 2
        
        var targetThrowerPosition = cameraRay.position + cameraRay.direction * distancePullToCamera

        let cameraDown = -normalize(cameraInfo.transform.columns.1).xyz
        targetThrowerPosition += cameraDown * throwerShiftDown

        base.simdWorldPosition = targetThrowerPosition
    }
    
    private func alignProjectile(cameraInfo: CameraInfo) {
        guard let projectile = projectile else { fatalError("Grabbed but no projectile") }
        alignProjectile(projectile, cameraInfo: cameraInfo)
    }
    
    func alignProjectile(_ projectile: SCNNode, cameraInfo: CameraInfo? = nil) {
        let cameraInfo = cameraInfo ?? lastCameraInfo
        let cameraRay = cameraInfo.ray
        let targetDartPosition = basePosition
        let projectileFront = targetDartPosition + cameraRay.direction
        
        projectile.simdWorldPosition = targetDartPosition
        projectile.simdLook(at: projectileFront)
        projectile.physicsBody?.resetTransform()
    }
    
    // MARK: - Dart Move
    var basePosition: float3 {
        return base.simdWorldPosition
    }
    
    func move(cameraInfo: CameraInfo) {
        guard isGrabbed else { os_log(.error, "trying to move before grabbing"); return }
        
        lastCameraInfo = cameraInfo
        
        // Set catapult position
        alignThrower(cameraInfo: cameraInfo)
        
        guard let _ = projectile else { fatalError("Grabbed but no projectile") }
        alignProjectile(cameraInfo: cameraInfo)

        delegate?.cameraThrowerDidMove(self)
    }
    
    func onLaunch(velocity: GameVelocity) {
        guard isGrabbed else { return }
        
        // can't grab again until the cooldown animations play
        dartCanBeThrowed = false
        
        // update local information for current player if that is what is pulling the catapult
        os_log(.debug, "Thrower%d launched", index)
        
        delegate?.cameraThrowerDidMove(self)
        delegate?.cameraThrowerDidLaunch(self)
        
        // set the ball to invisible
        dartVisible = .hidden
        
        // record the last launch time, and enforce a cooldown before ball reappears (need an update call then?)
        lastLaunchTime = GameTime.time
    }
    
    func tryGetLaunchVelocity(cameraInfo: CameraInfo) -> GameVelocity? {
        guard let projectile = projectile else {
            fatalError("Trying to launch without a dart")
        }
        
        move(cameraInfo: cameraInfo)
        
        let stretchNormalized = self.stretch
        
        let velocity = props.minVelocity * (1.0 - stretchNormalized) +
            props.maxVelocity * stretchNormalized
        
        let launchDir = cameraInfo.ray.direction
        let liftFactor = Float(0.05) * abs(1.0 - dot(launchDir, float3(0.0, 1.0, 0.0)))
        let lift = float3(0.0, 1.0, 0.0) * Float(velocity) * liftFactor
        guard !launchDir.hasNaN else { return nil }
        
        let velocityVector = GameVelocity(origin: projectile.simdWorldPosition, vector: launchDir * Float(velocity) + lift)
        
        return velocityVector
    }
    
    func releaseGrab() {
        // TODO: Maybe we should clean up after a throw
    }
    
    func update(cameraInfo: CameraInfo) {
        lastCameraInfo = cameraInfo
        
        // Set thrower position
        alignThrower(cameraInfo: cameraInfo)
        
        if disabled {
            dartVisible = .hidden
            return
        }
        
        if dartVisible == .hidden {
            // make sure cooldown doesn't occur starting the ball animation
            // until a few seconds after loading the level
            if lastLaunchTime == 0 {
                lastLaunchTime = GameTime.time
            }
            
            // only allow grabbing the ball after the cooldown animations play (grow + drop)
            let timeElapsed = GameTime.time - lastLaunchTime
            var timeForCooldown = props.cooldownTime - props.growAnimationTime - props.dropAnimationTime
            if timeForCooldown < 0.01 {
                os_log(.error, "cooldown time needs to be long enough to play animations")
                timeForCooldown = 0.0
            }
            let startCooldownAnimation = timeElapsed > timeForCooldown
            if startCooldownAnimation {
                // show the ball at the ballOrigin, that's in the sling
                dartVisible = .partial
            }
        }
        
        if dartCanBeThrowed, !isGrabbed {
            alignProjectile(cameraInfo: cameraInfo)
        }
    }
    
    override func generatePhysicsData() -> PhysicsNodeData? {
        let displayName = player?.username ?? ""
        return physicsNode.map { PhysicsNodeData(node: $0, alive: isAlive, playerID: displayName, team: team) }
    }
}
