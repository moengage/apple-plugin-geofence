---
name: native-feature-implementation
description: Create a minor version PR for apple-plugin-geofence based on a new native SDK API and SDK contract. Reads contracts remotely, implements the bridge method, updates CHANGELOG and version — then creates a PR.
parameters:
  - name: "ticket_id"
    description: "JIRA ticket ID, e.g. 'MOEN-44072'. Extracted from command text if not supplied."
    optional: true
  - name: "feature_description"
    description: "Natural language description of the feature. E.g. 'start geofence monitoring', 'stop geofence monitoring'."
  - name: "contract_pr_url"
    description: "GitHub PR URL in mobile-sdk-contracts that adds the feature contract. E.g. 'https://github.com/moengage/mobile-sdk-contracts/pull/12'."
  - name: "ios_native_version"
    description: "Minimum native iOS SDK version required for this feature. Updates sdkVerMin in package.json and adds a '[bump] Updated MoEngage-iOS-SDK to X' CHANGELOG entry. E.g. '10.13.0'. Optional — if not provided, sdkVerMin is not updated."
    optional: true
  - name: "pluginbase_version"
    description: "MoEngagePluginBase version required for this feature. Updates pluginbaseVerMin in package.json. E.g. '6.10.0'."
    optional: true
  - name: "native_sdk_pr_url"
    description: "GitHub PR URL in MoEngage-iPhone-SDK that adds the native API. Optional — if not provided, master branch is used."
    optional: true
---

# Minor Version PR — apple-plugin-geofence

You are implementing a minor version change in `apple-plugin-geofence` that bridges a new native
iOS SDK API to hybrid frameworks via the geofence plugin bridge. The contract is defined in the
`mobile-sdk-contracts` repo on the provided PR.

**Key differences from iOS-PluginBase:**
- Single source file: `Sources/MoEngagePluginGeofence/MoEngagePluginGeofenceBridge.swift`
- No separate Constants/Utils/Parser files — all logic lives in the bridge file
- Native SDK class is always `MoEngageSDKGeofence`
- `package.json` has both `sdkVerMin` and `pluginbaseVerMin`
- `identifier` is fetched via `MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: payload)` (no `if let` — returns non-optional String)

---

## Phase 0 — Clarify Inputs

### 0.1 Extract ticket ID
Scan the user's full command for `MOEN-\d+` → **`ticketId`**.
If not found in the command or parameters, ask before proceeding.

### 0.2 Confirm all required inputs are present
If either `feature_description` or `contract_pr_url` is missing, ask for them before proceeding.
`ios_native_version` is optional — do not ask for it if absent.

Derive:
- **`featureName`** — lowercase slug from `feature_description` (e.g. `startgeofencemonitoring`)
- **`prNumber`** — numeric part of `contract_pr_url` (e.g. `12`)
- **`branchName`** — `feature/<ticketId>-<featureName>` (e.g. `feature/MOEN-44072-startgeofencemonitoring`)

---

## Phase 1 — Read Contracts from PR (Hybrid ↔ GeofencePlugin boundary)

### 1.1 Fetch PR file list

```bash
gh pr view <prNumber> --repo moengage/mobile-sdk-contracts --json title,body,files,headRefName
```

From the response extract:
- **`contractBranch`** — `headRefName`
- **`contractDir`** — directory component of each changed file path (e.g. `geofence` from `json/hybridToNative/geofence/startGeofenceMonitoring.json`)
- **`hybridToNativeFiles`** — changed files under `json/hybridToNative/`
- **`nativeToHybridFiles`** — changed files under `json/nativeToHybrid/` (may be empty)

### 1.2 Read contract files and detect change type

From the PR file list, note for each file whether it was **added** (new) or **modified** (existing):

For each file in `hybridToNativeFiles`:
```
https://raw.githubusercontent.com/moengage/mobile-sdk-contracts/<contractBranch>/<path>
```
- Filename (without `.json`) = **method name**
- Content = **input payload schema**

For each file in `nativeToHybridFiles`:
```
https://raw.githubusercontent.com/moengage/mobile-sdk-contracts/<contractBranch>/<path>
```
- Content = **response payload schema**

### 1.3 Classify

First determine whether the contract file is new or modified:

| File status                | Meaning                                                           |
| -------------------------- | ----------------------------------------------------------------- |
| **New file** added         | New method — full bridge implementation needed (Phase 2 required) |
| **Existing file** modified | Payload change only — no new native API, no new bridge method     |

For **payload changes on existing files**:

| Modified file             | Implementation change                                                                                   |
| ------------------------- | ------------------------------------------------------------------------------------------------------- |
| `hybridToNative` modified | Hybrid sends additional fields → update existing bridge method to extract and pass new fields to native |
| `nativeToHybrid` modified | Native sends additional fields back → update response/event builder to include new fields               |

For payload changes, **skip Phase 2** and go directly to Phase 3.

For new files, classify and continue to Phase 2:

| New contract files                         | Classification                                  |
| ------------------------------------------ | ----------------------------------------------- |
| `hybridToNative` only                      | **Fire-and-forget** — no response expected      |
| both `hybridToNative` and `nativeToHybrid` | **Expects response** — type resolved in Phase 2 |

Print a `### Contract Summary` with method name(s), file status (new/modified), payload schema, and classification.

---

## Phase 2 — Find the Native API (GeofencePlugin ↔ Native boundary)

### 2a — Resolve source

**If `native_sdk_pr_url` was provided:**
```bash
gh pr view <prNumber> --repo moengage/MoEngage-iPhone-SDK --json title,body,files,headRefName
```
- Extract `nativeBranch` from `headRefName`
- Read each changed `.swift` file:
```
https://raw.githubusercontent.com/moengage/MoEngage-iPhone-SDK/<nativeBranch>/<path>
```

**If `native_sdk_pr_url` was NOT provided:**
Fetch `MoEngageSDKGeofence` from master:
```
https://raw.githubusercontent.com/moengage/MoEngage-iPhone-SDK/master/Sources/MoEngageGeofence/Public/MoEngageSDKGeofence.swift
```
If the method is not found, fall back to a targeted search:
```
https://api.github.com/search/code?q=<featureName>+repo:moengage/MoEngage-iPhone-SDK+language:Swift+path:Sources/MoEngageGeofence
```

### 2b — Extract from native source and finalize type

**If Phase 1 found `hybridToNative` only (no response):**
→ **Type 1** (fire-and-forget). Still read the native signature to extract parameter names and any availability guards.

**If Phase 1 found both `hybridToNative` and `nativeToHybrid` (response exists):**
Read the native method signature:

```
Native method has completionHandler / completionBlock / completion closure?
  YES → Ask the user:
        "Native API has a completion handler. How should GeofencePlugin return the response?
         1. completionBlock — result passed directly to hybrid caller (Type 2)
         2. flushMessage — result emitted as an event via message handler (Type 3)"
        Wait for user's answer before continuing.

  NO (returns Void, no closure param) → native delivers result via protocol/delegate
        → Check the delegate protocol:
              Standard MoEngagePluginBridgeDelegate / flushMessage pipeline?
                YES → Type 3 (auto-determined)
              Feature-specific listener protocol requiring a dedicated NSObject handler?
                YES → Type 4 (auto-determined)
```

Extract:
- **Full method signature** (name, parameters, return type)
- **Parameter types** — especially enums
- **Threading / availability** — `@MainActor`, `@available`, `#if os(tvOS)` guards
- **Closest existing bridge method** in `MoEngagePluginGeofenceBridge.swift` to use as template

Print a `### Native API Summary` with the finalized type and reasoning.

---

## Phase 3 — Read Current GeofencePlugin State

Read these files:

1. `Sources/MoEngagePluginGeofence/MoEngagePluginGeofenceBridge.swift`
2. `package.json` — current version, `sdkVerMin`, `pluginbaseVerMin`
3. `CHANGELOG.md` — format reference

Identify:
- Current version (e.g. `4.9.0`) → new minor version (e.g. `4.10.0`)
- Current `sdkVerMin` → will be updated to `<ios_native_version>`
- Current `pluginbaseVerMin` → will be updated to `<pluginbase_version>` if provided

---

## Phase 4 — Propose Implementation Plan

Output a numbered checklist under `### Implementation Plan`:

1. Branch: `<branchName>`
2. Files to change and exactly what to add/modify in each:
   - `MoEngagePluginGeofenceBridge.swift` — new bridge method (type determined in Phase 2)
   - `package.json` — minor version bump + `sdkVerMin` → `<ios_native_version>` + optionally `pluginbaseVerMin`
   - `CHANGELOG.md` — new entry
3. tvOS guard if native API is iOS-only

Ask: *"Does this plan look right before I implement?"* Wait for approval.

---

## Phase 5 — Implement

Once approved, implement **in this order**:

### 5a — Bridge method in MoEngagePluginGeofenceBridge.swift

Add the new `@objc public func` in the bridge file.

**Rules that apply to all types:**
- Always `@objc public` — hybrid SDKs reach this via ObjC runtime or direct Swift call
- First parameter is always `_ payload: [String: Any]`
- Fetch `identifier` via `MoEngagePluginUtils.fetchIdentifierFromPayload(attribute: payload)` — returns a non-optional `String` (no `if let` needed)
- **Always pass `identifier` to every native API call** — use whichever label the native signature requires (`forAppID:`, `for:`, `workspaceId:`)
- Add `#if os(tvOS)` guard with a descriptive log if the native API is iOS-only
- Response payload keys must exactly match the `nativeToHybrid` contract file

**Type 2 specific rules:**
- Bridge method takes a second parameter `completionHandler: @escaping ([String: Any]) -> Void`
- Build the response dict using `MoEngagePluginConstants.General.accountMeta` and `MoEngagePluginConstants.General.data` as top-level keys (same envelope as iOS-PluginBase), wrapping it with `MoEngagePluginUtils.createAccountPayload(identifier:)`
- Response data keys must exactly match the `nativeToHybrid` contract

Read the relevant example file before generating code:

| Type                        | Example file                             |
| --------------------------- | ---------------------------------------- |
| Type 1 — fire-and-forget    | `examples/Type1_FireAndForget.swift`     |
| Type 2 — completion handler | `examples/Type2_CompletionHandler.swift` |

For **Type 4**, two things must be created:
1. A new file `MoEngagePlugin<Feature>ListenerHandler.swift` alongside the bridge file
2. The bridge method in `MoEngagePluginGeofenceBridge.swift`

---

### 5b + 5c — Version bump and CHANGELOG

Invoke the `version-update` skill with:
- `new_version` = next minor version (e.g. `4.9.0` → `4.10.0`)
- `changelog_entries` = `["[minor] Added support for <feature_description>"]` — **do NOT include the ticket ID in the changelog entry**
- `native_sdk_version` = `<ios_native_version>` — **only if `ios_native_version` was provided**; omit otherwise
- `pluginbase_version` = `<pluginbase_version>` (if provided)

When `ios_native_version` is provided, the `version-update` skill will:
- Set `sdkVerMin` → `<ios_native_version>` in `package.json`
- Append `[<sdk_bump_type>] Updated MoEngage-iOS-SDK to <ios_native_version>` to the CHANGELOG entry

When `ios_native_version` is **not** provided:
- `sdkVerMin` in `package.json` is left unchanged
- No SDK version line is added to the CHANGELOG

---

## Phase 6 — Branch, Commit, Push and PR

### 6.1 — Create branch and commit

```bash
# 1. Check status
git status

# 2. Create feature branch
git checkout -b <branchName>

# 3. Stage all changes (including any new files like ListenerHandler for Type 4)
git add -A

# 4. Commit
git commit -m "<ticketId>: Added support for <feature_description>"
```

If `git checkout -b` fails because the branch already exists, stop and ask the user whether to
delete it or pick a different name.

### 6.2 — Push and create PR

```bash
# 5. Push branch
git push -u origin <branchName>

# 6. Create PR targeting development
gh pr create \
  --repo moengage/apple-plugin-geofence \
  --base development \
  --title "<ticketId>: Added support for <feature_description>" \
  --body "$(cat <<'EOF'
### Jira Ticket
https://moengagetrial.atlassian.net/browse/<ticketId>

### Description
Added support for <feature_description>

### Contract PR
<contract_pr_url>

### Native SDK
<native_sdk_pr_url or "moengage/MoEngage-iPhone-SDK @ master">

### Changes
- `MoEngagePluginGeofenceBridge.swift` — <new method / updated method: methodName, type: 1/2/3/4>
- `package.json` — version <old> → <new>, sdkVerMin <old> → <ios_native_version><, pluginbaseVerMin <old> → <pluginbase_version> if provided>
- `CHANGELOG.md` — new entry
EOF
)"
```

Print the PR URL on completion.

---

## Phase 7 — Summary

Print:

```
PR:       <pr_url>
Branch:   <branchName>
Version:  <old> → <new>
sdkVerMin: <old> → <ios_native_version>            ← omit this line if ios_native_version not provided
pluginbaseVerMin: <old> → <pluginbase_version>   ← omit this line if pluginbase_version not provided
Ticket:   <ticketId>
Contract PR: <contract_pr_url>

Files changed:
  - MoEngagePluginGeofenceBridge.swift  (<new/updated> method: <methodName>, type: <1/2/3/4>)
  - package.json                        (version bump + sdkVerMin<+ pluginbaseVerMin>)
  - CHANGELOG.md                        (new entry)

Native SDK source: <native_sdk_pr_url or "moengage/MoEngage-iPhone-SDK @ master">
```
