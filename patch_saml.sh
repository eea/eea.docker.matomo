#!/bin/bash

# Workaround for a plugin issue where the LoginSAML plugin will not load the libraries correctly for the analytics calls, making it return 500
# This forces the library load in all call paths

set -euo pipefail

PLUGIN_DIR="/bitnami/matomo/plugins/LoginSaml"
MATOMO_VENDOR_DIR="/bitnami/matomo/vendor"
CONFIG_FILE="$PLUGIN_DIR/Config.php"
LOCKFILE="/bitnami/matomo/.patch_saml_lock"
LOCK_TIMEOUT=3  # seconds

echo "Patching LoginSaml"

# Lock with timeout
exec 200>"$LOCKFILE"
if ! flock -w $LOCK_TIMEOUT 200; then
  echo "Warn: Could not acquire initialization lock within ${LOCK_TIMEOUT}s. Exiting."
  exit 0
fi

# LoginSAML exists
if [ ! -d "$PLUGIN_DIR" ]; then
  echo "Warn: $PLUGIN_DIR does not exist. Exiting."
  exit 0
fi

# Copy libraries if needed
for vendor in onelogin robrichards; do
  if [ ! -d "$MATOMO_VENDOR_DIR/$vendor" ]; then
    if [ -d "$PLUGIN_DIR/vendor/$vendor" ]; then
      echo "Copying $vendor to $MATOMO_VENDOR_DIR..."
      cp -r "$PLUGIN_DIR/vendor/$vendor" "$MATOMO_VENDOR_DIR/"
      chown -R daemon:root "$MATOMO_VENDOR_DIR/$vendor"
    else
      echo "Warning: $PLUGIN_DIR/vendor/$vendor does not exist, skipping."
    fi
  fi
done

# Lines to be checked/added to the Config.php
declare -a REQUIRED_LINES=(
"require_once PIWIK_INCLUDE_PATH . '/vendor/onelogin/php-saml/_toolkit_loader.php';"
"require_once PIWIK_INCLUDE_PATH . '/vendor/robrichards/xmlseclibs/src/XMLSecurityKey.php';"
"require_once PIWIK_INCLUDE_PATH . '/vendor/robrichards/xmlseclibs/src/XMLSecurityDSig.php';"
"require_once PIWIK_INCLUDE_PATH . '/vendor/robrichards/xmlseclibs/src/XMLSecEnc.php';"
)

missing_lines=()
for line in "${REQUIRED_LINES[@]}"; do
  if ! grep -Fq "$line" "$CONFIG_FILE"; then
    missing_lines+=("$line")
  fi
done

if [ ${#missing_lines[@]} -gt 0 ]; then
  echo "Patching $CONFIG_FILE with missing require_once lines..."
  tmpfile=$(mktemp)
  awk -v insert="$(printf '%s\n' "${missing_lines[@]}")" '
    /namespace Piwik\\Plugins\\LoginSaml;/ {
      print;
      print insert;
      next
    }
    {print}
  ' "$CONFIG_FILE" > "$tmpfile" && mv "$tmpfile" "$CONFIG_FILE"
  chown daemon:root "$CONFIG_FILE"  
fi

echo "Patching LoginSaml finished"
