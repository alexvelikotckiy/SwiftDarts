//
//  Player.swift
//  SwiftDarts
//
//  Created by Wilson on 4/3/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import simd

public struct Player {
    public let peerID: MCPeerID
    public var username: String { return peerID.displayName }
    
    public init(peerID: MCPeerID) {
        self.peerID = peerID
    }
    
    public init(username: String) {
        self.peerID = MCPeerID(displayName: username)
    }
}

extension Player: Hashable {
    public static func == (lhs: Player, rhs: Player) -> Bool {
        return lhs.peerID == rhs.peerID
    }
    
    public func hash(into hasher: inout Hasher) {
        peerID.hash(into: &hasher)
    }
}
