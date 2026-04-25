.PHONY: generate build run clean install-helper uninstall dmg

# Generate the Xcode project from project.yml (requires xcodegen)
generate:
	xcodegen generate

# Build in Xcode (release)
build: generate
	xcodebuild -project SmartCharge.xcodeproj -scheme SmartCharge -configuration Release -derivedDataPath build

# Open in Xcode
open: generate
	open SmartCharge.xcodeproj

# Install the privileged helper (requires sudo)
install-helper:
	sudo ./Scripts/install-helper.sh

# Uninstall everything (requires sudo)
uninstall:
	sudo ./Scripts/uninstall.sh

# Package as DMG
dmg:
	./Scripts/create-dmg.sh

# Clean build artifacts
clean:
	rm -rf build DerivedData
	rm -rf SmartCharge.xcodeproj
