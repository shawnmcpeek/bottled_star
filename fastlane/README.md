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

### ios upload_asc_listing

```sh
[bundle exec] fastlane ios upload_asc_listing
```

Upload App Store listing text only (no IPA, no screenshots)

### ios upload_asc_screenshots

```sh
[bundle exec] fastlane ios upload_asc_screenshots
```

Upload App Store screenshots only

----


## Android

### android upload_play_listing

```sh
[bundle exec] fastlane android upload_play_listing
```

Upload Play Store listing text only (no AAB, no images)

### android upload_play_screenshots

```sh
[bundle exec] fastlane android upload_play_screenshots
```

Upload Play Store phone screenshots only

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
