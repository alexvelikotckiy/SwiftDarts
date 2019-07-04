//
//  Bundle+Helpers.swift
//  SwiftDarts
//
//  Created by Wilson on 4/11/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation

extension Bundle {
    var appIdentifier: String? {
        guard let infoDictionary = infoDictionary else { return nil }
        guard let bundleName = infoDictionary[kCFBundleIdentifierKey as String] else { return nil }
        guard let buildNumber = infoDictionary[kCFBundleVersionKey as String] else { return nil }
        guard let fullVersion = infoDictionary["CFBundleShortVersionString"] else { return nil }
        
        return "\(bundleName): \(fullVersion)-(\(buildNumber))"
    }
}
