//
//  CollisionAudioSampler.swift
//  SwiftDarts
//
//  Created by Wilson on 4/11/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation

class CollisionAudioSampler {
    /// This is a record of the Midi Note and Velocity sent to the audio sampler on this
    /// GameAudioComponent. This is synchronized to other devices sharing the game and
    /// will be played on the corresponding objects on those devices too.
    struct CollisionEvent {
        let note: UInt8
        let velocity: UInt8
        let modWheel: Float // only requires 7-bit accuracy in range 0..1
    }
}
