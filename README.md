# Jamf Connect Extension Attribute

A Jamf Pro Extension Attribute for tracking Jamf Connect components across legacy and modern architectures.

![Shell](https://img.shields.io/badge/shell-bash-yellow.svg)

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

### Legacy with Cleanup Needed
```
JCMB SSP 3.11.0 (Active) (also found JCMB Classic 2.45.1 - Inactive)
JCLW Classic 2.45.1 (Inactive)
```

### Pure Legacy Installation
```
JCMB Classic 2.45.1 (Active)
JCLW Classic 2.45.1 (Active)
```

### Jamf Connect Not Installed
```
JCMB None NotInstalled
JCLW None NotInstalled
```

## Configuration

The script includes six configuration toggles at the top:

```bash
# Component reporting (lines 50-51)
REPORT_JCMB="true"             # Report Menu Bar component
REPORT_JCLW="true"             # Report Login Window component

# Output customization (lines 54-57)
SHOW_SSP_VERSION="false"       # SSP version inline with JCMB
SHOW_ACTIVE_STATUS="true"      # Active/Inactive status (recommended)
SHOW_MULTI_VERSION="true"      # Multi-version cleanup alerts (recommended)
SHOW_TIMESTAMPS="false"        # Installation dates
```

### Component Reporting (Flexible Deployment)

You can use the **same script** for different purposes by changing just two variables:

#### **Option 1: Both Components (Default)**
```bash
REPORT_JCMB="true"
REPORT_JCLW="true"
```
**Output:** Both JCMB and JCLW on separate lines  
**Use case:** Complete inventory in a single EA  
**Recommended for:** Most environments, especially during SSP migration

---

#### **Option 2: JCMB Only**
```bash
REPORT_JCMB="true"
REPORT_JCLW="false"
```
**Output:** Only JCMB line  

---

#### **Option 3: JCLW Only**
```bash
REPORT_JCMB="false"
REPORT_JCLW="true"
```
**Output:** Only JCLW line  

---

**Note:** While the script supports single-component reporting, the recommended approach is to keep both enabled and use separate Smart Groups for tracking (see Smart Group Examples below).

### Output Customization

## Smart Group Examples

Smart Groups use the Extension Attribute to dynamically scope computers for policies, configuration profiles, and reporting.

### Critical: Understanding Operator Behavior

**Extension Attribute Structure:**
```
JCMB SSP 3.11.0 (Active)
JCLW Stand-alone 3.5.0 (Inactive)
```

The EA contains TWO LINES separated by a newline character.

#### **"like" Operator (RECOMMENDED)** ✅
Matches **substrings** within the EA output. Use this for all Smart Groups.

**Example:**
```
Jamf Connect - Version (3.X) | like | JCMB SSP
```
→ Matches because "JCMB SSP" exists in first line ✅

#### **"is" Operator (AVOID)** ❌
Requires EXACT match of the ENTIRE EA field (both lines + newline). This will almost never work.

**Example:**
```
Jamf Connect - Version (3.X) | is | JCMB SSP 3.11.0
```
→ Fails because EA contains TWO lines, not just "JCMB SSP 3.11.0" ❌

#### **Multi-line Searches Don't Work** ❌
You cannot search for the complete multi-line output as one string.

**Example:**
```
Jamf Connect - Version (3.X) | like | JCMB SSP 3.11.0JCLW Stand-alone 3.5.0
```
→ Fails because there's a newline between the lines ❌

### Best Practices for Smart Group Values

**❌ DON'T match entire lines (too specific):**
```
❌ like "JCMB SSP 3.12.0-rc.4 (Active)"
❌ like "JCLW Stand-alone 3.5.0 (Active)"
```
**Problem:** Breaks on every version update - requires constant Smart Group maintenance.

**✅ DO match component types (flexible):**
```
✅ like "JCMB SSP"
✅ like "JCLW Stand-alone"
✅ like "Classic"
```
**Benefit:** Works across all versions - no maintenance needed when Jamf Connect updates.

**✅ DO match status when needed:**
```
✅ like "(Active)"
✅ like "(Inactive)"
```
**Benefit:** Identifies functional state regardless of version.

**✅ DO match specific versions only when necessary:**
```
✅ like "3.12.0"        → Any component with version 3.12.0
✅ like "3.12.0-rc"     → Any RC build of 3.12.0
```
**Use case:** Tracking specific deployments or testing RC versions.

**Key Principle:** Use the **shortest substring** that identifies what you need. This keeps Smart Groups flexible and reduces maintenance overhead.

### Troubleshooting Smart Groups

**If Smart Group finds 0 computers:**

1. ✅ **Use "like" operator** - Never use "is" operator
2. ✅ **Match substrings only** - Don't try to match entire multi-line output
3. ✅ **Check exact casing** - Use "JCMB SSP" not "jcmb ssp" (case-sensitive)
4. ✅ **Test with simple criteria first** - Try just "JCMB" before adding complexity
5. ✅ **Verify EA is populated** - Check computer inventory shows EA data
6. ✅ **Ensure inventory is current** - Machines must have run inventory since EA was installed

### Recommended Smart Groups

Create these Smart Groups to track Jamf Connect deployments. All use the Extension Attribute with operator `like` and the values shown:

#### Essential Tracking
**1. JCMB in SSP** - `JCMB SSP`  
Modern Menu Bar deployments

**2. JCLW Standalone** - `JCLW Stand-alone`  
Modern Login Window deployments

**3. Active Components** - `(Active)`  
All functioning components

**4. Legacy Components** - `Classic`  
Machines needing migration to 3.0+

#### Problem Detection
**5. Cleanup Needed** - `also found`  
Multi-version installations requiring cleanup

**6. Not Installed** - `NotInstalled`  
Machines without Jamf Connect

**7. No Active JCLW** - `JCLW` AND `(Inactive)`  
Identity integration broken

#### Migration Tracking
**8. SSP Migration Complete** - `JCMB SSP` AND `JCLW Stand-alone`  
Fully modernized deployments

**9. Missing JCLW** - `JCMB` AND `JCLW None NotInstalled`  
Menu Bar deployed, Login Window missing

**10. Missing JCMB** - `JCLW` AND `JCMB None NotInstalled`  
Login Window deployed, Menu Bar missing

**Note:** All criteria use `Jamf Connect - Version (3.X) | like | [value]`. These short values work across all versions—no maintenance required when Jamf Connect updates.

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

Thank you to my teammates and Mac admin community for the feedback!

## License

MIT License - See [LICENSE](LICENSE) file

## Author

Ellie Romero ([@SudoSunshine](https://github.com/SudoSunshine))

## Support

- **Issues**: [GitHub Issues](https://github.com/SudoSunshine/jamf-connect-ea/issues)
- **Discussions**: [GitHub Discussions](https://github.com/SudoSunshine/jamf-connect-ea/discussions)
