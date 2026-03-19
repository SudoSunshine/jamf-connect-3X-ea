#!/bin/sh
# Extension Attribute: Jamf Connect Components
# Author: Ellie Romero
# Version: 2.7.0
# Last Update: 2026-03-19
#
# Tracks Jamf Connect components (JCMB, JCLW) and Self Service+ across
# legacy (≤2.45.1) and modern (3.0+) architectures.
#
# Components:
#   JCMB = Jamf Connect Menu Bar (in SSP 2.0+)
#   JCLW = Jamf Connect Login Window (standalone 3.0+)
#   SSP  = Self Service+ (container for JCMB)
#
# Configure REPORT_JCMB, REPORT_JCLW, and REPORT_SSP below to control output.
# See README for full documentation and Smart Group examples.
#
# v2.7.0 — Fix SSP detection broken by Jamf Pro 11.25 custom branding (PI-1077).
#           SSP app bundle can be renamed on disk (e.g., "SmartAsset Self Service.app").
#           Now detects SSP via CFBundleIdentifier instead of hardcoded path.
#
################################
# CONFIGURATION & PATHS
################################
# Component reporting (set to "true" or "false")
REPORT_JCMB="true"             # Report Menu Bar component
REPORT_JCLW="true"             # Report Login Window component
REPORT_SSP="false"             # Report Self Service+ version only

# Output customization (set to "true" or "false")
SHOW_SSP_VERSION="false"       # Show SSP version inline with JCMB
SHOW_ACTIVE_STATUS="true"      # Show Active/Inactive for JCLW (recommended)
SHOW_MULTI_VERSION="true"      # Show multi-version alerts (recommended)
SHOW_TIMESTAMPS="false"        # Show installation dates

# Constants
THRESHOLD="2.45.1"             # Classic vs modern cutoff

# Bundle identifiers (stable across custom branding renames — Jamf Pro 11.25+)
SSP_BUNDLE_ID="com.jamf.selfserviceplus"
CLASSIC_SS_BUNDLE_ID="com.jamfsoftware.selfservice.mac"

# File paths — SSP_APP_PLIST and SSP_MB_PLIST are overwritten at runtime by
# resolve_ssp_paths() to handle custom-branded app names.
SSP_APP_PLIST="/Applications/Self Service+.app/Contents/Info.plist"
CLASSIC_SS_PLIST="/Applications/Self Service.app/Contents/Info.plist"
SSP_MB_PLIST="/Applications/Self Service+.app/Contents/MacOS/Jamf Connect.app/Contents/Info.plist"
LEGACY_MB_PLIST="/Applications/Jamf Connect.app/Contents/Info.plist"
JCLW_BUNDLE_PLIST="/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/Contents/Info.plist"
LEGACY_JC_PLIST="/Applications/Jamf Connect.app/Contents/Info.plist"

################################
# Helper functions
################################
# 1.1 - Version comparison (returns true if v1 > v2)
version_gt() {
  v1="$1"; v2="$2"
  [ -z "$v1" ] && return 1
  [ "$(printf '%s\n%s\n' "$v1" "$v2" | sort -V | head -n1)" != "$v1" ]
}

# 1.2 - Get version from plist
get_ver() {
  plist="$1"
  [ -f "$plist" ] && /usr/bin/defaults read "$plist" CFBundleShortVersionString 2>/dev/null
}

# 1.3 - Get file modification timestamp
get_timestamp() {
  plist="$1"
  if [ -f "$plist" ]; then
    stat -f "%Sm" -t "%Y-%m-%d" "$plist" 2>/dev/null
  fi
}

# 1.4 - Check which JCMB LaunchDaemon is loaded
check_jcmb_active() {
  # Check if SSP daemon is loaded
  if launchctl list 2>/dev/null | grep -q "com.jamf.connect.daemon.ssp"; then
    echo "ssp"
    return
  fi

  # Check if Classic/legacy daemon is loaded
  if launchctl list 2>/dev/null | grep -q "com.jamf.connect.daemon$"; then
    echo "legacy"
    return
  fi

  # No JCMB daemon loaded
  echo "none"
}

# 1.5 - Check which JCLW is registered in authorization database
check_jclw_active() {
  # Get the full authdb mechanisms list
  authdb_output=$(security authorizationdb read system.login.console 2>/dev/null)

  # Check if JamfConnectLogin mechanism is present
  if echo "$authdb_output" | grep -qi "JamfConnectLogin"; then
    # Try to detect SecurityAgentPlugins path (modern bundle)
    if echo "$authdb_output" | grep -q "SecurityAgentPlugins"; then
      echo "bundle"
      return
    fi

    # Try to detect /Applications/Jamf Connect.app path (legacy)
    if echo "$authdb_output" | grep -q "Applications/Jamf Connect"; then
      echo "legacy"
      return
    fi

    # JamfConnectLogin present but can't determine exact path — default to bundle
    echo "bundle"
  else
    echo "none"
  fi
}

# 1.6 - Find an app in /Applications by CFBundleIdentifier
#        Handles Jamf Pro 11.25+ custom branding that renames the .app bundle on disk.
#        Uses mdfind (Spotlight) first for speed; falls back to a direct scan.
find_app_by_bundle_id() {
  bundle_id="$1"

  # Try Spotlight — fast, but may be off or unindexed on some managed Macs.
  # Filter to top-level /Applications/*.app paths only (avoids nested bundles).
  mdfind_result=$(/usr/bin/mdfind \
    "kMDItemCFBundleIdentifier == '${bundle_id}'" \
    -onlyin /Applications 2>/dev/null \
    | grep -E "^/Applications/[^/]+\.app$" \
    | head -1)
  if [ -n "$mdfind_result" ]; then
    echo "$mdfind_result"
    return
  fi

  # Fallback: scan /Applications directly (handles Spotlight disabled/stale index)
  for app_path in /Applications/*.app; do
    plist="${app_path}/Contents/Info.plist"
    if [ -f "$plist" ]; then
      bid=$(/usr/bin/defaults read "$plist" CFBundleIdentifier 2>/dev/null)
      if [ "$bid" = "$bundle_id" ]; then
        echo "$app_path"
        return
      fi
    fi
  done
}

# 1.7 - Resolve SSP-related paths at runtime
#        Must be called once before any evaluate_* functions.
#        Overwrites SSP_APP_PLIST and SSP_MB_PLIST with the actual path on disk,
#        regardless of what the app is named due to custom branding.
resolve_ssp_paths() {
  ssp_app_path="$(find_app_by_bundle_id "$SSP_BUNDLE_ID")"

  if [ -n "$ssp_app_path" ]; then
    SSP_APP_PLIST="${ssp_app_path}/Contents/Info.plist"
    SSP_MB_PLIST="${ssp_app_path}/Contents/MacOS/Jamf Connect.app/Contents/Info.plist"
  fi
  # If not found, SSP_APP_PLIST/SSP_MB_PLIST remain at their hardcoded defaults,
  # which will simply not resolve — safe no-op behaviour.
}

################################
# Version classifying functions
################################
# 2.1 - Classify JCMB as SSP or Classic
classify_jcmb() {
  v="$1"
  version_gt "$v" "$THRESHOLD" && echo "SSP" || echo "Classic"
}

# 2.2 - Classify JCLW as Stand-alone or Classic
classify_jclw() {
  v="$1"
  version_gt "$v" "$THRESHOLD" && echo "Stand-alone" || echo "Classic"
}

################################
# Component evaluation functions
################################
# 3.1 - Get Self Service+ version
get_ssp_version() {
  ssp_ver=""

  if [ -f "$SSP_APP_PLIST" ]; then
    ssp_ver="$(get_ver "$SSP_APP_PLIST")"
  fi

  echo "$ssp_ver"
}

# 3.2 - Evaluate Menu Bar (JCMB)
evaluate_jcmb() {
  jcmb_ver=""
  jcmb_type="None"
  jcmb_plist=""
  ssp_ver=""
  legacy_ver=""
  ssp_version=""
  active_daemon=""

  # Get SSP version for inline display
  ssp_version="$(get_ssp_version)"

  # Check which daemon is loaded (if status enabled)
  if [ "$SHOW_ACTIVE_STATUS" = "true" ]; then
    active_daemon="$(check_jcmb_active)"  # Returns: "ssp", "legacy", or "none"
  fi

  # Check SSP location
  if [ -f "$SSP_MB_PLIST" ]; then
    ssp_ver="$(get_ver "$SSP_MB_PLIST")"
  fi

  # Check legacy location
  if [ -f "$LEGACY_MB_PLIST" ]; then
    legacy_ver="$(get_ver "$LEGACY_MB_PLIST")"
  fi

  # Determine primary version and type
  if [ -n "$ssp_ver" ]; then
    jcmb_ver="$ssp_ver"
    jcmb_type="SSP"
    jcmb_plist="$SSP_MB_PLIST"
  elif [ -n "$legacy_ver" ]; then
    jcmb_ver="$legacy_ver"
    jcmb_type="$(classify_jcmb "$jcmb_ver")"
    jcmb_plist="$LEGACY_MB_PLIST"
  fi

  # Output result
  if [ -z "$jcmb_ver" ]; then
    echo "JCMB None NotInstalled"
  else
    output="JCMB ${jcmb_type} ${jcmb_ver}"

    if [ "$SHOW_SSP_VERSION" = "true" ] && [ "$jcmb_type" = "SSP" ] && [ -n "$ssp_version" ]; then
      output="${output} (Detected in SSP ${ssp_version})"
    fi

    # Add active/inactive status if enabled
    if [ "$SHOW_ACTIVE_STATUS" = "true" ]; then
      if [ -n "$ssp_ver" ] && [ "$active_daemon" = "ssp" ]; then
        output="${output} (Active)"
      elif [ -z "$ssp_ver" ] && [ -n "$legacy_ver" ] && [ "$active_daemon" = "legacy" ]; then
        output="${output} (Active)"
      elif [ "$active_daemon" = "none" ]; then
        output="${output} (Inactive)"
      else
        output="${output} (Inactive)"
      fi
    fi

    if [ "$SHOW_TIMESTAMPS" = "true" ]; then
      timestamp="$(get_timestamp "$jcmb_plist")"
      [ -n "$timestamp" ] && output="${output} [${timestamp}]"
    fi

    if [ "$SHOW_MULTI_VERSION" = "true" ] && [ -n "$ssp_ver" ] && [ -n "$legacy_ver" ] && [ "$ssp_ver" != "$legacy_ver" ]; then
      legacy_type="$(classify_jcmb "$legacy_ver")"

      if [ "$SHOW_ACTIVE_STATUS" = "true" ]; then
        if [ "$active_daemon" = "legacy" ]; then
          output="${output} (also found JCMB ${legacy_type} ${legacy_ver} - Active)"
        else
          output="${output} (also found JCMB ${legacy_type} ${legacy_ver} - Inactive)"
        fi
      else
        output="${output} (also found JCMB ${legacy_type} ${legacy_ver})"
      fi
    fi

    echo "$output"
  fi
}

# 3.3 - Evaluate Login Window (JCLW)
evaluate_jclw() {
  jclw_ver=""
  jclw_type="None"
  jclw_plist=""
  bundle_ver=""
  legacy_ver=""
  active_location=""

  # Check which JCLW is registered in authorization database (if status enabled)
  if [ "$SHOW_ACTIVE_STATUS" = "true" ]; then
    active_location="$(check_jclw_active)"  # Returns: "bundle", "legacy", or "none"
  fi

  # Check modern bundle location
  if [ -f "$JCLW_BUNDLE_PLIST" ]; then
    bundle_ver="$(get_ver "$JCLW_BUNDLE_PLIST")"
  fi

  # Check legacy location — ONLY use for JCLW if version ≤ 2.45.1
  # After 3.0, /Applications/Jamf Connect.app/ contains ONLY JCMB (no JCLW)
  if [ -f "$LEGACY_JC_PLIST" ]; then
    temp_ver="$(get_ver "$LEGACY_JC_PLIST")"

    # Only use as JCLW source if version ≤ 2.45.1 (combined app era)
    if [ -n "$temp_ver" ] && ! version_gt "$temp_ver" "$THRESHOLD"; then
      legacy_ver="$temp_ver"
    fi
    # If version > 2.45.1, this path contains JCMB only — ignore for JCLW
  fi

  # Determine primary version and type
  if [ -n "$bundle_ver" ]; then
    jclw_ver="$bundle_ver"
    jclw_type="$(classify_jclw "$jclw_ver")"
    jclw_plist="$JCLW_BUNDLE_PLIST"
  elif [ -n "$legacy_ver" ]; then
    jclw_ver="$legacy_ver"
    jclw_type="$(classify_jclw "$jclw_ver")"
    jclw_plist="$LEGACY_JC_PLIST"
  fi

  # Output result
  if [ -z "$jclw_ver" ]; then
    echo "JCLW None NotInstalled"
  else
    output="JCLW ${jclw_type} ${jclw_ver}"

    # Add active/inactive status if enabled
    if [ "$SHOW_ACTIVE_STATUS" = "true" ]; then
      if [ -n "$bundle_ver" ] && [ "$active_location" = "bundle" ]; then
        output="${output} (Active)"
      elif [ -z "$bundle_ver" ] && [ -n "$legacy_ver" ] && [ "$active_location" = "legacy" ]; then
        output="${output} (Active)"
      elif [ "$active_location" = "none" ]; then
        output="${output} (Inactive)"
      else
        output="${output} (Inactive)"
      fi
    fi

    # Add timestamp if enabled
    if [ "$SHOW_TIMESTAMPS" = "true" ]; then
      timestamp="$(get_timestamp "$jclw_plist")"
      [ -n "$timestamp" ] && output="${output} [${timestamp}]"
    fi

    # Add multi-version annotation if enabled
    if [ "$SHOW_MULTI_VERSION" = "true" ] && [ -n "$bundle_ver" ] && [ -n "$legacy_ver" ] && [ "$bundle_ver" != "$legacy_ver" ]; then
      legacy_type="$(classify_jclw "$legacy_ver")"

      if [ "$SHOW_ACTIVE_STATUS" = "true" ]; then
        if [ "$active_location" = "legacy" ]; then
          output="${output} (also found JCLW ${legacy_type} ${legacy_ver} - Active)"
        else
          output="${output} (also found JCLW ${legacy_type} ${legacy_ver} - Inactive)"
        fi
      else
        output="${output} (also found JCLW ${legacy_type} ${legacy_ver})"
      fi
    fi

    echo "$output"
  fi
}

################################
# 3.4 - Evaluate Self Service+
################################
evaluate_ssp() {
  ssp_version="$(get_ssp_version)"
  classic_ss_ver=""

  # Check for classic Self Service — validate bundle ID to avoid false match when
  # SSP is custom-branded to a name that collides with the classic path (PI-1077).
  # e.g., if SSP is renamed to "Self Service.app", CLASSIC_SS_PLIST would resolve
  # to SSP without this check.
  if [ -f "$CLASSIC_SS_PLIST" ]; then
    classic_bid=$(/usr/bin/defaults read "$CLASSIC_SS_PLIST" CFBundleIdentifier 2>/dev/null)
    if [ "$classic_bid" = "$CLASSIC_SS_BUNDLE_ID" ]; then
      classic_ss_ver="$(get_ver "$CLASSIC_SS_PLIST")"
    fi
    # If bundle ID doesn't match, the path points to a renamed SSP — skip it
  fi

  # Build output
  if [ -n "$ssp_version" ]; then
    output="Self Service+ ${ssp_version}"

    # Add multi-version alert if both exist
    if [ "$SHOW_MULTI_VERSION" = "true" ] && [ -n "$classic_ss_ver" ]; then
      output="${output} (also found Self Service ${classic_ss_ver} - classic)"
    fi

    echo "$output"
  elif [ -n "$classic_ss_ver" ]; then
    # Only classic Self Service exists (unusual scenario)
    echo "Self Service ${classic_ss_ver} (classic)"
  else
    echo "Self Service+ None NotInstalled"
  fi
}

################################
# 4 - Main execution
################################

# Resolve SSP paths dynamically before evaluation.
# Handles Jamf Pro 11.25+ custom branding where the app bundle can be renamed
# (e.g., "SmartAsset Self Service.app") — finds it by CFBundleIdentifier instead.
resolve_ssp_paths

# Build output based on configuration
output_lines=""

if [ "$REPORT_SSP" = "true" ]; then
  ssp_fragment="$(evaluate_ssp)"
  output_lines="${ssp_fragment}"
fi

if [ "$REPORT_JCMB" = "true" ]; then
  jcmb_fragment="$(evaluate_jcmb)"
  if [ -n "$output_lines" ]; then
    output_lines="${output_lines}
${jcmb_fragment}"
  else
    output_lines="${jcmb_fragment}"
  fi
fi

if [ "$REPORT_JCLW" = "true" ]; then
  jclw_fragment="$(evaluate_jclw)"
  if [ -n "$output_lines" ]; then
    output_lines="${output_lines}
${jclw_fragment}"
  else
    output_lines="${jclw_fragment}"
  fi
fi

# Output result (both, one, or none based on configuration)
if [ -n "$output_lines" ]; then
  echo "<result>${output_lines}</result>"
else
  echo "<result>No components configured for reporting</result>"
fi
