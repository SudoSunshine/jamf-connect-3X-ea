# Jamf Connect 3.X Extension Attribute

![Shell](https://img.shields.io/badge/shell-bash-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-2.7.0-green.svg)
![Jamf Pro](https://img.shields.io/badge/Jamf%20Pro-11.24.0+-orange.svg)

A Jamf Pro Extension Attribute for tracking Jamf Connect components across legacy and modern architectures.

## Background

Starting with version 3.0, Jamf Connect's architecture changed significantly. The Menu Bar component moved into Self Service+, and the Login Window became standalone. Jamf Pro's current Extension Attribute template only checks the legacy path and reports "Does not exist" for modern deployments.

This Extension Attribute detects components across both architectures.

## Features

- Detects Self Service+ (SSP), Menu Bar (JCMB), and Login Window (JCLW) components
- Shows active/inactive status for each component
- Identifies multi-version scenarios from partial migrations
- Distinguishes between SSP and Classic, Stand-alone and Classic
- Works with all Jamf Connect versions from 2.45.1 to current
- Detects Self Service+ by bundle identifier — unaffected by Jamf Pro 11.25 custom branding renames
- Configurable output options

## Quick Start

### 1. Download the Script

```bash
curl -O https://raw.githubusercontent.com/SudoSunshine/jamf-connect-ea/main/JamfConnect_EA.sh
```

### 2. Add to Jamf Pro

1. Navigate to **Settings** → **Computer Management** → **Extension Attributes**
2. Click **+ New**
3. Configure:
   - **Display Name**: `Jamf Connect Components`
   - **Description**: `Tracks SSP, JCMB, and JCLW versions and status`
   - **Data Type**: `String`
   - **Input Type**: `Script`
4. Paste the script contents
5. Click **Save**

## Output Examples

### Modern SSP Deployment
```
JCMB SSP 3.11.0 (Active)
JCLW Stand-alone 3.5.0 (Active)
```

### Jamf Connect Not Installed
```
JCMB None NotInstalled
JCLW None NotInstalled
```

## Configuration

Default configuration reports both components for maximum flexibility:

```bash
REPORT_JCMB="true"              # Report Menu Bar component
REPORT_JCLW="true"              # Report Login Window component
SHOW_ACTIVE_STATUS="true"       # Show Active/Inactive status
SHOW_MULTI_VERSION="true"       # Show multi-version alerts
```

**Recommended:** Keep default settings and use separate Smart Groups to track JCMB and JCLW individually (see below).

**Optional:** Additional toggles available for SSP version display, timestamps, etc.

## Smart Group Examples

### Quick Reference

**Operator:** Always use `like` (substring matching)  
**Format:** `Jamf Connect - Version (3.X) | like | [value]`

**Best Practice:** Use short values like `JCMB SSP` instead of full strings like `JCMB SSP 3.12.0-rc.4 (Active)`. Short values work across all versions with no maintenance.

### Essential Smart Groups

**1. JCMB in SSP** → `like "JCMB SSP"`
**2. JCLW Standalone** → `like "JCLW Stand-alone"`
**3. Active Components** → `like "(Active)"`
**4. Not Installed** → `like "NotInstalled"`
**5. Cleanup Needed** → `like "also found"`

**Tip — tracking JCMB version currency:** Since JCMB and SSP always share the same version, you can target a specific JCMB version using either `like "JCMB SSP 3.12"` or by querying the SSP version directly. Both reflect the same update event.

### Why "like" Not "is"

The EA outputs TWO lines (one for JCMB, one for JCLW). The "is" operator requires exact match of both lines, so it won't work. Use "like" to match individual components.

**Note:** You cannot search for both components in a single criteria (e.g., `like "JCMB SSP 3.11.0 JCLW Classic 2.45.1"`). The newline between lines breaks the match. Use separate Smart Groups to track each component.

## Architecture Details

### Jamf Connect Architecture Changes in 3.0

**Pre-3.0 (≤ 2.45.1):** Combined app with JCMB + JCLW at `/Applications/Jamf Connect.app/`

**Post-3.0 (≥ 3.0.0):**
- JCMB → Embedded in Self Service+ at `/Applications/Self Service+.app/.../Jamf Connect.app/`
- JCLW → Standalone at `/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/`

The script detects both architectures and correctly identifies which components are present and active.

### SSP Version as a JCMB Proxy

Because JCMB is shipped inside Self Service+, **JCMB always shares its version number with SSP** — when SSP updates, JCMB updates with it. This means you can use the SSP version as an equivalent signal for JCMB currency. If you want to know whether JCMB is up to date across your fleet, tracking the SSP version (via this EA with `REPORT_SSP="true"`, or via Jamf Pro's built-in Self Service inventory) is sufficient — you don't need to inspect the embedded JCMB path separately.

**Practical tip:** A Smart Group on `like "JCMB SSP 3.12"` (or whatever your target version is) effectively identifies machines with an up-to-date Menu Bar without needing a separate SSP-focused query.

### Complementary Jamf Pro EA Templates

Jamf Pro includes a built-in EA template called **Jamf Connect - Connect Login Plugin Version** that tracks solely the JCLW mechanism (the login window plugin registered in the authorization database). If your only goal is monitoring JCLW, that built-in template is the simpler option.

This EA complements it by:
- Tracking JCMB and SSP in addition to JCLW
- Detecting active/inactive status for each component
- Flagging multi-version scenarios from partial migrations
- Working correctly across both pre-3.0 and post-3.0 architectures

## Jamf Pro 11.25 Custom Branding Compatibility (PI-1077)

Jamf Pro 11.25 introduced custom branding for Self Service+, which allows admins to rename the application. When a macOS branding configuration exists — even with default settings — Jamf Pro sends a `brandingApplicationName` to enrolled clients during version-info check-ins, which causes Self Service+ to rename its `.app` bundle on disk.

**What breaks:** If SSP is renamed (e.g., to `SmartAsset Self Service.app` or `Self Service.app`), path-based detection fails entirely. Additionally, if SSP is renamed to `Self Service.app`, it can collide with the classic Self Service path, causing false positives.

**How v2.7.0 fixes it:** SSP is now located by `CFBundleIdentifier` (`com.jamf.selfserviceplus`) rather than by app name. Spotlight (`mdfind`) is queried first for speed, with a direct `/Applications` scan as fallback for environments where Spotlight is disabled or the index is stale. Classic Self Service is also validated by its bundle ID (`com.jamfsoftware.selfservice.mac`) to prevent collision with a renamed SSP.

**Affected environments:** Any Jamf Pro 11.25+ environment where a macOS Self Service branding configuration was created (including automatically-created default configurations).

**Workarounds if not yet on v2.7.0:**
1. In Jamf Pro, set the branding application name back to `Self Service+`
2. Delete the macOS branding configuration entirely
3. Upgrade to v2.7.0

## Limitations

- Detects component presence and version, but does not verify configuration validity (IdP settings, sync state)
- Active status detection relies on system daemons/authorization database; edge cases may exist
- Requires root privileges (runs during inventory collection)

## Testing

Tested with Jamf Pro 11.24.0-11.25, Jamf Connect 2.45.1-3.12.0, and macOS 13.x-15.x. See [CHANGELOG](CHANGELOG.md) for detailed testing information.

## Version History

See [CHANGELOG.md](CHANGELOG.md) for complete version history.

## Contributing

Contributions welcome! Please test changes on multiple Jamf Connect versions and update documentation accordingly.

## License

MIT License - See [LICENSE](LICENSE) file

## Author

Ellie Romero ([@SudoSunshine](https://github.com/SudoSunshine))

## Support

- **Issues**: [GitHub Issues](https://github.com/SudoSunshine/jamf-connect-ea/issues)
- **Discussions**: [GitHub Discussions](https://github.com/SudoSunshine/jamf-connect-ea/discussions)
- **Mac Admins Slack**: [Join #jamf channel](https://join.slack.com/t/macadmins/shared_invite/zt-3ok3rukoj-ziZeIXzbqP~_65HM3R53Yw)
