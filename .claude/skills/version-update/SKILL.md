---
name: version-update
description: >
  Updates the version in package.json and prepends a new entry in CHANGELOG.md.
  Determines bump type (major/minor/patch) from the new version automatically.
  Can be used standalone or called from other skills like minor-version-pr.
parameters:
  - name: "new_version"
    description: "The new version to set. E.g. '4.10.0'. Bump type is derived automatically."
  - name: "changelog_entries"
    description: "One or more changelog lines to add under the new version. Each entry should be a plain string without the leading dash."
  - name: "native_sdk_version"
    description: "New MoEngage-iOS-SDK version to mention in changelog. Optional — if provided, adds 'Updated MoEngage-iOS-SDK to X' entry automatically."
    optional: true
  - name: "pluginbase_version"
    description: "New MoEngagePluginBase version to mention in changelog. Optional — if provided, adds 'Updated MoEngagePluginBase to X' entry and updates pluginbaseVerMin in package.json."
    optional: true
---

# Version Update

Updates `package.json` and `CHANGELOG.md` to reflect a new release version.

---

## Step 1 — Read current version

Read `package.json` and extract:
- **`currentVersion`** — value of `packages[0].version` (e.g. `4.9.0`)
- **`currentSdkVerMin`** — value of `sdkVerMin` (e.g. `10.12.0`)
- **`currentPluginbaseVerMin`** — value of `pluginbaseVerMin` (e.g. `6.9.0`)

---

## Step 2 — Determine bump types

**Plugin bump type** — compare `new_version` against `currentVersion` using semver `MAJOR.MINOR.PATCH`:

| What changed          | Bump type |
| --------------------- | --------- |
| MAJOR digit increased | `major`   |
| MINOR digit increased | `minor`   |
| PATCH digit increased | `patch`   |

**SDK bump type** (only when `native_sdk_version` provided) — compare `native_sdk_version` against `currentSdkVerMin` using the same rule. This prefix is used in the SDK CHANGELOG line.

**PluginBase bump type** (only when `pluginbase_version` provided) — compare `pluginbase_version` against `currentPluginbaseVerMin` using the same rule. This prefix is used in the PluginBase CHANGELOG line.

---

## Step 3 — Update package.json

In `package.json`:
- Set `packages[0].version` → `<new_version>`
- If `native_sdk_version` was provided → set `sdkVerMin` → `<native_sdk_version>`
- If `pluginbase_version` was provided → set `pluginbaseVerMin` → `<pluginbase_version>`

---

## Step 4 — Prepend CHANGELOG entry

Read `CHANGELOG.md` and check whether `# Release Date` already exists at the top.

**If `# Release Date` / `## Release Version` block already exists at the top:**
Append the new entries to the end of that existing block (do not add a new header):

```
# Release Date

## Release Version

- <existing entries>
- <changelog_entries line 1>        ← append here
- [<sdk_bump_type>] Updated MoEngage-iOS-SDK to <native_sdk_version>      ← append here if provided
- [<pluginbase_bump_type>] Updated MoEngagePluginBase to <pluginbase_version>    ← append here ONLY if pluginbase_version provided AND native_sdk_version is NOT provided
```

**If no `# Release Date` block exists at the top:**
Prepend a new block at the very top:

```
# Release Date

## Release Version

- <changelog_entries line 1>
- <changelog_entries line 2>
- [<sdk_bump_type>] Updated MoEngage-iOS-SDK to <native_sdk_version>      ← only if native_sdk_version provided
- [<pluginbase_bump_type>] Updated MoEngagePluginBase to <pluginbase_version>    ← only if pluginbase_version provided AND native_sdk_version is NOT provided
```

Format rules (from existing CHANGELOG):
- Date line: literal `# Release Date` (placeholder — replaced during release)
- Version header: literal `## Release Version` (placeholder — replaced during release)
- Each entry: `- <text>` (no ticket number; SDK/PluginBase lines use `[<bump_type>]` prefix, feature entries do not)
- **Mutual exclusion:** if `native_sdk_version` is provided, **omit the PluginBase line entirely** — do not add both. The SDK version entry already implies the PluginBase version is bundled within it.

---

## Step 5 — Print summary

```
Version:         <currentVersion> → <new_version>  (<bump type>)
sdkVerMin:       <currentSdkVerMin> → <native_sdk_version>       ← only if provided
pluginbaseVerMin: <currentPluginbaseVerMin> → <pluginbase_version> ← only if provided

CHANGELOG entry added:
# Release Date
## Release Version
<entries>
```
