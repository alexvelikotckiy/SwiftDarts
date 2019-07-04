//
//  NetworkGame.swift
//  SwiftDarts
//
//  Created by Wilson on 4/12/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation

struct NetworkGame: Hashable {
    var name: String
    var host: Player
    
    init(host: Player, name: String? = nil) {
        self.host = host
        self.name = name ?? "\(host.username)'s Game"
    }
}
