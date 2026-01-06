# Testing Guide

This guide provides comprehensive testing procedures for the Jamf Connect Extension Attribute.

## Quick Test

Run the EA script directly on a test machine:

```bash
sudo bash JamfConnect_EA.sh
```

Expected output format:
```xml
<r>JCMB [Type] [Version] ([Status])
JCLW [Type] [Version] ([Status])</r>
```

## Test Scenarios

### Scenario 1: Modern SSP Deployment

**System State:**
- Self Service+ installed with JCMB
- Modern JCLW standalone

**Expected Output:**
```xml
<r>JCMB SSP 3.x (Active)
JCLW Stand-alone 3.x (Active)</r>
```

**Validation:**
```bash
# Verify JCMB in SSP
defaults read "/Applications/Self Service+.app/Contents/MacOS/Jamf Connect.app/Contents/Info.plist" CFBundleShortVersionString

# Verify JCLW standalone
defaults read "/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/Contents/Info.plist" CFBundleShortVersionString

# Check daemons
launchctl list | grep jamf.connect

# Check authdb
security authorizationdb read system.login.console | grep -i jamfconnect
```

---

### Scenario 2: Pure Legacy (2.45.1)

**System State:**
- Jamf Connect 2.45.1 (combined app)
- No SSP

**Expected Output:**
```xml
<r>JCMB Classic 2.45.1 (Active)
JCLW Classic 2.45.1 (Active)</r>
```

**Validation:**
```bash
# Verify combined app
defaults read "/Applications/Jamf Connect.app/Contents/Info.plist" CFBundleShortVersionString

# Verify bundle
defaults read "/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/Contents/Info.plist" CFBundleShortVersionString

# Check daemon
launchctl list | grep "com.jamf.connect.daemon$"

# Check authdb
security authorizationdb read system.login.console | grep JamfConnectLogin
```

---

### Scenario 3: SSP + Old JCLW + Legacy Leftover

**System State:**
- SSP with JCMB 3.11.0
- Old JCLW 2.45.1 in bundle
- Legacy Jamf Connect.app 2.45.1 leftover

**Expected Output:**
```xml
<r>JCMB SSP 3.11.0 (Active) (also found JCMB Classic 2.45.1 - Inactive)
JCLW Classic 2.45.1 (Inactive)</r>
```

**Critical Check:**
- ✅ Legacy 2.45.1 should appear under JCMB (as leftover cleanup candidate)
- ✅ JCLW should NOT show "also found JCLW 3.11.0"
- ✅ This validates the v2.6 critical bug fix

**Validation:**
```bash
# Three files should exist:
ls -la "/Applications/Self Service+.app/Contents/MacOS/Jamf Connect.app/Contents/Info.plist"
ls -la "/Applications/Jamf Connect.app/Contents/Info.plist"
ls -la "/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/Contents/Info.plist"

# Verify versions
defaults read "/Applications/Self Service+.app/Contents/MacOS/Jamf Connect.app/Contents/Info.plist" CFBundleShortVersionString  # 3.11.0
defaults read "/Applications/Jamf Connect.app/Contents/Info.plist" CFBundleShortVersionString  # 3.11.0
defaults read "/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/Contents/Info.plist" CFBundleShortVersionString  # 2.45.1

# Check which daemon is running
launchctl list | grep jamf.connect  # Should show .ssp

# Check authdb
security authorizationdb read system.login.console | grep -i jamfconnect  # Should be empty or not contain JamfConnectLogin
```

---

### Scenario 4: Nothing Installed

**System State:**
- No Jamf Connect components

**Expected Output:**
```xml
<r>JCMB None NotInstalled
JCLW None NotInstalled</r>
```

---

### Scenario 5: JCLW Not Configured

**System State:**
- JCLW files exist but not registered in authdb

**Expected Output:**
```xml
<r>JCMB [Type] [Version] (Active)
JCLW [Type] [Version] (Inactive)</r>
```

**Validation:**
```bash
# JCLW files should exist
ls -la /Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/

# But authdb should not contain JamfConnectLogin
security authorizationdb read system.login.console | grep -i jamfconnectlogin || echo "Not configured (correct)"
```

---

## Automated Test Script

Save as `test_ea.sh`:

```bash
#!/bin/bash

echo "=========================================="
echo "Jamf Connect EA Test Suite"
echo "=========================================="
echo ""

# Test 1: Script syntax
echo "Test 1: Checking script syntax..."
bash -n JamfConnect_EA.sh
if [ $? -eq 0 ]; then
    echo "✅ PASS: Syntax valid"
else
    echo "❌ FAIL: Syntax errors found"
    exit 1
fi
echo ""

# Test 2: Script execution
echo "Test 2: Executing script..."
output=$(sudo bash JamfConnect_EA.sh 2>&1)
if [ $? -eq 0 ]; then
    echo "✅ PASS: Script executed successfully"
else
    echo "❌ FAIL: Script execution failed"
    echo "$output"
    exit 1
fi
echo ""

# Test 3: Output format
echo "Test 3: Validating output format..."
if echo "$output" | grep -q "^<r>"; then
    echo "✅ PASS: Output starts with <r>"
else
    echo "❌ FAIL: Output missing <r> tag"
    exit 1
fi

if echo "$output" | grep -q "</r>$"; then
    echo "✅ PASS: Output ends with </r>"
else
    echo "❌ FAIL: Output missing </r> tag"
    exit 1
fi

if echo "$output" | grep -q "JCMB"; then
    echo "✅ PASS: JCMB component present"
else
    echo "❌ FAIL: JCMB component missing"
    exit 1
fi

if echo "$output" | grep -q "JCLW"; then
    echo "✅ PASS: JCLW component present"
else
    echo "❌ FAIL: JCLW component missing"
    exit 1
fi
echo ""

# Test 4: Version detection
echo "Test 4: Checking version detection..."
echo "$output" | sed 's/<r>//; s/<\/r>//'
echo ""

# Test 5: File permissions
echo "Test 5: Checking file permissions..."
if [ -r "JamfConnect_EA.sh" ]; then
    echo "✅ PASS: Script is readable"
else
    echo "❌ FAIL: Script not readable"
    exit 1
fi
echo ""

# Summary
echo "=========================================="
echo "✅ ALL TESTS PASSED"
echo "=========================================="
echo ""
echo "Actual output:"
echo "$output"
```

Run tests:
```bash
chmod +x test_ea.sh
sudo ./test_ea.sh
```

---

## Configuration Testing

Test each configuration combination:

### Test 1: Minimal Output
```bash
# Edit script:
SHOW_SSP_VERSION="false"
SHOW_ACTIVE_STATUS="false"
SHOW_MULTI_VERSION="false"
SHOW_TIMESTAMPS="false"

# Expected: Just types and versions
# JCMB SSP 3.11.0
# JCLW Classic 2.45.1
```

### Test 2: Maximum Output
```bash
# Edit script:
SHOW_SSP_VERSION="true"
SHOW_ACTIVE_STATUS="true"
SHOW_MULTI_VERSION="true"
SHOW_TIMESTAMPS="true"

# Expected: All details
# JCMB SSP 3.11.0 (Detected in SSP 2.13.0) (Active) [2024-11-04] (also found JCMB Classic 3.11.0 - Inactive)
# JCLW Classic 2.45.1 (Inactive) [2024-03-19]
```

---

## Jamf Pro Integration Testing

### 1. Upload EA to Jamf Pro

1. Settings → Extension Attributes → + New
2. Paste script
3. Save

### 2. Force Inventory Update

On test machines:
```bash
sudo jamf recon
```

### 3. Verify in Jamf Pro

1. Computers → Search for test machine
2. Click machine → Inventory tab
3. Scroll to Extension Attributes
4. Find "Jamf Connect Components"
5. Verify output matches expected

### 4. Test Smart Groups

Create test Smart Groups:
```
Criteria: Jamf Connect Components | like | JCMB SSP
```

Verify machines appear correctly.

---

## Regression Testing

When making changes, test all scenarios:

- [ ] Pure legacy 2.45.1
- [ ] SSP with modern JCLW
- [ ] SSP with old JCLW  
- [ ] SSP with legacy leftover
- [ ] Nothing installed
- [ ] JCLW not configured
- [ ] Multiple versions (cleanup needed)
- [ ] Wrong version active (edge case)

---

## Performance Testing

```bash
# Test execution time
time sudo bash JamfConnect_EA.sh

# Expected: < 1 second
```

---

## Shellcheck Validation

```bash
shellcheck -s sh JamfConnect_EA.sh

# Expected: No errors
```

---

## Edge Case Testing

### Edge Case 1: Corrupted Plist

```bash
# Create corrupted plist (backup first!)
sudo cp /path/to/Info.plist /path/to/Info.plist.backup
echo "corrupted" | sudo tee /path/to/Info.plist

# Run EA
sudo bash JamfConnect_EA.sh

# Expected: Should handle gracefully (NotInstalled)

# Restore
sudo mv /path/to/Info.plist.backup /path/to/Info.plist
```

### Edge Case 2: Manual authchanger

```bash
# Register wrong JCLW manually
sudo authchanger -reset -JamfConnect "/Applications/Jamf Connect.app/Contents/MacOS/JamfConnectLogin"

# Run EA
sudo bash JamfConnect_EA.sh

# Expected: Should detect and show correct Active/Inactive status
```

---

## Documentation

All tests should document:
- System configuration
- Expected output
- Actual output  
- Pass/Fail status
- Any deviations

Example test log:
```
Date: 2026-01-05
Machine: MacBook Pro (M1)
OS: macOS 15.2
JC Version: SSP 2.13.0 + JCMB 3.11.0 + JCLW 2.45.1 + Legacy 2.45.1

Test: Scenario 3 (SSP + Old JCLW + Legacy)
Expected: JCMB SSP 3.11.0 (Active) (also found JCMB Classic 2.45.1 - Inactive) / JCLW Classic 2.45.1 (Inactive)
Actual: JCMB SSP 3.11.0 (Active) (also found JCMB Classic 2.45.1 - Inactive) / JCLW Classic 2.45.1 (Inactive)
Actual: JCMB SSP 3.11.0 (Active) (also found JCMB Classic 3.11.0 - Inactive) / JCLW Classic 2.45.1 (Inactive)
Result: ✅ PASS
```
