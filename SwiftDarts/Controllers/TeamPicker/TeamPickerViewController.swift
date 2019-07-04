//
//  TeamPickerViewController.swift
//  SwiftDarts
//
//  Created by Wilson on 4/28/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import UIKit

protocol TeamPickerViewControllerDelegate: class {
    func teamPickerViewController(_ teamPickerViewController: UIViewController, didSelectTeam team: Team)
}

class TeamPickerViewController: UIViewController {
    
    weak var delegate: TeamPickerViewControllerDelegate?
    
    @IBAction func touchBlue(_ sender: Any) {
        delegate?.teamPickerViewController(self, didSelectTeam: .teamA)
        dismiss(animated: true)
    }
    
    @IBAction func touchRed(_ sender: Any) {
        delegate?.teamPickerViewController(self, didSelectTeam: .teamB)
        dismiss(animated: true)
    }
}
