//
//  AppInfo.swift
//  SwiftDarts
//
//  Created by Wilson on 4/7/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation

public struct AppInfo {
    public static var appVersionDescription: String {
        return "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? 0)"
            + " (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? 0))"
    }
}
