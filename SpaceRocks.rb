cask "SpaceRocks" do
  version "1.0.0"
  sha256 "SHA256_HERE"

  url "https://github.com/kdekorte/SpaceRocks/releases/download/v#{version}/SpaceRocks.zip"
  name "SpaceRocks"
  desc "Space game for MacOS"
  homepage "https://github.com/kdekorte/SpaceRocks"

  app "SpaceRocks.app"
end
