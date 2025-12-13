# Release Process

This document describes how to cut a new Obsi Android release using the GitHub Actions workflow and local signing.

## 1. Branching model

- **develop**
  - Integration branch for day‑to‑day development.
  - Feature branches are merged here via PR.
- **main**
  - Stable, production branch.
  - Only release‑ready code is merged here.
- **feature / bugfix branches**
  - Branch from `develop`, e.g. `feature/inbox-filters`, `bugfix/notifications`.
  - Open PRs back into `develop`.

## 2. CI behavior (overview)

Workflow: `.github/workflows/main.yml`

```yaml
on:
  push:
    branches: [ main, develop ]
    tags:
      - 'v*'
  pull_request:
    branches: [ main, develop ]
  workflow_dispatch:
```

Jobs:

- **run_tests**
  - Runs on all pushes/PRs to `main` and `develop` and on `v*` tags.
  - Steps: `flutter pub get`, `flutter test` (Flutter 3.35.1, Dart 3.9.0).

- **build_android**
  - Runs only on:
    - Branch `main`, or
    - Tags starting with `v` (e.g. `v1.5.7`).
  - Builds a **release Android App Bundle (AAB)** with `flutter build appbundle --release`.
  - Uploads the bundle artifact as `android-bundle`.

- **release**
  - Runs only on tags starting with `v` and after `build_android` succeeds.
  - Downloads the `android-bundle` artifact.
  - Creates a GitHub Release for the tag using `softprops/action-gh-release`:
    - `generate_release_notes: true` (GitHub auto release notes).
    - Attaches the `.aab` file(s).

> Note: CI builds **unsigned** bundles. Signing is done locally with a private keystore.

## 3. Day‑to‑day development flow

1. **Create a feature branch**

   ```bash
   git checkout develop
   git pull
   git checkout -b feature/my-change
   ```

2. **Implement the change**, run tests locally as needed:

   ```bash
   flutter test
   ```

3. **Commit and push**:

   ```bash
   git add .
   git commit -m "feat: my change"
   git push -u origin feature/my-change
   ```

4. **Open a PR into `develop`**.
   - CI runs `run_tests` on the PR.
   - Fix any failing tests and update the PR.

5. **Merge PR into `develop`** when CI is green.

## 4. Preparing a release

When `develop` is stable and you want to release:

1. **Merge `develop` into `main`** (usually via PR):

   ```bash
   git checkout main
   git pull
   git merge --no-ff develop
   git push origin main
   ```

   - CI will run on `main`:
     - `run_tests`
     - `build_android` (builds the unsigned AAB and uploads `android-bundle`).

2. **Update the version in `pubspec.yaml`** on `main`:

   ```yaml
   version: 1.5.7+89  # example
   ```

   - `1.5.7` – semantic version visible to users.
   - `+89` – build number (must increase monotonically).

3. **Commit and push the version bump**:

   ```bash
   git add pubspec.yaml
   git commit -m "chore: release 1.5.7"
   git push origin main
   ```

   - CI runs again on `main` (tests + AAB build).

## 5. Tagging and automated GitHub Release

After `main` is up‑to‑date and green:

1. **Create a git tag** for the release:

   ```bash
   git tag v1.5.7
   git push origin v1.5.7
   ```

2. For the `v1.5.7` tag, CI will:
   - Run `run_tests`.
   - Run `build_android`:
     - `flutter build appbundle --release`.
     - Upload `android-bundle` (unsigned `.aab`).
   - Run `release`:
     - Download `android-bundle`.
     - Create a GitHub Release `v1.5.7`.
     - Generate release notes from commits/PRs.
     - Attach the `.aab` file to the release.

3. **Result**: under GitHub → Releases you will see a release named `v1.5.7` with:
   - Auto‑generated notes.
   - An attached unsigned `.aab` bundle.

## 6. Local signing and Play Console upload

Signing is intentionally kept **local** to protect the keystore.

1. **Download the AAB from GitHub**:
   - Option A: from the `vX.Y.Z` release page (preferred).
   - Option B: from the corresponding Actions run’s `android-bundle` artifact.

2. **Sign the bundle locally** using your existing keystore:

   - Option A: Android Studio
     - `Build` → `Generate Signed Bundle / APK…`.
     - Choose **Android App Bundle**.
     - Use your local keystore and passwords.
     - Produce a signed `.aab` for release.

   - Option B: your existing Gradle or command‑line signing process.

3. **Upload the signed bundle to Google Play Console**:
   - Go to the release track (e.g. Production / Beta).
   - Upload the signed `.aab`.
   - Complete the usual Play Console review steps.

## 7. Notes and conventions

- Commit message conventions (recommended):
  - `feat: ...` – new user‑visible feature.
  - `fix: ...` – bug fix.
  - `chore: ...` – technical/maintenance tasks (e.g. `chore: release 1.5.7`).
  - `docs: ...` – documentation changes.
- Tags must start with `v` (e.g. `v1.5.7`) for the release workflow to trigger.
- CI builds **only the bundle (.aab)** for releases; APKs are not produced.
