//
//  SCNMaterial+Helpers.swift
//  SwiftDarts
//
//  Created by Wilson on 4/12/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import SceneKit

extension SCNMaterial {
    convenience init(diffuse: Any?) {
        self.init()
        self.diffuse.contents = diffuse
        isDoubleSided = true
        lightingModel = .physicallyBased
    }
}

extension SCNMaterialProperty {
    var simdContentsTransform: float4x4 {
        get {
            return float4x4(contentsTransform)
        }
        set(newValue) {
            contentsTransform = SCNMatrix4(newValue)
        }
    }
}
