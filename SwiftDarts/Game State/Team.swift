//
//  Dart.swift
//  SwiftDarts
//
//  Created by Wilson on 4/12/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import SceneKit
import simd
import AVFoundation
import os.log

extension UIColor {
    convenience init(hexRed: UInt8, green: UInt8, blue: UInt8) {
        let fred = CGFloat(hexRed) / CGFloat(255)
        let fgreen = CGFloat(green) / CGFloat(255)
        let fblue = CGFloat(blue) / CGFloat(255)
        
        self.init(red: fred, green: fgreen, blue: fblue, alpha: 1.0)
    }
}

struct Score {
    var team: Team
    var value: Int
}

extension Score: BitStreamCodable {
    func encode(to bitStream: inout WritableBitStream) {
        team.encode(to: &bitStream)
        bitStream.appendUInt32(UInt32(value), numberOfBits: 4)
    }
    
    init(from bitStream: inout ReadableBitStream) throws {
        team = try Team(from: &bitStream)
        value = Int(try bitStream.readUInt32(numberOfBits: 4))
    }
}

public enum Team: Int {
    case none = 0 // default
    case teamA
    case teamB
    
    var description: String {
        switch self {
        case .none: return NSLocalizedString("none", comment: "Team name")
        case .teamA: return NSLocalizedString("Blue", comment: "Team name")
        case .teamB: return NSLocalizedString("Red", comment: "Team name")
        }
    }
    
    var color: UIColor {
        switch self {
        case .none: return .white
        case .teamA: return UIColor(hexRed: 120, green: 162, blue: 255)
        case .teamB: return UIColor(hexRed: 255, green: 105, blue: 112)
        }
    }
}

extension Team: BitStreamCodable {
    // We do not use the stanard enum encoding here to implement a tiny
    // optimization;
    func encode(to bitStream: inout WritableBitStream) {
        switch self {
        case .none:
            bitStream.appendBool(false)
        case .teamA:
            bitStream.appendBool(true)
            bitStream.appendBool(true)
        case .teamB:
            bitStream.appendBool(true)
            bitStream.appendBool(false)
        }
    }
    
    init(from bitStream: inout ReadableBitStream) throws {
        let hasTeam = try bitStream.readBool()
        if hasTeam {
            let isTeamA = try bitStream.readBool()
            self = isTeamA ? .teamA : .teamB
        } else {
            self = .none
        }
    }
}
