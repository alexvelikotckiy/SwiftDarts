//
//  ViewController+Storyboard.swift
//  SwiftDarts
//
//  Created by Wilson on 4/7/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    static func initWithStoryboard<T: UIViewController>() -> T? {
        let controller = String(describing: self)
        let storyboard = UIStoryboard(name: controller, bundle: nil)
        if let viewController = storyboard.instantiateViewController(withIdentifier:"\(controller)ID") as? T {
            return viewController
        }
        print("Error create \(controller)")
        return nil
    }
}
