cask "typeright" do
  version "0.1.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/ViGeng/TypeRight/releases/download/v#{version}/TypeRight.zip"
  name "TypeRight"
  desc "Menu bar app to track backspace ratio and improve typing efficiency"
  homepage "https://github.com/ViGeng/TypeRight"

  depends_on macos: ">= :ventura"

  app "TypeRight.app"

  zap trash: [
    "~/Library/Preferences/com.vigeng.TypeRight.plist",
  ]
end
