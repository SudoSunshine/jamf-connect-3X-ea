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
**Use case:** Separate EA for Menu Bar tracking, SSP adoption metrics  
**How to deploy:** Create EA named "Jamf Connect Menu Bar" with these settings

---

#### **Option 3: JCLW Only**
```bash
REPORT_JCMB="false"
REPORT_JCLW="true"
```
**Output:** Only JCLW line  
**Use case:** Separate EA for Login Window tracking, identity compliance  
**How to deploy:** Create EA named "Jamf Connect Login Window" with these settings

---

### Creating Multiple EAs from One Script

**Workflow for separate component tracking:**

1. **Create EA #1** - "Jamf Connect Menu Bar"
   - Paste script
   - Set `REPORT_JCMB="true"` and `REPORT_JCLW="false"`
   - Save

2. **Create EA #2** - "Jamf Connect Login Window"
   - Paste same script
   - Set `REPORT_JCMB="false"` and `REPORT_JCLW="true"`
   - Save

**Benefits:**
- ✅ Maintain one script codebase
- ✅ Easy to update both EAs
- ✅ Cleaner Smart Group criteria
- ✅ Separate reporting per component

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

**Proven Working Patterns (from testing):**
- ✅ `like "JCMB SSP"` - Finds machines with JCMB
- ✅ `like "JCLW Stand-alone"` - Finds machines with standalone JCLW
- ✅ `like "3.11.0"` - Finds machines with any component version 3.11.0
- ✅ `like "(Active)"` - Finds machines with active components
- ❌ `is "JCMB SSP 3.11.0"` - Will NOT work (requires exact match of entire field)

### Recommended Smart Groups to Create

These Smart Groups provide practical value for Jamf Connect management without requiring constant maintenance:

#### 1. JCMB in Self Service+ (Modern Deployment)
```
Name: Jamf Connect - JCMB in SSP
Criteria: Jamf Connect - Version (3.X) | like | JCMB SSP
Purpose: Track modern JCMB deployments across all versions
```

#### 2. Standalone JCLW (Modern Deployment)
```
Name: Jamf Connect - JCLW Standalone
Criteria: Jamf Connect - Version (3.X) | like | JCLW Stand-alone
Purpose: Track modern JCLW deployments across all versions
```

#### 3. Legacy Components Still Deployed
```
Name: Jamf Connect - Legacy Components
Criteria: Jamf Connect - Version (3.X) | like | Classic
Purpose: Identify machines that haven't migrated to 3.0+ architecture
```

#### 4. Active Components (All Types)
```
Name: Jamf Connect - Active Components
Criteria: Jamf Connect - Version (3.X) | like | (Active)
Purpose: All machines with functioning Jamf Connect components
```

#### 5. Multi-Version Cleanup Needed
```
Name: Jamf Connect - Cleanup Needed
Criteria: Jamf Connect - Version (3.X) | like | also found
Purpose: Machines with leftover old versions needing cleanup
```

#### 6. SSP Migration Complete
```
Name: Jamf Connect - SSP Migration Complete
Criteria 1: Jamf Connect - Version (3.X) | like | JCMB SSP
AND
Criteria 2: Jamf Connect - Version (3.X) | like | JCLW Stand-alone
Purpose: Machines fully migrated to modern architecture
```

#### 7. No Active Login Window
```
Name: Jamf Connect - No Active JCLW
Criteria 1: Jamf Connect - Version (3.X) | like | JCLW
AND
Criteria 2: Jamf Connect - Version (3.X) | like | (Inactive)
Purpose: Identity integration broken or disabled
```

#### 8. Machines WITHOUT Jamf Connect
```
Name: Jamf Connect - Not Installed
Criteria: Jamf Connect - Version (3.X) | like | NotInstalled
Purpose: Machines that don't have Jamf Connect installed at all
```

#### 9. JCMB Installed, JCLW Missing
```
Name: Jamf Connect - Missing Login Window
Criteria 1: Jamf Connect - Version (3.X) | like | JCMB
AND
Criteria 2: Jamf Connect - Version (3.X) | like | JCLW None NotInstalled
Purpose: Menu Bar deployed but identity integration missing
```

#### 10. JCLW Installed, JCMB Missing
```
Name: Jamf Connect - Missing Menu Bar
Criteria 1: Jamf Connect - Version (3.X) | like | JCLW
AND
Criteria 2: Jamf Connect - Version (3.X) | like | JCMB None NotInstalled
Purpose: Identity integration deployed but menu bar missing
```

**Pro Tip:** These Smart Groups use short, generic values that work across all Jamf Connect versions - no updates needed when new versions release!

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
