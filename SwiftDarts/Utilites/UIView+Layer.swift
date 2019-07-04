//
//  UIView+Layer.swift
//  SwiftDarts
//
//  Created by Wilson on 6/12/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import UIKit
import Foundation

@IBDesignable
class DesignableView: UIView {
}

extension UIView {
    
    @IBInspectable
    var darts_cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            setNeedsLayout()
        }
    }
    
    @IBInspectable
    var darts_borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
            setNeedsLayout()
        }
    }
    
    @IBInspectable
    var darts_borderColor: UIColor? {
        get {
            if let color = layer.borderColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.borderColor = color.cgColor
            } else {
                layer.borderColor = nil
            }
            setNeedsLayout()
        }
    }
    
    @IBInspectable
    var darts_shadowRadius: CGFloat {
        get {
            return layer.shadowRadius
        }
        set {
            layer.shadowRadius = newValue
            setNeedsLayout()
        }
    }
    
    @IBInspectable
    var darts_shadowOpacity: Float {
        get {
            return layer.shadowOpacity
        }
        set {
            layer.shadowOpacity = newValue
            setNeedsLayout()
        }
    }
    
    @IBInspectable
    var darts_shadowOffset: CGSize {
        get {
            return layer.shadowOffset
        }
        set {
            layer.shadowOffset = newValue
            setNeedsLayout()
        }
    }
    
    @IBInspectable
    var darts_shadowColor: UIColor? {
        get {
            if let color = layer.shadowColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.shadowColor = color.cgColor
            } else {
                layer.shadowColor = nil
            }
            setNeedsLayout()
        }
    }
    
}
