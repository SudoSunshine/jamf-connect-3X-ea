# Jamf Connect Version 3.X

A Jamf Pro Extension Attribute for tracking Jamf Connect components across legacy and modern architectures.

## Background

Starting with version 3.0, Jamf Connect's architecture changed significantly. The Menu Bar component moved into Self Service+, and the Login Window became standalone. Jamf Pro's current Extension Attribute template only checks the legacy path and reports "Does not exist" for modern deployments.

This Extension Attribute addresses that limitation by detecting all components across both architectures.

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

### 3. Test

Force inventory on a test machine:
```bash
sudo jamf recon
```

Check the Extension Attribute value in Jamf Pro inventory.

## Output Examples

### Modern SSP Deployment
```
JCMB SSP 3.11.0 (Active)
JCLW Stand-alone 3.5.0 (Active)
```

### Legacy with Cleanup Needed
```
JCMB SSP 3.11.0 (Active) (also found JCMB Classic 3.11.0 - Inactive)
JCLW Classic 2.45.1 (Inactive)
```

### Pure Legacy Installation
```
JCMB Classic 2.45.1 (Active)
JCLW Classic 2.45.1 (Active)
```

## Configuration

The script includes four toggles (lines 33-36):

```bash
SHOW_SSP_VERSION="false"       # SSP version inline with JCMB
SHOW_ACTIVE_STATUS="true"      # Active/Inactive status (recommended)
SHOW_MULTI_VERSION="true"      # Multi-version cleanup alerts (recommended)
SHOW_TIMESTAMPS="false"        # Installation dates
```

## Smart Group Examples

### Find Machines with Active JCMB
```
Jamf Connect Components | like | JCMB
AND
Jamf Connect Components | like | Active
```

### Find Machines Needing Cleanup
```
Jamf Connect Components | like | also found
```

### Find SSP Deployments
```
Jamf Connect Components | like | JCMB SSP
```

## Architecture Details

### Pre-3.0 (≤ 2.45.1)
- Combined app at `/Applications/Jamf Connect.app/`
- JCMB and JCLW bundled together

### Post-3.0 (≥ 3.0.0)
- JCMB in Self Service+ at `/Applications/Self Service+.app/Contents/MacOS/Jamf Connect.app/`
- JCLW standalone at `/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/`

### Detection Logic

**JCMB:**
- Checks SSP path (modern)
- Checks legacy path (pre-3.0 or leftover)
- Daemon check: `launchctl list | grep com.jamf.connect.daemon`

**JCLW:**
- Checks bundle path (all versions)
- Checks legacy path (only if version ≤ 2.45.1)
- AuthDB check: `security authorizationdb read system.login.console`

## Testing

See [TESTING.md](TESTING.md) for comprehensive testing procedures.

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
