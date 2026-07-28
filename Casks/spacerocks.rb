cask "spacerocks" do
  version "1.0.0"
  sha256 "<SHA256_PLACEHOLDER>"

  url "https://github.com/kdekorte/SpaceRocks/releases/download/v#{version}/SpaceRocks.zip"
  name "SpaceRocks"
  desc "Classic arcade-style asteroid shooter for macOS"
  homepage "https://github.com/kdekorte/SpaceRocks"

  app "SpaceRocks.app"
end
