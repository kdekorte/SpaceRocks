# SpaceRocks

SpaceRocks is a classic arcade-style asteroid shooter for macOS, written in Swift using SpriteKit.

## Features

- Fast-paced asteroid blasting action
- Smooth controls using keyboard or game controller
- Shields, alien UFOs, and more
- Retro visuals and sounds

## Requirements

- macOS 13.0 or later

## Installation

### Homebrew (Recommended)

You can install the latest release of SpaceRocks using Homebrew:

```sh
brew tap kdekorte/spacerocks
brew install --cask spacerocks
```

## Building a Release

To build and publish a new release of SpaceRocks (and update the Homebrew cask):

1. **Update App Version (if needed)**

• Make any version changes in your app as needed (for example, update Info.plist or version constants in your source files).

2. **Commit All Changes**

• Ensure all changes are committed:

```bash
git add .
git commit -m "Prepare for release"
```

**Create a New Git Tag for the Release Version**

• Replace v1.0.1 with your desired version:

```bash
git tag v1.0.1
git push origin v1.0.1
```

The release script uses the latest tag as the version.

4. **Run the Release Script**

• Make sure you have Xcode, Homebrew, and the GitHub CLI (gh) installed.

• Then run:

```bash
./release.sh
```

This will:

• Build a signed, release version of the app

• Package it as a zip

• Create a GitHub release and upload the zip

• Calculate SHA256 and update the Homebrew cask

• Push the cask change to your tap repository (if available)
