cask "smartcharge" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/a217-anjali/SmartCharge/releases/download/v#{version}/SmartCharge.dmg"
  name "SmartCharge"
  desc "Automatic battery charge management for macOS"
  homepage "https://github.com/a217-anjali/SmartCharge"

  app "SmartCharge.app"

  zap trash: [
    "~/Library/Preferences/com.smartcharge.app.plist",
  ]
end
