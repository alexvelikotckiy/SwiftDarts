//
//  KeyPositionAnchor.swift
//  SwiftDarts
//
//  Created by Wilson on 4/14/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import ARKit

class KeyPositionAnchor: ARAnchor {
    let image: UIImage
    let mappingStatus: ARFrame.WorldMappingStatus
    
    init(image: UIImage, transform: float4x4, mappingStatus: ARFrame.WorldMappingStatus) {
        self.image = image
        self.mappingStatus = mappingStatus
        super.init(name: "KeyPosition", transform: transform)
    }
    
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    required init?(coder aDecoder: NSCoder) {
        if let image = aDecoder.decodeObject(of: UIImage.self, forKey: "image") {
            self.image = image
            let mappingValue = aDecoder.decodeInteger(forKey: "mappingStatus")
            self.mappingStatus = ARFrame.WorldMappingStatus(rawValue: mappingValue) ?? .notAvailable
        } else {
            return nil
        }
        super.init(coder: aDecoder)
    }
    
    // this is guaranteed to be called with something of the same class
    required init(anchor: ARAnchor) {
        let other = anchor as! KeyPositionAnchor
        self.image = other.image
        self.mappingStatus = other.mappingStatus
        super.init(anchor: other)
    }
    
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(image, forKey: "image")
        aCoder.encode(mappingStatus.rawValue, forKey: "mappingStatus")
    }
}
