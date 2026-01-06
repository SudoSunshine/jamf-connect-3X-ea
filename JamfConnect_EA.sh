#!/bin/sh
# Extension Attribute: Jamf Connect 3.X Components
# Author: Ellie Romero
# Version: 2.6.0
# Last Update: 2026-01-05
#
# Brief Description:
#   This EA identifies which Jamf Connect components are installed post-3.0 split
#   and determines which components are actively registered.
#
#     • JCMB  = Jamf Connect Menu Bar
#     • JCLW  = Jamf Connect Login Window
#     • SSP   = Self Service+ (container for JCMB)
#
#   Version 3.0+ Split Architecture:
#     - Self Service+ 2.0.0+ contains JCMB 3.0.0+
#     - JCLW 3.0.0+ deployed separately to SecurityAgentPlugins
#     - Legacy (≤2.45.1) had JCMB+JCLW bundled in single app
#
#   Output Examples (Basic - Default Settings):
#       JCMB SSP 3.11.0 (Active)
#       JCLW Stand-alone 3.5.0 (Active)
#
#   Output Examples (All Features Enabled):
#       JCMB SSP 3.11.0 (Detected in SSP 2.13.0) (Active) [2025-11-04]
#       JCLW Classic 2.45.1 (Inactive) [2025-03-19] (also found JCLW Stand-alone 3.5.0 - Active)
#
################################
# CONFIGURATION & PATHS
################################

# Output customization (set to "true" or "false")
SHOW_SSP_VERSION="false"       # Show SSP version inline with JCMB
SHOW_ACTIVE_STATUS="true"      # Show Active/Inactive for JCLW (recommended)
SHOW_MULTI_VERSION="true"      # Show multi-version alerts (recommended)
SHOW_TIMESTAMPS="false"        # Show installation dates

# Constants
THRESHOLD="2.45.1"             # Classic vs modern cutoff

# File paths
SSP_APP_PLIST="/Applications/Self Service+.app/Contents/Info.plist"
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
    
    # JamfConnectLogin present but can't determine exact path
    # This shouldn't happen, but default to bundle (modern standard)
    echo "bundle"
  else
    # No JamfConnectLogin registered at all
    echo "none"
  fi
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
      # Determine if THIS version is active based on which daemon is loaded
      if [ -n "$ssp_ver" ] && [ "$active_daemon" = "ssp" ]; then
        # SSP version exists and SSP daemon is loaded
        output="${output} (Active)"
      elif [ -z "$ssp_ver" ] && [ -n "$legacy_ver" ] && [ "$active_daemon" = "legacy" ]; then
        # Only legacy exists and legacy daemon is loaded
        output="${output} (Active)"
      elif [ "$active_daemon" = "none" ]; then
        # No daemon loaded
        output="${output} (Inactive)"
      else
        # This is the primary but different daemon is loaded (edge case)
        output="${output} (Inactive)"
      fi
    fi
    
    if [ "$SHOW_TIMESTAMPS" = "true" ]; then
      timestamp="$(get_timestamp "$jcmb_plist")"
      [ -n "$timestamp" ] && output="${output} [${timestamp}]"
    fi
    
    if [ "$SHOW_MULTI_VERSION" = "true" ] && [ -n "$ssp_ver" ] && [ -n "$legacy_ver" ] && [ "$ssp_ver" != "$legacy_ver" ]; then
      legacy_type="$(classify_jcmb "$legacy_ver")"
      
      # Determine if secondary is active or inactive
      if [ "$SHOW_ACTIVE_STATUS" = "true" ]; then
        if [ "$active_daemon" = "legacy" ]; then
          # Secondary (legacy) daemon is actually loaded - unusual!
          output="${output} (also found JCMB ${legacy_type} ${legacy_ver} - Active)"
        else
          # Secondary is not active (normal)
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
  
  # Check legacy location - ONLY use for JCLW if version ≤ 2.45.1
  # After 3.0, /Applications/Jamf Connect.app/ contains ONLY JCMB (no JCLW)
  if [ -f "$LEGACY_JC_PLIST" ]; then
    temp_ver="$(get_ver "$LEGACY_JC_PLIST")"
    
    # Only use as JCLW source if version ≤ 2.45.1 (combined app era)
    if [ -n "$temp_ver" ] && ! version_gt "$temp_ver" "$THRESHOLD"; then
      legacy_ver="$temp_ver"
    fi
    # If version > 2.45.1, this path contains JCMB only - ignore for JCLW
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
      # Determine if THIS version is active based on which path is registered
      if [ -n "$bundle_ver" ] && [ "$active_location" = "bundle" ]; then
        # Bundle exists and bundle is registered in authdb
        output="${output} (Active)"
      elif [ -z "$bundle_ver" ] && [ -n "$legacy_ver" ] && [ "$active_location" = "legacy" ]; then
        # Only legacy exists and legacy is registered in authdb
        output="${output} (Active)"
      elif [ "$active_location" = "none" ]; then
        # Nothing registered in authdb
        output="${output} (Inactive)"
      else
        # This is the primary but different one is registered (edge case)
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
      
      # Determine if secondary is active or inactive
      if [ "$SHOW_ACTIVE_STATUS" = "true" ]; then
        if [ "$active_location" = "legacy" ]; then
          # Secondary (legacy) is actually registered - unusual!
          output="${output} (also found JCLW ${legacy_type} ${legacy_ver} - Active)"
        else
          # Secondary is not registered (normal)
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
# 4 - Main execution
################################

jcmb_fragment="$(evaluate_jcmb)"
jclw_fragment="$(evaluate_jclw)"

echo "<result>${jcmb_fragment}
${jclw_fragment}</result>"
