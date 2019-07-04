//
//  NetworkGameBrowserViewController.swift
//  SwiftDarts
//
//  Created by Wilson on 4/9/19.
//  Copyright © 2019 Wilson. All rights reserved.
//

import Foundation
import UIKit
import os.log

protocol NetworkGameBrowserViewControllerDelegate: class {
    func networkGameBrowserViewController(_ networkGameBrowserViewController: UIViewController, join session: NetworkSession)
}

class NetworkGameBrowserViewController: UITableViewController {
    
    weak var delegate: NetworkGameBrowserViewControllerDelegate?
    
    var session: NetworkSession?
    var games: [NetworkGame] = []
    
    // must be set by parent
    var browser: GameBrowser? {
        didSet {
            oldValue?.stop()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(GameCell.self, forCellReuseIdentifier: "GameCell")
        
        startBrowser()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    func startBrowser() {
        browser?.delegate = self
        browser?.start()
        tableView.reloadData()
    }
    
    func joinGame(_ game: NetworkGame) {
        guard let session = browser?.join(game: game) else {
            os_log(.error, "could not join game")
            return
        }
        
        delegate?.networkGameBrowserViewController(self, join: session)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GameCell", for: indexPath)
        let game = games[indexPath.row]
        cell.textLabel?.text = game.name
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return games.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let otherPlayer = games[indexPath.row]
        joinGame(otherPlayer)
    }
}

extension NetworkGameBrowserViewController: GameBrowserDelegate {
    func gameBrowser(_ browser: GameBrowser, sawGames games: [NetworkGame]) {
        os_log(.info, "saw %d games!", games.count)
        
        self.games = games
        
        tableView.reloadData()
    }
}
