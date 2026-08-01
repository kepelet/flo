# Dependencies

flo intentionally keeps its dependency graph small. This page lists the Swift Package Manager packages used by the Xcode project and the Ruby dependency used for build automation.

Sources: `flo.xcodeproj/project.pbxproj`, `Gemfile`, and `Gemfile.lock`.

## Swift Package Manager dependencies

The packages are declared in `flo.xcodeproj/project.pbxproj` under `XCRemoteSwiftPackageReference` and linked under `XCSwiftPackageProductDependency`.

| Package | Repository | Requirement | Products used |
| --- | --- | --- | --- |
| Alamofire | `https://github.com/Alamofire/Alamofire` | up to next major version, minimum `5.9.1` | `Alamofire` |
| KeychainAccess | `https://github.com/kishikawakatsumi/KeychainAccess` | branch `master` | `KeychainAccess` |
| Nuke | `https://github.com/kean/Nuke` | up to next major version, minimum `12.8.0` | `Nuke`, `NukeUI` |
| Pulse | `https://github.com/kean/Pulse` | up to next major version, minimum `5.1.2` | `Pulse`, `PulseUI` |

### What each dependency is used for

| Package | Role in flo |
| --- | --- |
| Alamofire | HTTP networking for Navidrome native API and Subsonic API calls. |
| KeychainAccess | Secure storage of user credentials and authentication tokens. |
| Nuke | Asynchronous image loading and caching for cover art and artist images. |
| Pulse / PulseUI | Network logging and an in-app network inspector for debugging. |

## Apple frameworks

The project also links against Apple system frameworks directly. One example is `CarPlay.framework`, which is linked to support the CarPlay interface. See `flo.xcodeproj/project.pbxproj` and the `CarPlay/` group for more details.

## Ruby dependencies

The project uses fastlane for build automation. The only direct gem dependency is declared in `Gemfile`:

| Gem | Requirement |
| --- | --- |
| fastlane | `>= 2.233.0` |

`Gemfile.lock` pins fastlane to `2.233.0` and resolves the full transitive dependency tree, including `xcodeproj`, `xcpretty`, `faraday`, `google-cloud-storage`, and others required by fastlane. These are not used by the app at runtime.

## Dependency philosophy

As noted in the README, flo keeps dependencies minimal to make the project easier to maintain and reduce supply-chain risk. For the same reason, the project does not use third-party localization services or heavy dependency injection frameworks.
