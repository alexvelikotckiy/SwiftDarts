//
//  SettingsViewController.swift
//  SwiftDarts
//
//  Created by Wilson on 4/7/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import UIKit

class SettingsViewController: UITableViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var playerNameTextField: UITextField!
    @IBOutlet weak var appVersionLabel: UILabel!
    
    @IBOutlet weak var developerCell: UITableViewCell!
    
    // MARK: - IBActions
    
    // MARK: - Var & let
    let defaults = UserDefaults.standard
    
    // MARK: - Class functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerNameTextField.text = defaults.myself.username
        appVersionLabel.text = AppInfo.appVersionDescription
        
        if navigationController?.viewControllers.count == 1,
            navigationController?.viewControllers.first == self {
            let done = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(processDone)
            )
            navigationItem.rightBarButtonItem = done
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    @objc private func processDone() {
        navigationController?.dismiss(animated: true)
    }
}

// MARK: - UITableViewDelegate
extension SettingsViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        
        switch cell {
        case developerCell:
            let developerSettingsVC: DeveloperSettingsViewController = .initWithStoryboard()!
            navigationController?.pushViewController(developerSettingsVC, animated: true)
            
        default:
            break
        }
    }
}

extension SettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        if reason == .committed, let username = playerNameTextField.text {
            UserDefaults.standard.myself = Player(username: username)
        } else {
            playerNameTextField.text = UserDefaults.standard.myself.username
        }
    }
}
