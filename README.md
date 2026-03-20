# Jamf Connect 3.X Extension Attribute

![Shell](https://img.shields.io/badge/shell-bash-yellow.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-2.7.0-green.svg)
![Jamf Pro](https://img.shields.io/badge/Jamf%20Pro-11.24.0+-orange.svg)

A Jamf Pro Extension Attribute for tracking Jamf Connect components across legacy and modern architectures.

## Background

Starting with version 3.0, Jamf Connect's architecture changed significantly. The Menu Bar component moved into Self Service+, and the Login Window became standalone. Jamf Pro's built-in Extension Attribute template only checks the legacy path and reports "Does not exist" for modern deployments.

This EA detects components across both architectures.

## Features

- Detects Self Service+ (SSP), Menu Bar (JCMB), and Login Window (JCLW) components
- Shows active/inactive status for each component
- Flags multi-version scenarios from partial migrations
- Distinguishes between SSP and Classic, Stand-alone and Classic
- Works with all Jamf Connect versions from 2.45.1 to current
- Locates Self Service+ by bundle identifier — unaffected by Jamf Pro 11.25 custom branding renames
- Configurable output options

## Quick Start

### Add to Jamf Pro

1. Go to **Settings → Computer Management → Extension Attributes**
2. Click **+ New**
3. Configure:
   - **Display Name**: `Jamf Connect SSP`
   - **Description**: `Tracks SSP, JCMB, and JCLW versions and status`
   - **Data Type**: `String`
   - **Input Type**: `Script`
4. Paste the script contents and save

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

Default configuration reports both components:

```bash
REPORT_JCMB="true"              # Report Menu Bar component
REPORT_JCLW="true"              # Report Login Window component
SHOW_ACTIVE_STATUS="true"       # Show Active/Inactive status
SHOW_MULTI_VERSION="true"       # Show multi-version alerts
```

Keep the defaults and use separate Smart Groups for JCMB and JCLW — it's more flexible than trying to filter both in one criteria.

## Smart Group Examples

### Quick Reference

Always use `like` (substring matching), not `is`. The EA outputs two lines, and `is` requires an exact match of the entire field.

You can't filter for both JCMB and JCLW in a single Smart Group criteria — the newline between the two output lines breaks the match. Create one Smart Group per component instead.

**Best Practice:** Use short values like `JCMB SSP` rather than full strings like `JCMB SSP 3.12.0-rc.4 (Active)`. Short values remain valid across version updates with no ongoing maintenance.

### Essential Smart Groups

**1. JCMB in SSP** → `like "JCMB SSP"`
**2. JCLW Standalone** → `like "JCLW Stand-alone"`
**3. Active Components** → `like "(Active)"`
**4. Not Installed** → `like "NotInstalled"`
**5. Cleanup Needed** → `like "also found"`

**Tracking JCMB version currency:** JCMB and SSP always share the same version number, as JCMB is shipped inside SSP. Filtering on `like "JCMB SSP 3.12"` is equivalent to checking the SSP version — both reflect the same update event.

## Architecture Details

### Jamf Connect 3.0 Changes

**Pre-3.0 (≤ 2.45.1):** JCMB and JCLW were combined in `/Applications/Jamf Connect.app/`

**Post-3.0 (≥ 3.0.0):**
- JCMB → embedded in Self Service+ at `/Applications/Self Service+.app/.../Jamf Connect.app/`
- JCLW → standalone at `/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/`

### SSP Version = JCMB Version

Because JCMB is bundled inside Self Service+, both components always share a version number. When SSP updates, JCMB updates with it. Tracking the SSP version is sufficient to determine whether JCMB is current across your fleet — there is no need to inspect the embedded JCMB path separately.

### Complementary Jamf Pro EA Templates

Jamf Pro includes a built-in EA template called **Jamf Connect - Connect Login Plugin Version** that tracks solely the JCLW mechanism. If monitoring JCLW is the only requirement, that template is the simpler option.

This EA goes further by also tracking JCMB and SSP, showing active/inactive status for each component, and flagging multi-version scenarios from partial migrations.

## Jamf Pro 11.25 Custom Branding (PI-1077)

Jamf Pro 11.25 enabled custom branding for Self Service+. When a macOS branding configuration exists — including one created automatically on upgrade — Jamf Pro pushes a new application name to enrolled clients, which renames the Self Service+ `.app` bundle on disk. Previous versions of this EA would fail to detect SSP in these environments because they relied on the app name rather than its identity.

In environments where SSP was renamed to `Self Service.app` (the Jamf Pro 11.25 default branding name), the EA could also misidentify the renamed SSP as the classic Self Service app.

**v2.7.0 resolves this** by locating SSP via its bundle identifier (`com.jamf.selfserviceplus`) rather than its app name. Classic Self Service is also validated by bundle ID (`com.jamfsoftware.selfservice.mac`) to prevent the path collision.

If you can't upgrade to v2.7.0 right away, the workarounds are:
1. Set the branding application name back to `Self Service+` in Jamf Pro
2. Delete the macOS branding configuration entirely

## Limitations

- Detects component presence and version, but does not verify configuration validity (IdP settings, sync state)
- Active status relies on system daemons and the authorization database — edge cases may exist in non-standard configurations
- Requires root privileges (runs during inventory collection)

## Testing

Tested with Jamf Pro 11.24.0–11.25, Jamf Connect 2.45.1–3.12.0, and macOS 13.x–15.x. See [CHANGELOG](CHANGELOG.md) for details.

## Version History

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

## Contributing

Contributions welcome. Please test changes across multiple Jamf Connect versions and update the docs accordingly.

## License

MIT — see [LICENSE](LICENSE)

## Author

Ellie Romero ([@SudoSunshine](https://github.com/SudoSunshine))

## Support

- **Issues**: [GitHub Issues](https://github.com/SudoSunshine/jamf-connect-3X-ea/issues)
- **Discussions**: [GitHub Discussions](https://github.com/SudoSunshine/jamf-connect-3X-ea/discussions)
- **Mac Admins Slack**: [Join #jamf channel](https://join.slack.com/t/macadmins/shared_invite/zt-3ok3rukoj-ziZeIXzbqP~_65HM3R53Yw)
