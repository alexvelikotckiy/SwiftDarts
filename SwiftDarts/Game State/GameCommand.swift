//
//  GameCommand.swift
//  SwiftDarts
//
//  Created by Wilson on 4/11/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import simd
import MultipeerConnectivity

/// - Tag: GameCommand
struct GameCommand {
    var player: Player?
    var action: Action
}

enum GameBoardLocation {
    case worldMapData(Data)
    case manual
    
    enum CodingKey: UInt32, CaseIterable {
        case worldMapData
        case manual
    }
}

enum BoardSetupAction {
    case requestBoardLocation
    case boardLocation(GameBoardLocation)
    
    enum CodingKey: UInt32, CaseIterable {
        case requestBoardLocation
        case boardLocation
    }
}

struct Ray {
    var position: float3
    var direction: float3
    static var zero: Ray { return Ray(position: float3(), direction: float3()) }
}

struct CameraInfo {
    var transform: float4x4
    var ray: Ray {
        let position = transform.translation
        let direction = normalize((transform * float4(0, 0, -1, 0)).xyz)
        return Ray(position: position, direction: direction)
    }
}

// GameVelocity stores the origin and vector of velocity.
// It is similar to ray, but whereas ray will have normalized direction, the .vector is the velocity vector
struct GameVelocity {
    var origin: float3
    var vector: float3
    static var zero: GameVelocity { return GameVelocity(origin: float3(), vector: float3()) }
}

struct ThrowData {
    var throwerID: Int
    var projectileType: ProjectileType
    var velocity: GameVelocity
}

struct ThrowInfo {
    var throwableID: Int?
    var cameraInfo: CameraInfo
}

struct HitDart {
    var dartID: Int
    var score: Score
}

/// - Tag: GameAction
enum GameAction {
    case joinTeam(Team)
    
    case throwTryStart(ThrowInfo)
    case throwStart(ThrowInfo)
    case throwPositionMove(ThrowInfo)
    case throwTryRelease(ThrowInfo)
    case throwReleaseEnd(ThrowInfo)
    case throwStatus(ThrowInfo)
    
    case cameraThrowerRelease(ThrowData)
    
    case requestDartSync
    case hitDart(HitDart)
    case gameState(GameState)
    
    case physics(PhysicsSyncData)
    
    private enum CodingKey: UInt32, CaseIterable {
        case joinTeam
        
        case throwTryStart
        case throwCanStart
        case throwPositionMove
        case throwTryRelease
        case throwReleaseEnd
        case throwStatus
        
        case cameraThrowerRelease
        
        case requestDartSync
        case hitDart
        case gameState
        
        case physicsSyncData
    }
}

struct StartGameMusicTime: CustomDebugStringConvertible {
    let startNow: Bool
    let timestamps: [TimeInterval]
    
    let countBits = 4
    let maxCount = 1 << 4
    
    init(startNow: Bool, timestamps: [TimeInterval]) {
        self.startNow = startNow
        self.timestamps = timestamps
    }
    
    var debugDescription: String {
        return "<StartGameMusicTime startNow=\(startNow) times=\(timestamps)>"
    }
}

enum Action {
    case gameAction(GameAction)
    case boardSetup(BoardSetupAction)
    case startGameMusic(StartGameMusicTime)
}

// MARK: - BitStreamCodable realization
extension GameAction: BitStreamCodable {
    func encode(to bitStream: inout WritableBitStream) throws {
        switch self {
        case .joinTeam(let data):
            bitStream.appendEnum(CodingKey.joinTeam)
            data.encode(to: &bitStream)
        case .throwTryStart(let data):
            bitStream.appendEnum(CodingKey.throwTryStart)
            data.encode(to: &bitStream)
        case .throwStart(let data):
            bitStream.appendEnum(CodingKey.throwCanStart)
            data.encode(to: &bitStream)
        case .throwPositionMove(let data):
            bitStream.appendEnum(CodingKey.throwPositionMove)
            data.encode(to: &bitStream)
        case .throwTryRelease(let data):
            bitStream.appendEnum(CodingKey.throwTryRelease)
            data.encode(to: &bitStream)
        case .throwReleaseEnd(let data):
            bitStream.appendEnum(CodingKey.throwReleaseEnd)
            data.encode(to: &bitStream)
        case .throwStatus(let data):
            bitStream.appendEnum(CodingKey.throwStatus)
            data.encode(to: &bitStream)
        case .cameraThrowerRelease(let data):
            bitStream.appendEnum(CodingKey.cameraThrowerRelease)
            data.encode(to: &bitStream)
        case .requestDartSync:
            bitStream.appendEnum(CodingKey.requestDartSync)
        case .hitDart(let coords):
            bitStream.appendEnum(CodingKey.hitDart)
            coords.encode(to: &bitStream)
        case .gameState(let data):
            bitStream.appendEnum(CodingKey.gameState)
            data.encode(to: &bitStream)
        case .physics(let data):
            bitStream.appendEnum(CodingKey.physicsSyncData)
            data.encode(to: &bitStream)
        }
    }
    
    init(from bitStream: inout ReadableBitStream) throws {
        let key: CodingKey = try bitStream.readEnum()
        switch key {
        case .joinTeam:
            let data = try Team(from: &bitStream)
            self = .joinTeam(data)
            
        case .throwTryStart:
            let data = try ThrowInfo(from: &bitStream)
            self = .throwTryStart(data)
        case .throwCanStart:
            let data = try ThrowInfo(from: &bitStream)
            self = .throwStart(data)
        case .throwPositionMove:
            let data = try ThrowInfo(from: &bitStream)
            self = .throwPositionMove(data)
        case .throwTryRelease:
            let data = try ThrowInfo(from: &bitStream)
            self = .throwTryRelease(data)
        case .throwReleaseEnd:
            let data = try ThrowInfo(from: &bitStream)
            self = .throwReleaseEnd(data)
        case .throwStatus:
            let data = try ThrowInfo(from: &bitStream)
            self = .throwStatus(data)
            
        case .cameraThrowerRelease:
            let data = try ThrowData(from: &bitStream)
            self = .cameraThrowerRelease(data)
            
        case .requestDartSync:
            self = .requestDartSync
        case .hitDart:
            let data = try HitDart(from: &bitStream)
            self = .hitDart(data)
        case .gameState:
            let data = try GameState(from: &bitStream)
            self = .gameState(data)
            
        case .physicsSyncData:
            let data = try PhysicsSyncData(from: &bitStream)
            self = .physics(data)
        }
    }
}

extension Action: BitStreamCodable {
    private enum CodingKey: UInt32, CaseIterable {
        case gameAction
        case boardSetup
        case startGameMusic
    }

    func encode(to bitStream: inout WritableBitStream) throws {
        switch self {
        case .gameAction(let gameAction):
            bitStream.appendEnum(CodingKey.gameAction)
            try gameAction.encode(to: &bitStream)
        case .boardSetup(let boardSetup):
            bitStream.appendEnum(CodingKey.boardSetup)
            boardSetup.encode(to: &bitStream)
        case .startGameMusic(let timeData):
            bitStream.appendEnum(CodingKey.startGameMusic)
            timeData.encode(to: &bitStream)
        }
    }

    init(from bitStream: inout ReadableBitStream) throws {
        let code: CodingKey = try bitStream.readEnum()
        switch code {
        case .gameAction:
            let gameAction = try GameAction(from: &bitStream)
            self = .gameAction(gameAction)
        case .boardSetup:
            let boardAction = try BoardSetupAction(from: &bitStream)
            self = .boardSetup(boardAction)
        case .startGameMusic:
            let timeData = try StartGameMusicTime(from: &bitStream)
            self = .startGameMusic(timeData)
        }
    }
}

extension GameBoardLocation: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        let key: CodingKey = try bitStream.readEnum()
        switch key {
        case .worldMapData:
            let data = try bitStream.readData()
            self = .worldMapData(data)
        case .manual:
            self = .manual
        }
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        switch self {
        case .worldMapData(let data):
            bitStream.appendEnum(CodingKey.worldMapData)
            bitStream.append(data)
        case .manual:
            bitStream.appendEnum(CodingKey.manual)
        }
    }
}

extension BoardSetupAction: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        let key: CodingKey = try bitStream.readEnum()
        switch key {
        case .requestBoardLocation:
            self = .requestBoardLocation
        case .boardLocation:
            let location = try GameBoardLocation(from: &bitStream)
            self = .boardLocation(location)
        }
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        switch self {
        case .requestBoardLocation:
            bitStream.appendEnum(CodingKey.requestBoardLocation)
        case .boardLocation(let location):
            bitStream.appendEnum(CodingKey.boardLocation)
            location.encode(to: &bitStream)
        }
    }
}

extension GameVelocity: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        origin = try float3(from: &bitStream)
        vector = try float3(from: &bitStream)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        origin.encode(to: &bitStream)
        vector.encode(to: &bitStream)
    }
}

extension ProjectileType: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        self = try bitStream.readEnum()
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendEnum(self)
    }
}

extension ThrowData: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        throwerID = Int(try bitStream.readUInt32(numberOfBits: 4))
        projectileType = try ProjectileType(from: &bitStream)
        velocity = try GameVelocity(from: &bitStream)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendUInt32(UInt32(throwerID), numberOfBits: 4)
        projectileType.encode(to: &bitStream)
        velocity.encode(to: &bitStream)
    }
}

extension CameraInfo: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        self.init(transform: try float4x4(from: &bitStream))
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        transform.encode(to: &bitStream)
    }
}

extension Ray: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        position = try float3(from: &bitStream)
        direction = try float3(from: &bitStream)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        position.encode(to: &bitStream)
        direction.encode(to: &bitStream)
    }
}

extension ThrowInfo: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        let hasId = try bitStream.readBool()
        if hasId {
            throwableID = Int(try bitStream.readUInt32(numberOfBits: 4))
        } else {
            throwableID = nil
        }
        cameraInfo = try CameraInfo(from: &bitStream)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        if let thrower = throwableID {
            bitStream.appendBool(true)
            bitStream.appendUInt32(UInt32(thrower), numberOfBits: 4)
        } else {
            bitStream.appendBool(false)
        }
        cameraInfo.encode(to: &bitStream)
    }
}

extension HitDart: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        dartID = Int(try bitStream.readUInt32(numberOfBits: 4))
        score = try Score(from: &bitStream)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendUInt32(UInt32(dartID), numberOfBits: 4)
        score.encode(to: &bitStream)
    }
}

extension StartGameMusicTime: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        self.startNow = try bitStream.readBool()
        let count = try bitStream.readUInt32(numberOfBits: countBits)
        var timestamps = [TimeInterval]()
        for _ in 0..<count {
            let milliseconds = try bitStream.readUInt32()
            timestamps.append(TimeInterval(Double(milliseconds) / 1000.0))
        }
        self.timestamps = timestamps
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendBool(startNow)
        guard timestamps.count < maxCount else {
            fatalError("Cannot encode more than \(maxCount) timestamps")
        }
        bitStream.appendUInt32(UInt32(timestamps.count), numberOfBits: countBits)
        for timestamp in timestamps {
            bitStream.appendUInt32(UInt32(timestamp * 1000.0))
        }
    }
}

extension float3: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        let x = try bitStream.readFloat()
        let y = try bitStream.readFloat()
        let z = try bitStream.readFloat()
        self.init(x, y, z)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendFloat(x)
        bitStream.appendFloat(y)
        bitStream.appendFloat(z)
    }
}

extension float4: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        let x = try bitStream.readFloat()
        let y = try bitStream.readFloat()
        let z = try bitStream.readFloat()
        let w = try bitStream.readFloat()
        self.init(x, y, z, w)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendFloat(x)
        bitStream.appendFloat(y)
        bitStream.appendFloat(z)
        bitStream.appendFloat(w)
    }
}

extension float4x4: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        self.init()
        self.columns.0 = try float4(from: &bitStream)
        self.columns.1 = try float4(from: &bitStream)
        self.columns.2 = try float4(from: &bitStream)
        self.columns.3 = try float4(from: &bitStream)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        columns.0.encode(to: &bitStream)
        columns.1.encode(to: &bitStream)
        columns.2.encode(to: &bitStream)
        columns.3.encode(to: &bitStream)
    }
}

extension String: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        let data = try bitStream.readData()
        if let value = String(data: data, encoding: .utf8) {
            self = value
        } else {
            throw BitStreamError.encodingError
        }
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        if let data = data(using: .utf8) {
            bitStream.append(data)
        }
    }
}
