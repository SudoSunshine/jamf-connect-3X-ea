# Jamf Connect Extension Attribute

A comprehensive Jamf Pro Extension Attribute for tracking Jamf Connect components in the post-3.0 architecture, including Self Service+ (SSP), Jamf Connect Menu Bar (JCMB), and Jamf Connect Login Window (JCLW).

## Overview

This Extension Attribute accurately tracks all Jamf Connect components across the architecture split that occurred at version 3.0, when JCMB moved into Self Service+ and JCLW became standalone.

### Key Features

- ✅ **Complete Component Tracking**: SSP, JCMB, and JCLW versions
- ✅ **Active Status Detection**: Shows which components are actually running
- ✅ **Multi-Version Detection**: Identifies cleanup candidates from partial migrations
- ✅ **Smart Classification**: Distinguishes SSP vs Classic, Stand-alone vs Classic
- ✅ **Configurable Output**: Four granular feature toggles
- ✅ **Production-Tested**: Validated against real Jamf Connect installers

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

### Recommended Settings

**Default** (clean, informative):
```bash
SHOW_SSP_VERSION="false"
SHOW_ACTIVE_STATUS="true"
SHOW_MULTI_VERSION="true"
SHOW_TIMESTAMPS="false"
```

**Minimal** (just versions):
```bash
SHOW_SSP_VERSION="false"
SHOW_ACTIVE_STATUS="false"
SHOW_MULTI_VERSION="false"
SHOW_TIMESTAMPS="false"
```

**Maximum** (all details):
```bash
SHOW_SSP_VERSION="true"
SHOW_ACTIVE_STATUS="true"
SHOW_MULTI_VERSION="true"
SHOW_TIMESTAMPS="true"
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

### Find Machines with Inactive JCLW
```
Jamf Connect Components | like | JCLW
AND
Jamf Connect Components | like | Inactive
```

### Find SSP Deployments
```
Jamf Connect Components | like | JCMB SSP
```

### Find Legacy Deployments
```
Jamf Connect Components | like | JCMB Classic
```

## Architecture Details

### Jamf Connect Version History

**Pre-3.0 (≤ 2.45.1):**
- Combined app at `/Applications/Jamf Connect.app/`
- JCMB and JCLW bundled together
- JCLW also in `/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/`

**Post-3.0 (≥ 3.0.0):**
- JCMB moved into Self Service+ at `/Applications/Self Service+.app/Contents/MacOS/Jamf Connect.app/`
- JCLW standalone at `/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/`
- JCLW versions: 3.0.0, 3.1.0, 3.2.0, 3.3.0, 3.4.0, 3.5.0+

### Detection Logic

**JCMB:**
- Checks SSP path (modern)
- Checks legacy path (pre-3.0 or leftover)
- Daemon check: `launchctl list | grep com.jamf.connect.daemon`

**JCLW:**
- Checks bundle path (all versions)
- Checks legacy path (only if version ≤ 2.45.1)
- AuthDB check: `security authorizationdb read system.login.console`

## Troubleshooting

### EA Shows "NotInstalled" But Components Exist

**Check file permissions:**
```bash
ls -la /Applications/Self\ Service+.app/Contents/MacOS/Jamf\ Connect.app/Contents/Info.plist
ls -la /Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/Contents/Info.plist
```

**Verify plist readable:**
```bash
defaults read "/Applications/Self Service+.app/Contents/MacOS/Jamf Connect.app/Contents/Info.plist" CFBundleShortVersionString
```

### Active Status Shows Inactive But Component Running

**Check daemon/authdb manually:**

For JCMB:
```bash
launchctl list | grep jamf.connect
```

For JCLW:
```bash
security authorizationdb read system.login.console | grep -i jamfconnect
```

### Wrong Version Showing as Active

This is expected when an admin has manually used `authchanger` to register a different version than the primary one. The EA correctly identifies this edge case.

## Version History

- **v2.6.0** (2024-12-24) - Fixed JCLW false detection from legacy JCMB path
- **v2.5.0** (2024-12-24) - Added JCMB active status detection
- **v2.4.0** (2024-12-24) - Enhanced JCLW active detection (checks authdb path)
- **v2.3.0** (2024-12-24) - Granular feature toggles, consolidated config
- **v2.2.0** (2024-12-24) - Added JCLW active/inactive status
- **v2.1.0** (2024-12-24) - SSP version inline with JCMB
- **v2.0.0** (2024-12-24) - Added SSP version detection
- **v1.10.1** (2024-12-23) - Fixed XML result tags
- **v1.0.0** (2024-12-23) - Initial combined EA

## Testing

See [TESTING.md](TESTING.md) for comprehensive testing procedures.

## Contributing

Contributions welcome! Please:
1. Test changes on multiple Jamf Connect versions
2. Update documentation
3. Follow existing code style
4. Add test cases

## License

MIT License - See [LICENSE](LICENSE) file

## Author

**Ellie Romero** ([@SudoSunshine](https://github.com/SudoSunshine))

## Acknowledgments

Built for the Jamf community to simplify Jamf Connect 3.0+ deployments.

## Support

- **Issues**: [GitHub Issues](https://github.com/SudoSunshine/jamf-connect-ea/issues)
- **Discussions**: [GitHub Discussions](https://github.com/SudoSunshine/jamf-connect-ea/discussions)

## Resources

- [Jamf Connect Documentation](https://docs.jamf.com/jamf-connect/documentation/)
- [Jamf Pro Extension Attributes](https://learn.jamf.com/bundle/jamf-pro-documentation/page/Extension_Attributes.html)
