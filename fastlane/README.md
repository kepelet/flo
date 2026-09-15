fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios load_asc_api_key

```sh
[bundle exec] fastlane ios load_asc_api_key
```

load App Store Connect API key

### ios sync_certs

```sh
[bundle exec] fastlane ios sync_certs
```

sync certs thing

### ios fetch_and_increment_build_number

```sh
[bundle exec] fastlane ios fetch_and_increment_build_number
```

bump build number based on latest TestFlight build number

### ios build

```sh
[bundle exec] fastlane ios build
```

build app

### ios beta

```sh
[bundle exec] fastlane ios beta
```

push a new build to TestFlight

## Mac Catalyst

### mac build

```sh
[bundle exec] fastlane mac build
```

build the Mac Catalyst app

### mac beta

```sh
[bundle exec] fastlane mac beta
```

push a Mac Catalyst build to TestFlight. Pass `public:true` to distribute to the external TestFlight group.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
