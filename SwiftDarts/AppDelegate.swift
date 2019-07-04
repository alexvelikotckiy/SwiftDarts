//
//  AppDelegate.swift
//  SwiftDarts
//
//  Created by Wilson on 4/3/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        let navController = UINavigationController()
        
        let controller: GameStartViewController = .initWithStoryboard()!
        navController.pushViewController(controller, animated: false)
        
        self.window?.rootViewController = navController
        self.window?.makeKeyAndVisible()
        
        UserDefaults.standard.register(defaults: UserDefaults.applicationDefaults)
        
        return true
    }
}
