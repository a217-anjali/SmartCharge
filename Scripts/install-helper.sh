#!/bin/bash
set -euo pipefail

HELPER_LABEL="com.smartcharge.helper"
HELPER_PATH="/Library/PrivilegedHelperTools/${HELPER_LABEL}"
PLIST_PATH="/Library/LaunchDaemons/${HELPER_LABEL}.plist"

echo "Installing SmartCharge privileged helper..."

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo."
    exit 1
fi

BUILD_DIR="build/Release"
HELPER_BINARY="${BUILD_DIR}/SmartChargeHelper"

if [ ! -f "${HELPER_BINARY}" ]; then
    echo "Error: Helper binary not found at ${HELPER_BINARY}"
    echo "Build the project first with: xcodebuild -scheme SmartChargeHelper -configuration Release"
    exit 1
fi

cp "${HELPER_BINARY}" "${HELPER_PATH}"
chmod 544 "${HELPER_PATH}"
chown root:wheel "${HELPER_PATH}"

cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${HELPER_LABEL}</string>
    <key>Program</key>
    <string>${HELPER_PATH}</string>
    <key>MachServices</key>
    <dict>
        <key>${HELPER_LABEL}</key>
        <true/>
    </dict>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

chmod 644 "${PLIST_PATH}"
chown root:wheel "${PLIST_PATH}"

launchctl bootout system "${PLIST_PATH}" 2>/dev/null || true
launchctl bootstrap system "${PLIST_PATH}"

echo "Helper installed and running."
