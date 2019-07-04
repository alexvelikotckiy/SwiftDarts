//
//  UIView+Helpers.swift
//  SwiftDarts
//
//  Created by Wilson on 4/14/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    
    func fadeInFadeOut(duration: TimeInterval) {
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseIn, animations: {
            self.alpha = 1.0
        }, completion: { finished in
            if finished {
                self.isHidden = false
                UIView.animate(withDuration: duration, delay: 1.0, options: .curveEaseOut, animations: {
                    self.alpha = 0.0
                }, completion: { _ in
                    self.isHidden = true
                })
            } else {
                self.isHidden = true
            }
        })
    }    
}
