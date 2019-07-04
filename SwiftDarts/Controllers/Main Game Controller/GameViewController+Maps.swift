//
//  GameViewController+Maps.swift
//  SwiftDarts
//
//  Created by Wilson on 4/11/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import UIKit
import ARKit
import os.log


extension GameViewController {
    
    // MARK: Saving and Loading Maps
    
    func configureMappingUI() {
        let showMappingState = sessionState != .gameInProgress &&
            sessionState != .setup &&
            sessionState != .localizingToBoard &&
            UserDefaults.standard.showARDebug
        
        mappingStateLabel.isHidden = !showMappingState
    }
    
    func updateMappingStatus(_ mappingStatus: ARFrame.WorldMappingStatus) {
        // Check the mapping status of the worldmap to be able to save the worldmap when in a good state
        switch mappingStatus {
        case .notAvailable:
            mappingStateLabel.text = "Mapping state: Not Available"
            mappingStateLabel.textColor = .red
        case .limited:
            mappingStateLabel.text = "Mapping state: Limited"
            mappingStateLabel.textColor = .red
        case .extending:
            mappingStateLabel.text = "Mapping state: Extending"
            mappingStateLabel.textColor = .red
        case .mapped:
            mappingStateLabel.text = "Mapping state: Mapped"
            mappingStateLabel.textColor = .green
        @unknown default:
            fatalError()
        }
    }
    
    func getCurrentWorldMapData(_ closure: @escaping (Data?, Error?) -> Void) {
        os_log(.info, "in getCurrentWordMapData")
        // When loading a map, send the loaded map and not the current extended map
        if let targetWorldMap = targetWorldMap {
            os_log(.info, "using existing worldmap, not asking session for a new one.")
            compressMap(map: targetWorldMap, closure)
            return
        } else {
            os_log(.info, "asking ARSession for the world map")
            sceneView.session.getCurrentWorldMap { map, error in
                os_log(.info, "ARSession getCurrentWorldMap returned")
                if let error = error {
                    os_log(.error, "didn't work! %s", "\(error)")
                    closure(nil, error)
                }
                guard let map = map else { os_log(.error, "no map either!"); return }
                os_log(.info, "got a worldmap, compressing it")
                self.compressMap(map: map, closure)
            }
        }
    }
    
    private func showSaveDialog(for data: Data) {
        let dialog = UIAlertController(title: "Save World Map", message: nil, preferredStyle: .alert)
        dialog.addTextField(configurationHandler: nil)
        let saveAction = UIAlertAction(title: "Save", style: .default) { action in
            guard let fileName = dialog.textFields?.first?.text else {
                os_log(.error, "no filename"); return
            }
            DispatchQueue.global(qos: .background).async {
                do {
                    let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    let maps = docs.appendingPathComponent("maps", isDirectory: true)
                    try FileManager.default.createDirectory(at: maps, withIntermediateDirectories: true, attributes: nil)
                    let targetURL = maps.appendingPathComponent(fileName).appendingPathExtension("swiftshotmap")
                    try data.write(to: targetURL, options: [.atomic])
                    DispatchQueue.main.async {
                        self.showAlert(title: "Saved")
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.showAlert(title: error.localizedDescription, message: nil)
                    }
                }
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        dialog.addAction(saveAction)
        dialog.addAction(cancelAction)
        
        present(dialog, animated: true, completion: nil)
    }
    
    /// Get the archived data from a URL Path
    private func fetchArchivedWorldMap(from url: URL, _ closure: @escaping (Data?, Error?) -> Void) {
        DispatchQueue.global().async {
            do {
                _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                let data = try Data(contentsOf: url)
                closure(data, nil)
                
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: error.localizedDescription)
                }
                closure(nil, error)
            }
        }
    }
    
    private func compressMap(map: ARWorldMap, _ closure: @escaping (Data?, Error?) -> Void) {
        DispatchQueue.global().async {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                os_log(.info, "data size is %d", data.count)
                let compressedData = data.compressed()
                os_log(.info, "compressed size is %d", compressedData.count)
                closure(compressedData, nil)
            } catch {
                os_log(.error, "archiving failed %s", "\(error)")
                closure(nil, error)
            }
        }
    }
}
