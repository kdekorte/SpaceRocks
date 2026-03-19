xcodebuild clean build -project SpaceRocks.xcodeproj -scheme SpaceRocks -configuration Release SYMROOT=build
ditto -c -k --keepParent build/Release/SpaceRocks.app SpaceRocks.zip
shasum -a 256 SpaceRocks.zip
