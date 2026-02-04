# Jamf Connect 3.X Extension Attribute

![Shell](https://img.shields.io/badge/shell-bash-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-2.6.1-green.svg)
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

## Limitations

- Detects component presence and version, but does not verify configuration validity (IdP settings, sync state)
- Active status detection relies on system daemons/authorization database; edge cases may exist
- Requires root privileges (runs during inventory collection)

## Testing

Tested with Jamf Pro 11.24.0, Jamf Connect 2.45.1-3.12.0, and macOS 13.x-15.x. See [CHANGELOG](CHANGELOG.md) for detailed testing information.

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
