#!/bin/bash
set -e

# -------- User Configurable --------
GITHUB_USER="kdekorte"
REPO="SpaceRocks"
TAP_REPO="spacerocks"
APP_NAME="SpaceRocks.app"
ZIP_NAME="SpaceRocks.zip"
CASK_PATH="Casks/spacerocks.rb"

echo "Starting release process for $REPO..."

# 1. Clean and build release
echo "Building signed release version..."
xcodebuild -scheme SpaceRocks -configuration Release -derivedDataPath build clean build

# 2. Package the .app into a zip
echo "Packaging $APP_NAME into $ZIP_NAME..."
rm -f "$ZIP_NAME"
cp -R build/Build/Products/Release/$APP_NAME .
zip -r "$ZIP_NAME" "$APP_NAME"
rm -rf "$APP_NAME"

# 3. Create a GitHub release and upload the zip
VERSION=$(git describe --tags --abbrev=0)
echo "Creating GitHub release $VERSION..."
gh release create "$VERSION" "$ZIP_NAME" --title "SpaceRocks $VERSION" --notes "Release $VERSION"

# 4. Calculate SHA256
echo "Calculating SHA256 checksum..."
SHA256=$(shasum -a 256 "$ZIP_NAME" | awk '{ print $1 }')

# 5. Update Homebrew cask
echo "Updating Homebrew cask file..."
CASK_URL="https://github.com/$GITHUB_USER/$REPO/releases/download/$VERSION/$ZIP_NAME"
sed -i '' "s|version \".*\"|version \"$VERSION\"|g" "$CASK_PATH"
sed -i '' "s|sha256 \".*\"|sha256 \"$SHA256\"|g" "$CASK_PATH"
sed -i '' "s|url \".*\"|url \"$CASK_URL\"|g" "$CASK_PATH"

# 6. Commit and push to tap repo
if [ -d "../$TAP_REPO" ]; then
    echo "Updating tap repository $TAP_REPO..."
    cp "$CASK_PATH" "../$TAP_REPO/Casks/spacerocks.rb"
    cd ../$TAP_REPO
    git add Casks/spacerocks.rb
    git commit -m "Update SpaceRocks cask to $VERSION"
    git push
    cd -
else
    echo "WARNING: $TAP_REPO repo not found. Please update the cask file manually."
fi

echo "Release $VERSION complete!"
