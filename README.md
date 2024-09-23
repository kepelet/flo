<div align="center">
  <img src="./meta/guthib.jpeg" alt="flo" width="100%">
  <br><br>
  <p>Meet flo, an open source Navidrome client written in Swift.</p>
</div>

# flo

As mentioned many times, flo is an open source Navidrome client written in Swift. It has modern yet familiar user interfaces
built on top of Apple's latest UI framework: SwiftUI. While Navidrome supports Subsonic APIs, flo was purposely designed for Navidrome servers.

However, flo is still under heavy development. Bugs and regular updates are expected to improve flo over time. It's worth noting that flo at
this stage is unlikely to harm your iPhone or your beloved Navidrome server.

## Features

Everything you can expect from a music player: it plays music. However, here are some features you may enjoy:

- Online streaming (save your storage)
- Offline streaming (save your bandwidth)
- Play by album (shuffle for surprises)
- Background playback (just don't close the app)
- Control playback via the "command center" (something in your "notification")

flo may have opt-in "social" features in the future to make the listening experience more fun and extroverted. But for now, flo is intended to become one of the best
Navidrome clients in the Apple ecosystem!

To learn more about flo, visit flo's [landing page.](https://client.flooo.club)

## Development

For now just clone it and figure it out :)

Jokes aside, make sure you have Xcode installed. The latest stable version is recommended, and as of this writing, Swift 5 is used. Another step, such as setting up a "provisioning profile," may be required to run this app in a development environment.

This project uses integrated SwiftPM (Swift Package Manager) to manage app dependencies. So far, only two package are being used:

- Alamofire — everyone's favorite http library
- KeychainAccess — a simple wrapper for Keychain access

The minimum number of dependencies is intended to make the project easier to maintain.

If you're part of the Kepelet org, make sure you have [fastlane](https://fastlane.tools) installed. Then, you can run `fastlane match development` and you're ready to go without having to mess with the provisioning profile too much!

Practically, this project uses the Gitflow workflow, where:

- `main` is the "App Store" version
- `develop` is the "TestFlight" public version
- `release/xxx` is the "TestFlight" internal version
- `features/yyy` or `bugfix/zzz` is the "staging" area of the current release (feature/bugfix branches)

Realistically, sometimes feature branches are unnecessary, as the project doesn't run tests (yet) and the developer tests the app anyway.

So, the flow is:

- Draft a release branch
- Every week or so, if no critical errors are present, merge to develop and submit to the TestFlight external group
- Wait for approval
- Test the beta app
- Every week or so, if no critical errors are present, submit for review to the App Store
- Wait for approval
- When it's live, merge to main
- Repeat

Coming from Web Development, where no one technically controls the release process, I hate this cycle — I used to ship as soon as it was ready and figure it out later. This time, I have to draft a release every 1-2 weeks. It might get approved, or it might be rejected. But at least I tried!

## Localization

One of the promises of flo is customization — to make flo look the way you want. More importantly, it aims to make flo easier to use, and one of the efforts is localization: to make flo speak the language you know best.

Unfortunately, we don't use third-party apps/services to manage localizations in flo, which means Xcode is required. While the process itself is [relatively easy](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog), but, still, the existence of Xcode become a significant barrier to contributing more languages.

## Support

Bug reports, typos, errors and feedback are welcome! Please use GitHub Issues for reports and GitHub Discussions for... discussion. For anything private,
you can reach me via email at oss [at] rizaldy.club. I don't check email often but I have  push notifications turned on!

## License

MIT.
