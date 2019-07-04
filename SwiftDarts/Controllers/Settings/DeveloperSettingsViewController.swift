//
//  DeveloperSettingsViewController.swift
//  SwiftDarts
//
//  Created by Wilson on 4/7/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import UIKit

class DeveloperSettingsViewController: UITableViewController {
    
    // MARK: - IBOutlets
    // misc
    @IBOutlet weak var antialiasingMode: UISwitch!
    @IBOutlet weak var useAutofocusSwitch: UISwitch!
    @IBOutlet weak var allowGameBoardAutoSizeSwitch: UISwitch!
    
    // level controls
    @IBOutlet weak var showResetLeverSwitch: UISwitch!
    @IBOutlet weak var showLOD: UISwitch!
    @IBOutlet weak var synchronizeMusicWithWallClockSwitch: UISwitch!
    
    // UI Settings
    @IBOutlet weak var disableInGameUISwitch: UISwitch!
    @IBOutlet weak var showARDebugSwitch: UISwitch!
    @IBOutlet weak var showRenderStatsSwitch: UISwitch!
    @IBOutlet weak var showTrackingStateSwitch: UISwitch!
    @IBOutlet weak var showWireframe: UISwitch!
    @IBOutlet weak var showPhysicsDebugSwitch: UISwitch!
    @IBOutlet weak var showSettingsSwitch: UISwitch!
    @IBOutlet weak var showARRelocalizationHelp: UISwitch!
    @IBOutlet weak var showNetworkDebugSwitch: UISwitch!
    @IBOutlet weak var showThermalStateSwitch: UISwitch!
    
    var uiSwitches = [UISwitch]()
    
    // world map sharing
    @IBOutlet weak var worldMapCell: UITableViewCell!
    @IBOutlet weak var manualCell: UITableViewCell!
    
    // projectile trail
    @IBOutlet weak var showProjectileTrailSwitch: UISwitch!
    @IBOutlet weak var useCustomTrailSwitch: UISwitch!
    @IBOutlet weak var taperTrailSwitch: UISwitch!
    @IBOutlet weak var trailWidthTextField: UITextField!
    @IBOutlet weak var trailLengthTextField: UITextField!
    
    // MARK: - IBOutlets
    @IBAction func showARDebugChanged(_ sender: UISwitch) {
        defaults.showARDebug = sender.isOn
    }
    
    @IBAction func showRenderStatsChanged(_ sender: UISwitch) {
        defaults.showSceneViewStats = sender.isOn
    }
    
    @IBAction func showTrackingStateChanged(_ sender: UISwitch) {
        defaults.showTrackingState = sender.isOn
    }
    
    @IBAction func enablePhysicsChanged(_ sender: UISwitch) {
        defaults.showPhysicsDebug = sender.isOn
    }
    
    @IBAction func showNetworkDebugChanged(_ sender: UISwitch) {
        defaults.showNetworkDebug = sender.isOn
    }
    
    @IBAction func showWireframeChanged(_ sender: UISwitch) {
        defaults.showWireframe = sender.isOn
    }
    
    @IBAction func antialiasingMode(_ sender: UISwitch) {
        defaults.antialiasingMode = sender.isOn
    }
    
    @IBAction func showSettingsChanged(_ sender: UISwitch) {
        defaults.showSettingsInGame = sender.isOn
    }
    
    @IBAction func showARRelocalizationHelpChanged(_ sender: UISwitch) {
        defaults.showARRelocalizationHelp = sender.isOn
    }
    
    @IBAction func showResetSwitch(_ sender: UISwitch) {
        defaults.showResetLever = sender.isOn
    }
    
    @IBAction func showLOD(_ sender: UISwitch) {
        defaults.showLOD = sender.isOn
    }
    
    @IBAction func useAutofocus(_ sender: UISwitch) {
        defaults.autoFocus = sender.isOn
    }
    
    @IBAction func disableInGameUIChanged(_ sender: UISwitch) {
        defaults.disableInGameUI = sender.isOn
        if sender.isOn {
            // also turn off everything else
            defaults.showARDebug = false
            defaults.showPhysicsDebug = false
            defaults.showARDebug = false
            defaults.showWireframe = false
            defaults.showSceneViewStats = false
            defaults.showTrackingState = false
            defaults.showSettingsInGame = false
            defaults.showARRelocalizationHelp = false
            defaults.showNetworkDebug = false
            defaults.showLOD = false
        }
        configureUISwitches()
    }
    
    @IBAction func synchronizeMusicWithWallClockChanged(_ sender: UISwitch) {
        defaults.synchronizeMusicWithWallClock = sender.isOn
    }
    
    // MARK: - projectile trail
    @IBAction func allowGameBoardAutoSizeChanged(_ sender: UISwitch) {
        defaults.allowGameBoardAutoSize = sender.isOn
    }
    
    @IBAction func showProjectileTrailChanged(_ sender: UISwitch) {
        defaults.showProjectileTrail = sender.isOn
    }
    
    @IBAction func useCustomTrailChanged(_ sender: UISwitch) {
        defaults.useCustomTrail = sender.isOn
        configureProjectileTrail()
    }
    
    @IBAction func taperTrailChanged(_ sender: UISwitch) {
        defaults.tailShouldNarrow = sender.isOn
        configureProjectileTrail()
    }
    
    @IBAction func showThermalStateChanged(_ sender: UISwitch) {
        defaults.showThermalState = sender.isOn
    }
    
    // MARK: - Var & let
    let defaults = UserDefaults.standard
    
    // MARK: - Class functions
    override func viewDidLoad() {
        antialiasingMode.isOn = defaults.antialiasingMode
        
        useAutofocusSwitch.isOn = defaults.autoFocus
        allowGameBoardAutoSizeSwitch.isOn = defaults.allowGameBoardAutoSize
        
        // level
        showResetLeverSwitch.isOn = defaults.showResetLever
        
        // happens here so the switches have been loaded from the storyboard
        uiSwitches = [showARDebugSwitch, showRenderStatsSwitch, showTrackingStateSwitch,
                      showWireframe, showLOD,
                      showPhysicsDebugSwitch, showSettingsSwitch, showARRelocalizationHelp,
                      showNetworkDebugSwitch, showThermalStateSwitch]
        configureUISwitches()
        configureBoardLocationCells()
        configureProjectileTrail()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    // MARK: - Functions
    func configureUISwitches() {
        disableInGameUISwitch.isOn = defaults.disableInGameUI
        
        showARDebugSwitch.isOn = defaults.showARDebug
        showRenderStatsSwitch.isOn = defaults.showSceneViewStats
        showTrackingStateSwitch.isOn = defaults.showTrackingState
        showWireframe.isOn = defaults.showWireframe
        showLOD.isOn = defaults.showLOD
        showPhysicsDebugSwitch.isOn = defaults.showPhysicsDebug
        showSettingsSwitch.isOn = defaults.showSettingsInGame
        showARRelocalizationHelp.isOn = defaults.showARRelocalizationHelp
        showNetworkDebugSwitch.isOn = defaults.showNetworkDebug
        showProjectileTrailSwitch.isOn = defaults.showProjectileTrail
        synchronizeMusicWithWallClockSwitch.isOn = defaults.synchronizeMusicWithWallClock
        showThermalStateSwitch.isOn = defaults.showThermalState
        
        for uiSwitch in uiSwitches {
            uiSwitch.isEnabled = !defaults.disableInGameUI
        }
    }
    
    func configureBoardLocationCells() {
        let boardLocationMode = defaults.boardLocatingMode
        worldMapCell.accessoryType = (boardLocationMode == .worldMap) ? .checkmark : .none
        manualCell.accessoryType = (boardLocationMode == .manual) ? .checkmark : .none
    }
    
    func configureProjectileTrail() {
        useCustomTrailSwitch.isOn = defaults.useCustomTrail
        taperTrailSwitch.isOn = defaults.tailShouldNarrow
        if defaults.useCustomTrail {
            let width = (defaults.trailWidth ?? TrailDartProjectile.defaultTrailWidth)
            trailWidthTextField.text = "\(width)"
            trailWidthTextField.isEnabled = true
            trailLengthTextField.text = "\(defaults.trailLength ?? TrailDartProjectile.defaultTrailLength)"
            trailLengthTextField.isEnabled = true
        } else {
            let defaultText = NSLocalizedString("Default", comment: "when no custom selected")
            trailWidthTextField.text = defaultText
            trailWidthTextField.isEnabled = false
            trailLengthTextField.text = defaultText
            trailLengthTextField.isEnabled = false
        }
    }
}

// MARK: - UITableViewDelegate
extension DeveloperSettingsViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        switch cell {
        case worldMapCell:
            defaults.boardLocatingMode = .worldMap
        case manualCell:
            defaults.boardLocatingMode = .manual
        default:
            break
        }
        configureBoardLocationCells()
    }
}

extension DeveloperSettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        switch textField {
        case trailWidthTextField:
            trailWidthDidEndEditing(reason: reason)
        case trailLengthTextField:
            trailLengthDidEndEditing(reason: reason)
        default:
            break
        }
    }
    
    private func trailWidthDidEndEditing(reason: UITextField.DidEndEditingReason) {
        if let text = trailWidthTextField.text, let newValue = Float(text) {
            defaults.trailWidth = newValue // value stored in unit ball size (1.0 as trail width equal to ball size)
        } else {
            defaults.trailWidth = nil
        }
        configureProjectileTrail()
    }
    
    private func trailLengthDidEndEditing(reason: UITextField.DidEndEditingReason) {
        if let text = trailLengthTextField.text, let newValue = Int(text) {
            defaults.trailLength = newValue
        } else {
            defaults.trailLength = nil
        }
        configureProjectileTrail()
    }
}
