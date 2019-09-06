<p align="center">
	<img src="Screenshots/app%20icon.png">
</p>

# SwiftDarts #

[![Swift Version][swift-image]][swift-url]
![Platform][ios-image]
[![License][license-image]][license-url]
![Xcode][xcode-image]

SwiftDarts is an AR darts game for solo or multiplayer games, which is based on a game [SwiftShot][swiftshot-url] featured in the WWDC18 keynote. Thereby, SwiftDarts is a customized version of the basic game which uses [ARKit][arkit-url], [SceneKit][scenekit-url], [Swift][swift-url] and [MultipeerConnectivity][multipeerconnectivity-url]. Requires Xcode 10.0, iOS 12.2 and an iOS device with an A9 or later processor.

## Key Features ##

### Multiplayer Physics ###
Each peer in a session runs its own local physics simulation, but synchronizes physics results with a server. To send information between devices, the customized type ```PhysicsNodeData``` and ```PhysicsPoolNodeData``` encode it to a minimal binary representation. Every projectile's(dart) piece of data represents position, orientaion, velocity, angular velocity and a team of player who throwed it. A boolean flag ```isAlive``` indicates whether a dart should be spawned.

### Synchronizing ###
To synchronize game events between players, it uses an action queue pattern. The ```GameManager``` class maintains a list of ```GameCommand``` structures, each of which pairs a ```GameAction``` enum value describing the event with an identifier for the player responsible for that event. When the player touches the screen(making some action), the game creates and adds it to the queue. Simultaneously, the game sends encoded actions to other players for sync.

### Sharing World Maps ###
As well as the [SwiftShot][swiftshot-url] uses [MultipeerConnectivity][multipeerconnectivity-url] framework, SwiftDarts is completely based on the same classes and logic which creates an ```ARWorldMap``` containing ARKit's understanding of the area around the game board and allows to share worlds with joining players.

## Installation and Launch ##
The game requires an iOS device with an A9 or later processor. After launch choose a game type and follow instructions. A host player can place, rotate, scale board on vertical surfaces. In multiplayer games a new player can join an existing game session.

## Bug list ##

- There is a possible bug when a new player joins a multiplayer game and it doesn't load a game board,
- Fix projectile despawning when a player throws his dart outside game zone borders. Hint: ```RemoveWhenFallenComponent``` type,
- Investigate the ```CameraThrower``` spawning logic. A bug occurs when a new player joins a multiplayer session,

## Contributing ##

### Bug Reports & Feature Requests ###

Please use GitHub issues to report any bugs or file feature requests. If you want fix it yourself or suggest a new feature, feel free to send in a pull request. 

### Pull requests ###

Pull requests should include information about what has been changed. Also, try to include links to issues in order to better review the pull request.

## Contacts ##

- Email: <alexvelikotckiy@gmail.com>
- GitHub: [alexvelikotckiy][author-url]

## License ##

SwiftDarts is available under the [MIT license][license-url]. 

[license-url]: LICENSE
[swift-url]: https://swift.org/
[swiftshot-url]: https://developer.apple.com/documentation/arkit/swiftshot_creating_a_game_for_augmented_reality
[multipeerconnectivity-url]: https://developer.apple.com/documentation/multipeerconnectivity
[scenekit-url]: https://developer.apple.com/documentation/scenekit
[arkit-url]: https://developer.apple.com/augmented-reality/
[author-url]: https://github.com/alexvelikotckiy

[license-image]: https://img.shields.io/badge/license-MIT-blue.svg
[swift-image]: https://img.shields.io/badge/swift-5-orange.svg
[xcode-image]: https://img.shields.io/badge/xcode-10+-blue.svg
[ios-image]: http://img.shields.io/badge/iOS-12.0%2B-blue.svg
