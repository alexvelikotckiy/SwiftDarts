//
//  Action+Signposts.swift
//  SwiftDarts
//
//  Created by Wilson on 4/11/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import os.signpost

extension Action: CustomStringConvertible {
    var description: String {
        switch self {
        case .gameAction(let action):
            switch action {
            case .joinTeam(_):
                return "joinTeam"
            case .throwTryStart(_):
                return "throwTryStart"
            case .throwStart(_):
                return "throwStart"
            case .throwPositionMove(_):
                return "throwPositionMove"
            case .throwTryRelease(_):
                return "throwTryRelease"
            case .throwReleaseEnd(_):
                return "throwReleaseEnd"
            case .throwStatus(_):
                return "throwStatus"
            case .cameraThrowerRelease(_):
                return "cameraThrowerRelease"
            case .requestDartSync:
                return "requestDartSync"
            case .hitDart(_):
                return "hitDart"
            case .gameState(_):
                return "gameState"
            case .physics(_):
                return "physics"
            }
        case .boardSetup(let setup):
            switch setup {
            case .requestBoardLocation:
                return "requestBoardLocation"
            case .boardLocation:
                return "boardLocation"
            }
        case .startGameMusic:
            return "startGameMusic"
        }
    }
}
