# CI/CD & Firebase — the build and deploy pipeline

**Audit snapshot: 2026-08-10**, against `.github/workflows/build.yml` (428 lines, single workflow),
`build/build.bat`, `build/setup.iss`, and `game/export_presets.cfg` at `527eef6` on `main`.

This is the operational manual for how American Tycoon gets from a commit to your phone. It covers
what secrets the pipeline needs, exactly what fires when, how Firebase is wired, and how a local
build differs from a runner build — plus an audit section listing what is missing or fragile.

**Short version:** one workflow, four jobs, one Firebase product (App Distribution — **Hosting is not
used at all**), two build paths (local `build.bat`, CI `build.yml`) that do *not* produce identical
artifacts.

---

## Contents

1. [Required GitHub Secrets & Service Accounts](#1-required-github-secrets--service-accounts)
2. [Build Triggers — What Fires When](#2-build-triggers--what-fires-when)
3. [Firebase Configuration](#3-firebase-configuration)
4. [Local vs. GitHub Runner Builds](#4-local-vs-github-runner-builds)
5. [CLI Command Reference](#4a-cli-command-reference)
6. [Audit Findings](#5-audit-findings)

---

## 1. Required GitHub Secrets & Service Accounts

Set at **Settings → Secrets and variables → Actions** on `TimGoergen/american-tycoon`.

| Secret | Purpose | Missing → |
| :--- | :--- | :--- |
| `ANDROID_KEYSTORE_BASE64` | Base64 of `android_release.keystore`. Decoded to `build/android_release.keystore` on the runner | **Hard fail** — the "Verify keystore" step exits 1 |
| `ANDROID_KEYSTORE_PASS` | Store *and* key password (one value serves both) | **Hard fail** — same verify step catches the un-injected password |
| `FIREBASE_APP_ID` | Firebase Android App ID, `1:123456789:android:abcdef` | **Soft skip** — the `firebase-deploy` job detects the empty value and exits cleanly. The rest of the pipeline still runs |
| `FIREBASE_SERVICE_ACCOUNT_KEY` | Full JSON of a service account key with the **Firebase App Distribution Admin** role | Upload step fails *if* `FIREBASE_APP_ID` is set |

### The service account

- **Role required:** Firebase App Distribution Admin.
- **Where it comes from:** Google Cloud IAM → Service Accounts, in the Firebase project. The pipeline
  comments note this account is **shared with the Critter Quitters pipeline** — the same JSON was
  reused rather than minting a second one.
- **How it is consumed:** passed whole as `serviceCredentialsFileContent` to
  `wzieba/Firebase-Distribution-Github-Action@v1`. Nothing is written to the repo, and no
  `firebase.json`, `.firebaserc`, or `google-services.json` exists anywhere in the tree — the
  action needs only the app ID and the credentials blob.

### The keystore — the one irreplaceable asset

`build/keystore_info.txt` (gitignored) records the alias and password; the keystore itself lives at
`build/android_release.keystore` and is **also gitignored**, so *the repository is not a backup*.

> **If the keystore is lost, every installed device refuses all future updates.** There is no
> recovery — a new key means a new package identity. Both the keystore and its password note must
> live somewhere durable (password manager / cloud), and that file says so itself.

Signing identity, for reference: alias `american_tycoon`, package `com.timgoergen.americantycoon`.

### Token permissions

Only the `release` job declares permissions (`contents: write`, needed to create releases and upload
assets). The other three jobs run on the repository default. See
[Finding 8](#finding-8--no-workflow-level-permissions-floor-low).

---

## 2. Build Triggers — What Fires When

### 2.1 Trigger conditions

```yaml
on:
  push:
    branches: [main, 'feature/**']
  workflow_dispatch:
```

**Nothing else builds.** A push to any other branch name — `shelved/credit-and-class`, a bare
`experiment` branch, a tag — produces no build at all. Pull requests do not trigger it either.
`workflow_dispatch` allows a manual run against any branch you pick in the Actions UI.

### 2.2 Job graph

```
   push to main or feature/**
              │
              ▼
      ┌───────────────┐
      │  export       │  ubuntu-latest · Windows + Android exports, APK signed
      └───┬───────┬───┘
          │       │
   main   │       │  every branch
   only   ▼       ▼
 ┌──────────────┐ ┌──────────────────┐
 │ windows-     │ │ firebase-deploy  │  → APK to the Pixel
 │ installer    │ │                  │
 └──────┬───────┘ └──────────────────┘
        │
        ▼  main only
 ┌──────────────┐
 │  release     │  → tagged GitHub pre-release
 └──────────────┘
```

| Branch | `export` | `firebase-deploy` | `windows-installer` | `release` |
| :--- | :---: | :---: | :---: | :---: |
| `feature/**` | ✅ | ✅ | — | — |
| `main` | ✅ | ✅ | ✅ | ✅ |

`windows-installer` and `release` are gated by `if: github.ref == 'refs/heads/main'`.
`firebase-deploy` has **no branch condition** — shipping work-in-progress to the phone without
merging is the entire point of the feature-branch path.

### 2.3 Job 1 — `export` (ubuntu-latest), step by step

Linux cross-exports to both targets, so no Windows runner is involved in the export itself.

1. **Checkout** (`actions/checkout@v4`).
2. **Compute version stamp** — `sha` = first 7 of `GITHUB_SHA`; `build_num` = `GITHUB_RUN_NUMBER`
   zero-padded to 4; plus `branch` and the commit subject `msg`. All four become job outputs.
3. **Set up Java 17** (temurin) — required because APK signing calls `apksigner`/`jarsigner`.
4. **Restore cache** — key `godot-4.5.1-stable-v1`, covering `~/.local/godot-ci/` and
   `~/.local/share/godot/export_templates/`. **Changing `GODOT_VERSION` requires clearing the Actions
   cache**, or bumping the `-v1` suffix.
5. **Download Godot** (cache miss only) — the **standard, non-Mono** Linux headless binary. The Mono
   build blocks Android export with "C#/.NET is experimental"; the game is pure GDScript, so the
   standard binary exports identically and dodges the check.
6. **Download export templates** (cache miss only) — the `.tpz` is a renamed zip; contents are copied
   into `~/.local/share/godot/export_templates/4.5.1.stable/`. **That directory name must match the
   version string exactly** or Godot will not find the templates.
7. **Decode the keystore** — base64 → `build/android_release.keystore`, via Python. The decoder
   strips a BOM and any whitespace, because PowerShell's base64 encoding adds one.
8. **Inject the keystore password** into `game/export_presets.cfg`, replacing the empty
   `keystore/release_password=""`. Done in Python, not shell, to survive special characters.
9. **Stamp the build version** — three values written together:
   - `version/code` = `GITHUB_RUN_NUMBER` (plain integer; Android requires monotonic increase)
   - `version/name` = `0.0.0.NNNN`
   - `game/project.godot`'s `config/version` = the same string, so the in-game About screen matches
     what Firebase shows.
10. **Verify keystore and SDK** — greps for the un-injected password and **exits 1** if found; prints
    keystore presence, build-tools list, `JAVA_HOME`.
11. **Configure Godot editor settings** — writes `~/.config/godot/editor_settings-4.5.tres` with the
    Android SDK path, Java SDK path, and **three deliberately blank debug-keystore fields**. That
    blankness is a workaround for [Godot issue #109551](https://github.com/godotengine/godot/issues/109551):
    the debug-keystore validator runs even with `package/signed=false` and fails with a *blank* error
    if some of the three fields are set and others are not. Setting all three to `""` satisfies the
    "none of them" branch.
12. **Export Windows** — `--headless --export-release "Windows Desktop" "../dist/american_tycoon_win.exe"`.
13. **Export Android, then sign manually** — the most workaround-dense step in the pipeline:
    - `rm -f ~/.android/debug.keystore` — the runner auto-generates one, Godot detects it and then
      fails blankly (same issue #109551). Removing it forces the empty-path branch.
    - Flip `package/signed=true` → `false` so Godot's own signing-config check is bypassed entirely.
    - Export to `american_tycoon_raw.apk`, piping through `tee` so output appears live *and* is saved;
      on failure the log is re-dumped with `cat -A` to make ANSI-only blank errors visible.
    - Strip non-printable characters from the password (`tr -cd '[:print:]'`) — GitHub secrets can
      pick up a BOM from copy-paste, and Java's PKCS12 rejects it with "Password is not ASCII".
    - Sign with `apksigner` from the newest build-tools → `american_tycoon.apk`; delete the raw APK.
14. **Stamp version into filenames** — `american_tycoon_<sha>_win.exe`, `american_tycoon_<sha>.apk`.
15. **Upload artifacts** — `windows-exe` **only on `main`** (7-day retention; nothing downloads it on
    feature branches and it costs ~44MB a push), `android-apk` always (14-day retention, deliberately
    longer so a failed Firebase upload can be re-distributed by hand).

### 2.4 Job 2 — `windows-installer` (windows-latest, `main` only)

Checks out the repo (it needs `build/setup.iss`), downloads the `windows-exe` artifact, and runs
**Inno Setup 6** — pre-installed on GitHub Windows runners — via `ISCC.exe` with four `/D` defines:
`AppVersion=0.0.0.NNNN`, `SourceExe`, `OutputDir` (absolute, because ISCC resolves relative paths
against the `.iss` file's own directory), and `OutputFilename`.

The installer itself: `PrivilegesRequired=lowest` (installs to the user's Programs folder, no admin
prompt), LZMA solid compression, optional desktop icon, launch-on-finish. It ships a **single
self-contained exe** because the export preset sets `binary_format/embed_pck=true`. `AppId` is a
fixed GUID — **never change it**, it is what Windows uses to track upgrades and uninstalls.

### 2.5 Job 3 — `release` (ubuntu-latest, `main` only)

Needs both `export` and `windows-installer`. Downloads every artifact and publishes a GitHub
**pre-release** via `softprops/action-gh-release@v2`:

- Tag: `build-<sha>` · Name: `Build <sha>` · `prerelease: true`
- Assets: the installer `.exe` and the signed `.apk`
- Body: install instructions for both platforms

### 2.6 Job 4 — `firebase-deploy` (ubuntu-latest, every branch)

1. **Check Firebase configured** — sets `configured=true/false` from whether `FIREBASE_APP_ID` is
   non-empty. This exists because **GitHub Actions cannot read secrets in a job-level `if:`** — they
   are evaluated before secrets are injected. Every subsequent step is conditioned on that output
   instead, so the job exits green when Firebase is not set up.
2. **Download the `android-apk` artifact.**
3. **Resolve the APK path** — the action takes a concrete path, not a glob.
4. **Upload** via `wzieba/Firebase-Distribution-Github-Action@v1` to group `testers`, with release
   notes `[<branch>] <sha>: <commit subject>`.

---

## 3. Firebase Configuration

### 3.1 Hosting — not used

**There is no Firebase Hosting configuration in this project.** No `firebase.json`, no `.firebaserc`,
no `public/` directory, no hosting deploy step, no web export preset. The game exports to Windows and
Android only, so there is nothing to host. If web hosting is ever wanted it is net-new work: a Web
export preset, a hosting config, and a fifth job.

### 3.2 App Distribution — the only Firebase product in use

| Setting | Value |
| :--- | :--- |
| Product | Firebase App Distribution |
| Android package | `com.timgoergen.americantycoon` |
| Tester group | `testers` |
| Tester | `goergen.tim@gmail.com` |
| Uploader | `wzieba/Firebase-Distribution-Github-Action@v1` |
| Auth | Service account JSON (App Distribution Admin), passed as file content |
| Runs on | Every push to `main` and `feature/**` |

**One-time setup** (recorded in the workflow header, reproduced here so it survives a workflow
rewrite):

1. Register the Android app in the Firebase console with package name
   `com.timgoergen.americantycoon`.
2. Enable App Distribution.
3. Add `goergen.tim@gmail.com` as a tester in a group named **`testers`** — the group name is
   hardcoded in the workflow; renaming it in the console silently breaks distribution.
4. Accept the tester invitation on the Pixel via the **Firebase App Tester** app.
5. Reuse the existing service account JSON (App Distribution Admin) or mint one in IAM.
6. Add `FIREBASE_APP_ID` and `FIREBASE_SERVICE_ACCOUNT_KEY` as GitHub secrets.

### 3.3 What a tester sees

The Pixel gets an install/update notification per push. Release notes carry branch, short SHA, and
commit subject, so a feature-branch build is identifiable on the device without opening the console.
The `versionName` shown is `0.0.0.NNNN` — the same string the in-game About screen displays, which is
the whole reason step 9 rewrites `project.godot` too.

---

## 4. Local vs. GitHub Runner Builds

Both paths exist and **they do not produce equivalent artifacts.** Use CI for anything that reaches
the phone; use local for a fast Windows check.

| | Local (`build/build.bat`) | CI (`build.yml`) |
| :--- | :--- | :--- |
| Godot | `godot` **on PATH** | Downloaded Linux headless binary, cached |
| Host OS | Windows | ubuntu-latest (+ windows-latest for the installer) |
| Version string | `0.0.<short-sha>` | `0.0.0.NNNN` from the run number |
| `version/code` | **Not stamped — stays `1`** | `GITHUB_RUN_NUMBER` |
| `project.godot` `config/version` | **Not stamped** — About screen shows `0.0.0.0001` | Rewritten to match |
| APK signing | Godot's built-in signing | Godot signing **disabled**; manual `apksigner` |
| Keystore password | **You edit `export_presets.cfg` by hand** | Injected from a secret, verified |
| Windows installer | ✅ local Inno Setup 6 | ✅ on a Windows runner |
| Firebase upload | ❌ | ✅ |
| GitHub release | ❌ | ✅ on `main` |
| Verification gates | Manual `pwsh tools\run_gates.ps1` | ❌ **none** — see [Finding 1](#finding-1--no-verification-gates-run-in-ci-high) |

### 4.1 Running a local build

Prerequisites: Godot 4.5.1 reachable as `godot` on PATH, Inno Setup 6 at the default location, and
`build/android_release.keystore` present.

```
build\build.bat          # run from the repository root
```

Three steps: Windows export → Inno Setup installer → Android APK (skipped with a warning if the
keystore is absent). Output lands in `dist/`.

> ⚠️ **The local Android path needs the password written into `game/export_presets.cfg`.** Protect
> against committing it:
> ```
> git update-index --skip-worktree game\export_presets.cfg
> ```
> Remember you did this — a `skip-worktree` file silently ignores later legitimate changes to the
> preset, which is its own trap.

> ⚠️ **A locally-built APK will usually refuse to install over a CI build.** Local builds leave
> `version/code` at `1`; a device carrying CI build code 120 treats the local APK as a downgrade and
> Android blocks it. Uninstall first, or stamp the code by hand.

**Note the PATH inconsistency:** `build.bat` expects `godot` on PATH, while every other workflow in
this project (parse checks, sims, `run_gates.ps1`) invokes the absolute
`D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe`, because Godot is
deliberately *not* on PATH here. As written, `build.bat` does not run on this machine without either
adding Godot to PATH or editing the `set GODOT=` line.

### 4.2 Running an export by hand

The same two commands CI uses, from the `game/` directory:

```
<godot> --headless --export-release "Windows Desktop" "../dist/american_tycoon_win.exe"
<godot> --headless --export-release "Android"         "../dist/american_tycoon.apk"
```

### 4.3 Triggering a CI build without a code change

Actions → **Build & Deploy** → **Run workflow**, pick the branch. Useful when a Firebase upload
failed on an otherwise good commit. Note that a re-run reuses `GITHUB_RUN_NUMBER`, so the rebuilt APK
carries the same `versionCode` — and on `main` it will attempt the same `build-<sha>` release tag
([Finding 4](#finding-4--re-running-a-main-build-collides-with-its-own-release-tag-low)).

---

## 4A. CLI Command Reference

The pipeline itself uses a GitHub Action rather than the Firebase CLI, so none of these are required
for normal operation. They are what you need to **set the pipeline up, rotate a secret, or
distribute a build by hand when CI is unavailable.**

### 4A.1 Firebase CLI — manual distribution

```powershell
npm install -g firebase-tools          # one-time install
firebase login                         # interactive; opens a browser
firebase projects:list                 # confirm which project you are in
firebase apps:list ANDROID             # ← this prints the FIREBASE_APP_ID secret value
```

Distribute an APK without CI:

```powershell
firebase appdistribution:distribute "dist\american_tycoon_abc1234.apk" `
  --app "1:123456789:android:abcdef" `
  --groups "testers" `
  --release-notes "manual build from feature/my-branch"
```

Using a service account instead of interactive login (what CI does, in effect):

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"
firebase appdistribution:distribute "dist\american_tycoon.apk" --app "<APP_ID>" --groups "testers"
```

Tester management:

```powershell
firebase appdistribution:testers:add    goergen.tim@gmail.com --group-alias testers
firebase appdistribution:testers:list
```

> **Firebase Hosting commands do not apply here** — `firebase init hosting` / `firebase deploy` would
> be net-new setup. There is no hosting config in this project ([§3.1](#31-hosting--not-used)).

### 4A.2 gcloud — the service account

```powershell
gcloud auth login
gcloud config set project <firebase-project-id>

gcloud iam service-accounts list

gcloud iam service-accounts create at-app-distribution `
  --display-name "American Tycoon App Distribution"

gcloud projects add-iam-policy-binding <firebase-project-id> `
  --member "serviceAccount:at-app-distribution@<project>.iam.gserviceaccount.com" `
  --role "roles/firebaseappdistro.admin"

# Generate the key whose full contents become FIREBASE_SERVICE_ACCOUNT_KEY
gcloud iam service-accounts keys create service-account.json `
  --iam-account "at-app-distribution@<project>.iam.gserviceaccount.com"
```

Delete the local `service-account.json` once it is pasted into the GitHub secret — it is a
credential, and the secret store is the durable copy.

### 4A.3 Keystore — creation, inspection, rotation

The keystore already exists; these are for inspection and disaster recovery.

```powershell
# Inspect the existing keystore (prompts for the password)
keytool -list -v -keystore build\android_release.keystore

# Create one from scratch — ONLY for a new project. Never regenerate this project's key:
# a new key means installed devices refuse every future update.
keytool -genkey -v -keystore android_release.keystore `
  -alias american_tycoon -keyalg RSA -keysize 2048 -validity 10000
```

### 4A.4 Encoding secrets for GitHub

`ANDROID_KEYSTORE_BASE64` is the keystore, base64-encoded:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("build\android_release.keystore")) |
  Set-Content -Encoding ascii keystore_b64.txt
```

Paste the file's contents as the secret value, then delete the file. **`-Encoding ascii` matters** —
the workflow's decoder strips a BOM specifically because PowerShell has added one before, and the
password path strips non-printables for the same reason.

### 4A.5 APK inspection and manual signing

```powershell
$BT = "$env:LOCALAPPDATA\Android\Sdk\build-tools\34.0.0"

& "$BT\apksigner.exe" verify --verbose dist\american_tycoon.apk
& "$BT\zipalign.exe" -c -v 4 dist\american_tycoon.apk     # -c checks, changes nothing

& "$BT\apksigner.exe" sign `
  --ks build\android_release.keystore `
  --ks-key-alias american_tycoon `
  --out dist\american_tycoon.apk `
  dist\american_tycoon_raw.apk

adb install -r dist\american_tycoon.apk      # sideload to a connected Pixel
```

### 4A.6 gh CLI — watching and managing runs

```powershell
$GH = "C:\Program Files\GitHub CLI\gh.exe"

& $GH run list --limit 10
& $GH run watch                                  # live progress of the current run
& $GH run view --log-failed                      # just the failing steps
& $GH run rerun <run-id>
& $GH workflow run "Build & Deploy" --ref feature/my-branch   # manual workflow_dispatch

& $GH secret list                                # names only; values are never readable
& $GH secret set FIREBASE_APP_ID                 # prompts for the value
& $GH release list
```

---

## 5. Audit Findings

Ordered by what would hurt most. Nothing here is currently *broken* — the pipeline works and ships —
but each is a real gap between what the pipeline does and what it appears to guarantee.

### Finding 1 — No verification gates run in CI (HIGH)

`tools/run_gates.ps1` and the 12 verification gates **never execute in the pipeline.** Nothing checks
that the project even *parses* before an APK is built, signed, and pushed to the phone. A commit that
breaks `MoneyTest` or `EpochTest` distributes exactly as cleanly as one that passes.

This makes the gate discipline entirely dependent on remembering to run it locally — which is the
same failure mode that produced the 2026-08-10 incident (9 of 12 gates run, two never run at all)
that `run_gates.ps1` was written to prevent. The runner exists; CI just doesn't call it.

**Fix is small.** `pwsh` is present on `ubuntu-latest`, and the runner already takes a `-Godot`
override, so a gate job needs no new tooling:

```yaml
  gates:
    name: Verification gates
    runs-on: ubuntu-latest
    steps:
      # ... checkout + the same cache/download steps the export job uses ...
      - name: Run gates
        run: pwsh tools/run_gates.ps1 -Godot "$HOME/.local/godot-ci/Godot_v4.5.1-stable_linux.x86_64"
```

Then add `needs: gates` to `export`. Two caveats: `PortraitSheet` must stay excluded (it needs a real
renderer, and the default sweep already excludes it), and the gates may need an editor import pass
first for the global class cache. Worth confirming on a feature branch before wiring it into `main`.

*Same gap exists in the Critter Quitters pipeline this was cloned from — it was inherited, not
introduced here.*

### Finding 2 — Commit subject is interpolated into an action input (MODERATE)

`msg` is captured with `git log -1 --format='%s'` and reaches Firebase as:

```yaml
releaseNotes: "[${{ ... branch }}] ${{ ... sha }}: ${{ ... msg }}"
```

`${{ }}` interpolation happens *before* YAML parsing, so a commit subject containing a double quote
truncates or breaks the input, and one containing shell metacharacters is untrusted text landing in a
templated field. Only you commit here, so this is a robustness issue rather than a live security
hole — but it is the textbook GitHub Actions script-injection shape and a stray `"` in a commit
message is enough to fail the deploy.

**Fix:** pass it via an environment variable instead of direct interpolation —
`env: MSG: ${{ needs.export.outputs.msg }}` and reference `$MSG` — so the value is never spliced into
the YAML or a shell command.

### Finding 3 — The signed APK is never verified, and alignment is unconfirmed (MODERATE)

The pipeline disables Godot's signing and calls `apksigner sign` directly, then ships the result with
**no `apksigner verify` step**. If signing silently produced something unusable, the first sign of it
would be an install failure on the Pixel.

Related and worth actually checking: `apksigner` normally expects the APK to be **zipaligned before
signing**, and because Godot's own packaging path is bypassed here, it is not obvious from the
workflow whether alignment happened. Firebase App Distribution does not enforce it (Play Store
would), so an unaligned APK would install fine and only cost runtime memory — which is exactly why
this could sit unnoticed.

**Fix:** add after signing —

```bash
"$ANDROID_HOME/build-tools/$BUILD_TOOLS/apksigner" verify --verbose ../dist/american_tycoon.apk
"$ANDROID_HOME/build-tools/$BUILD_TOOLS/zipalign" -c -v 4 ../dist/american_tycoon.apk || echo "NOT ALIGNED"
```

The `zipalign -c` is a check, not a change — it answers the open question without altering behavior.

### Finding 4 — Re-running a `main` build collides with its own release tag (LOW)

The release tag is `build-<short-sha>`. Re-running a `main` workflow on the same commit attempts to
create a tag that already exists; `softprops/action-gh-release@v2` will either fail or overwrite,
neither of which is stated anywhere. Adding the run number (`build-<sha>-<run>`) or setting an
explicit overwrite policy would make the behavior intentional.

### Finding 5 — No `concurrency` group (LOW)

Two pushes in quick succession run the full pipeline twice in parallel, including two Firebase
uploads. The phone gets two notifications and the later-finishing build may not be the newer commit.

**Fix:**
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

### Finding 6 — Local builds are not version-stamped (LOW, but bites)

`build.bat` sets `VERSION=0.0.<sha>` for the Inno installer and stamps **nothing** into the Android
preset or `project.godot`. Consequences: local APKs all carry `versionCode 1` and will not install
over a CI build; the About screen reports `0.0.0.0001` regardless; and the local installer's version
format (`0.0.527eef6`) does not match CI's (`0.0.0.0042`), so the two cannot be ordered against each
other in Windows' installed-programs list.

### Finding 7 — The keystore password sits in plaintext at rest (LOW / accepted)

`build/keystore_info.txt` holds the store and key password in the clear. It is gitignored and the
file itself warns to back it up — this is a deliberate trade for a hobby project, recorded here so it
is a known accepted risk rather than an oversight. The more pressing half is the **backup**
obligation: the keystore is gitignored too, so the repo is not a copy, and losing it permanently ends
your ability to update installed devices.

### Finding 8 — No workflow-level `permissions` floor (LOW)

Only `release` declares permissions. Adding a top-level `permissions: contents: read` would make the
other three jobs least-privilege by default, with `release` keeping its `contents: write` override.

### Finding 9 — No `timeout-minutes` on any job (LOW)

A hung export (or a wget stalling against a GitHub release URL) burns the full 6-hour default before
being killed. `timeout-minutes: 30` on `export` is ample.

### What the audit found healthy

Worth stating, because much of this pipeline is more careful than average:

- **Fail-fast on the keystore.** The verify step greps for the un-injected password and exits 1 —
  an unsigned or misconfigured build cannot proceed silently.
- **Secrets handled properly.** Passed via `env:` into Python rather than inline shell expansion,
  avoiding escaping bugs; BOM and non-printable stripping on both the base64 and the password address
  real failures that were actually hit.
- **The Firebase soft-skip is correct engineering.** The workaround for "secrets are unavailable in
  job-level `if:`" is implemented properly and documented inline with the reason.
- **Every workaround carries its justification**, including a linked Godot issue number. That is why
  this audit could distinguish a workaround from a mistake at all.
- **Artifact retention is deliberate** — 7 days for build intermediates, 14 for the APK, with the
  reasoning written down; and the Windows exe is skipped entirely on feature branches.
- **Version stamping keeps three values in sync** (`version/code`, `version/name`,
  `project.godot`'s `config/version`), so the About screen cannot lie about which build is installed.
