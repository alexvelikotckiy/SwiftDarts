//
//  GameStartViewController.swift
//  SwiftDarts
//
//  Created by Wilson on 4/3/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import UIKit

protocol GameStarter: class {
    func solo()
    func select(_ game: NetworkSession)
    func start(_ game: NetworkSession)
}

class GameStartViewController: UIViewController {
    
    // MARK: - IBActions
    @IBAction func touchStartNewGame(_ sender: UIButton) {
        let gameVC: GameViewController = .initWithStoryboard()!
        navigationController?.present(gameVC, animated: true) {
            self.startHostGame(starter: gameVC, with: self.myself)
        }
    }
    
    @IBAction func touchSrartSoloGame(_ sender: UIButton) {
        let gameVC: GameViewController = .initWithStoryboard()!
        navigationController?.present(gameVC, animated: true) {
            self.startSoloGame(starter: gameVC, with: self.myself)
        }
    }
    
    @IBAction func touchJoinGame(_ sender: UIButton) {
        let networkGameBrowserVC: NetworkGameBrowserViewController = .initWithStoryboard()!
        networkGameBrowserVC.delegate = self
        gameBrowser = GameBrowser(myself: myself)
        networkGameBrowserVC.browser = gameBrowser
        navigationController?.pushViewController(networkGameBrowserVC, animated: true)
    }
    
    @IBAction func touchSettings(_ sender: UIButton) {
        let settingsVC: SettingsViewController = .initWithStoryboard()!
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    // MARK: - Init
    
    // MARK: - Class functions
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    // MARK: - Functions
    private func startHostGame(starter: GameStarter, with player: Player) {
        let gameSession = NetworkSession(myself: player, asServer: true, host: myself)
        starter.start(gameSession)
    }
    
    private func startSoloGame(starter: GameStarter, with player: Player) {
        starter.solo()
    }
    
    private func jointGame(starter: GameStarter, session: NetworkSession) {
        starter.select(session)
    }
    
    // MARK: - Var & let
    private let myself = UserDefaults.standard.myself
    
    var gameBrowser: GameBrowser?
}

extension GameStartViewController: NetworkGameBrowserViewControllerDelegate {
    func networkGameBrowserViewController(_ networkGameBrowserViewController: UIViewController, join session: NetworkSession) {
        let gameVC: GameViewController = .initWithStoryboard()!
        navigationController?.present(gameVC, animated: true) {
            self.jointGame(starter: gameVC, session: session)
        }
    }
}
