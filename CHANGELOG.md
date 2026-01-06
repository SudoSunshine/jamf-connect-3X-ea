# Jamf Connect 3.X EA - Version 2.6 Changelog

## 🐛 v2.6.0 - Critical JCLW Detection Fix (Released: January 5, 2026)

### **Critical Bug Fixed:**

**JCLW False Detection from Legacy Path**

Previous versions incorrectly reported JCMB versions as JCLW when found in the legacy `/Applications/Jamf Connect.app/` path.

---

## 🚨 The Problem

### **Architecture Truth:**

**Pre-3.0 (Version 2.45.1 and earlier):**
- `/Applications/Jamf Connect.app/` = **JCMB + JCLW combined** ✓

**Post-3.0 (Version 3.0.0 and later):**
- `/Applications/Jamf Connect.app/` = **JCMB ONLY** (no JCLW)
- `/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/` = **JCLW standalone**

**JCLW version history:**
- 2.45.1 (last combined version)
- 3.0.0, 3.1.0, 3.2.0, 3.3.0, 3.4.0, 3.5.0... (standalone versions)
- **There is NO JCLW 3.11.0** (that's JCMB only!)

---

### **What v2.5 Did Wrong:**

**System State:**
```
/Applications/Self Service+.app/.../Jamf Connect.app/ → JCMB 3.11.0
/Applications/Jamf Connect.app/ → 3.11.0 (leftover JCMB)
/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/ → JCLW 2.45.1
```

**v2.5 Output (WRONG):**
```
JCMB SSP 3.11.0 (Active)
JCLW Classic 2.45.1 (Inactive) (also found JCLW Stand-alone 3.11.0 - Inactive)
                                                    ^^^^^^^^^^^^^^^^^^^^^ BUG!
```

**Problem:** Reported 3.11.0 as JCLW, but JCLW never had a 3.11.0 version!

The 3.11.0 at `/Applications/Jamf Connect.app/` is **JCMB**, not JCLW.

---

## ✅ What v2.6 Does Correctly

### **New Logic in `evaluate_jclw()`:**

```bash
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
```

**Now:**
- ✅ Legacy path used for JCLW **only if** version ≤ 2.45.1
- ✅ Legacy path ignored for JCLW if version > 2.45.1 (it's JCMB only)
- ✅ Accurate detection of actual JCLW installations

---

### **v2.6 Output (CORRECT):**

**Same System State:**
```
/Applications/Self Service+.app/.../Jamf Connect.app/ → JCMB 3.11.0
/Applications/Jamf Connect.app/ → 3.11.0 (leftover JCMB)
/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/ → JCLW 2.45.1
```

**v2.6 Output:**
```
JCMB SSP 3.11.0 (Active) (also found JCMB Classic 3.11.0 - Inactive)
JCLW Classic 2.45.1 (Inactive)
```

**Perfect!** 
- 3.11.0 now correctly appears under JCMB (not JCLW)
- JCLW only shows actual JCLW version (2.45.1)
- Multi-version alert correctly identifies it as JCMB

---

## 📊 Test Scenarios

### **Scenario 1: Pure Legacy (2.45.1)**

**System:**
```
/Applications/Jamf Connect.app/ → 2.45.1
/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/ → 2.45.1
```

**v2.6 Output:**
```
JCMB Classic 2.45.1 (Active/Inactive)
JCLW Classic 2.45.1 (Active/Inactive)
```

**Correct:** Both use legacy path because version ≤ 2.45.1 ✓

---

### **Scenario 2: SSP with Old JCLW**

**System:**
```
/Applications/Self Service+.app/.../Jamf Connect.app/ → JCMB 3.11.0
/Applications/Jamf Connect.app/ → 3.11.0 (leftover)
/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/ → JCLW 2.45.1
```

**v2.6 Output:**
```
JCMB SSP 3.11.0 (Active) (also found JCMB Classic 3.11.0 - Inactive)
JCLW Classic 2.45.1 (Inactive)
```

**Correct:** 
- JCMB shows both versions (SSP + legacy leftover) ✓
- JCLW only shows bundle version (ignores 3.11.0 legacy) ✓

---

### **Scenario 3: SSP with Modern JCLW**

**System:**
```
/Applications/Self Service+.app/.../Jamf Connect.app/ → JCMB 3.11.0
/Applications/Jamf Connect.app/ → 3.11.0 (leftover)
/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/ → JCLW 3.5.0
```

**v2.6 Output:**
```
JCMB SSP 3.11.0 (Active) (also found JCMB Classic 3.11.0 - Inactive)
JCLW Stand-alone 3.5.0 (Active)
```

**Correct:**
- JCMB shows multi-version ✓
- JCLW only shows modern standalone version ✓
- No false "also found" for JCLW ✓

---

### **Scenario 4: Complete Modern Stack**

**System:**
```
/Applications/Self Service+.app/.../Jamf Connect.app/ → JCMB 3.11.0
/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle/ → JCLW 3.5.0
(No legacy leftovers)
```

**v2.6 Output:**
```
JCMB SSP 3.11.0 (Active)
JCLW Stand-alone 3.5.0 (Active)
```

**Perfect:** Clean modern deployment, no multi-version alerts ✓

---

## 🎯 Impact

### **What This Fixes:**

1. **Accurate JCLW Detection**
   - No more false JCLW versions reported
   - Only actual JCLW installations shown
   - Correct version numbers

2. **Accurate JCMB Multi-Version Detection**
   - Legacy JCMB properly identified as JCMB (not JCLW)
   - Cleanup candidates correctly categorized
   - "also found" annotations accurate

3. **Smart Group Accuracy**
   - JCLW Smart Groups now accurate
   - No false positives for JCLW versions
   - Reliable deployment tracking

### **Who This Affects:**

**If you have SSP + old JCLW:**
- v2.5: Incorrectly showed false JCLW version
- v2.6: Correctly shows only actual JCLW

**If you have pure legacy (2.45.1):**
- No change (both versions work correctly)

**If you have complete modern stack:**
- No change (both versions work correctly)

---

## 🔄 Migration from v2.5 to v2.6

### **Breaking Changes:**
- None for functionality
- Output format unchanged

### **Output Changes:**

**Systems with SSP + legacy JCMB leftover:**

**Before (v2.5):**
```
JCLW Classic 2.45.1 (also found JCLW Stand-alone 3.11.0)
```

**After (v2.6):**
```
JCMB SSP 3.11.0 (also found JCMB Classic 3.11.0)
JCLW Classic 2.45.1
```

The false JCLW version disappears, appears correctly under JCMB.

### **Smart Groups:**

**May need updating:**
- Any Smart Groups filtering on false JCLW versions (3.6+, 3.7+, etc.)
- These were always inaccurate, v2.6 fixes them

**No changes needed:**
- Smart Groups based on JCMB versions
- Smart Groups based on actual JCLW versions (2.45.1, 3.0-3.5)
- Active/Inactive status filtering

---

## 📋 Upgrade Steps

1. **Replace EA script** with v2.6
2. **Force inventory** on test machines
3. **Verify output** is now accurate
4. **Review Smart Groups** for any using false JCLW versions
5. **Deploy to production**

---

## ✅ Code Changes

### **Modified Function: `evaluate_jclw()`**

**Added version check before using legacy path:**

```bash
# OLD (v2.5):
if [ -f "$LEGACY_JC_PLIST" ]; then
  legacy_ver="$(get_ver "$LEGACY_JC_PLIST")"  # Used regardless of version
fi

# NEW (v2.6):
if [ -f "$LEGACY_JC_PLIST" ]; then
  temp_ver="$(get_ver "$LEGACY_JC_PLIST")"
  
  # Only use as JCLW source if version ≤ 2.45.1
  if [ -n "$temp_ver" ] && ! version_gt "$temp_ver" "$THRESHOLD"; then
    legacy_ver="$temp_ver"
  fi
  # If version > 2.45.1, ignore for JCLW (it's JCMB only)
fi
```

**Result:** Legacy path only used for JCLW if version ≤ 2.45.1

---

## 🧪 Testing Performed

**Validated against known JCLW versions:**
- 2.45.1 (last combined) ✓
- 3.0.0, 3.1.0, 3.2.0, 3.3.0, 3.4.0, 3.5.0 (standalone) ✓
- Confirmed no JCLW 3.6+, 3.7+, 3.11.0 exists ✓

**Tested on multiple system states:**
- Pure legacy 2.45.1 ✓
- SSP + old JCLW ✓
- SSP + modern JCLW ✓
- Complete modern stack ✓

---

## 🎯 Summary

**v2.6.0 fixes a critical bug** where JCMB versions were incorrectly reported as JCLW versions when found in the legacy `/Applications/Jamf Connect.app/` path.

**The fix:** Only use legacy path for JCLW detection if version ≤ 2.45.1, because post-3.0 that path contains JCMB only.

**Impact:** Accurate JCLW detection, correct multi-version alerts, reliable Smart Groups.

**Recommended:** All v2.5 users should upgrade to v2.6 immediately.

---

## Version History

**v2.6.0** - Fixed JCLW false detection from legacy JCMB path
**v2.5.0** - Added JCMB active status detection
**v2.4.0** - Enhanced JCLW active detection (checks authdb path)
**v2.3.0** - Granular feature toggles, consolidated config
**v2.2.0** - Added JCLW active/inactive status
**v2.1.0** - SSP version inline with JCMB
**v2.0.0** - Added SSP version detection
**v1.10.1** - Fixed XML result tags
**v1.0.0** - Initial combined EA
