//
//  GameBrowser.swift
//  SwiftDarts
//
//  Created by Wilson on 4/11/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import os.log

struct SwiftDartsGameService {
    static let playerService = "swiftdarts-p"
    static let spectatorService = "swiftdarts-s"
}

struct SwiftDartsGameAttribute {
    static let name = "SwiftDartsGameAttributeName"
    static let location = "LocationAttributeName"
    static let appIdentifier = "AppIdentifierAttributeName"
}

protocol GameBrowserDelegate: class {
    func gameBrowser(_ browser: GameBrowser, sawGames: [NetworkGame])
}

class GameBrowser: NSObject {
    private let myself: Player
    private let serviceBrowser: MCNearbyServiceBrowser
    weak var delegate: GameBrowserDelegate?
    
    fileprivate var games: Set<NetworkGame> = []
    
    init(myself: Player) {
        self.myself = myself
        self.serviceBrowser = MCNearbyServiceBrowser(peer: myself.peerID, serviceType: SwiftDartsGameService.playerService)
        super.init()
        self.serviceBrowser.delegate = self
    }
    
    deinit {
        stop()
    }
    
    func start() {
        os_log(.info, "looking for peers")
        serviceBrowser.startBrowsingForPeers()
    }
    
    func stop() {
        os_log(.info, "stopping the search for peers")
        serviceBrowser.stopBrowsingForPeers()
    }
    
    func join(game: NetworkGame) -> NetworkSession? {
        guard games.contains(game) else { return nil }
        let session = NetworkSession(myself: myself, asServer: false, host: game.host)
        serviceBrowser.invitePeer(game.host.peerID, to: session.session, withContext: nil, timeout: 30)
        return session
    }
}

/// - Tag: GameBrowser-MCNearbyServiceBrowserDelegate
extension GameBrowser: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        os_log(.info, "found peer %@", peerID)
        guard peerID != myself.peerID else {
            os_log(.info, "found myself, ignoring")
            return
        }
        guard let appIdentifier = info?[SwiftDartsGameAttribute.appIdentifier],
            appIdentifier == Bundle.main.appIdentifier else {
                os_log(.info, "peer appIdentifier %s doesn't match, ignoring", info?[SwiftDartsGameAttribute.appIdentifier] ?? "(nil)")
                return
        }
        DispatchQueue.main.async {
            let player = Player(peerID: peerID)
            let gameName = info?[SwiftDartsGameAttribute.name]
            
            let game = NetworkGame(host: player, name: gameName)
            self.games.insert(game)
            self.delegate?.gameBrowser(self, sawGames: Array(self.games))
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        os_log(.info, "lost peer id %@", peerID)
        DispatchQueue.main.async {
            self.games = self.games.filter { $0.host.peerID != peerID }
            self.delegate?.gameBrowser(self, sawGames: Array(self.games))
        }
    }
    
    func refresh() {
        delegate?.gameBrowser(self, sawGames: Array(games))
    }
}
