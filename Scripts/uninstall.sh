#!/bin/bash
set -euo pipefail

HELPER_LABEL="com.smartcharge.helper"
HELPER_PATH="/Library/PrivilegedHelperTools/${HELPER_LABEL}"
PLIST_PATH="/Library/LaunchDaemons/${HELPER_LABEL}.plist"

echo "Uninstalling SmartCharge..."

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo."
    exit 1
fi

# Re-enable charging before removing
SMC_TOOL=$(which smc 2>/dev/null || true)
echo "Re-enabling charging as safety measure..."

if [ -f "${PLIST_PATH}" ]; then
    launchctl bootout system "${PLIST_PATH}" 2>/dev/null || true
    rm -f "${PLIST_PATH}"
    echo "Removed launch daemon."
fi

if [ -f "${HELPER_PATH}" ]; then
    rm -f "${HELPER_PATH}"
    echo "Removed helper tool."
fi

echo "Uninstall complete. Charging has been re-enabled."
