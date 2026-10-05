# Release streamlining

Date: 2026-10-05

## Context

Shipping v0.3.0 needed four separate approvals of the `release` environment, because the macOS and Windows builds ran one after the other and each asked on its own. The release also re-ran CI on a commit whose CI had already passed on `main`. It then stopped at a draft until someone published it by hand.

During a GitHub Actions runner outage, each extra job meant another wait for a runner. The update-file check alone was cancelled twice without ever starting. The owner asked for a release flow with no approvals: once a change is on `main` and tagged, it is built and shipped, with no loss of production quality.

## Decisions

| Decision | Why |
|---|---|
| The macOS and Windows builds run side by side | The one-after-the-other order came from Tauri, whose build action rewrote `latest.json` from both jobs and raced. The Flutter pipeline writes `latest.json` once, in its own job after both builds, so there is no race to avoid. A release finishes about ten minutes sooner |
| The release checks that the tagged commit is on `main` and that its `CI OK` passed, instead of running CI again | Every commit on `main` already runs the full CI, including both platform builds. That is more than the release's own CI call, which skipped the builds. The release waits while that CI is still running and refuses a commit whose `CI OK` failed or was cancelled, so a red commit still cannot ship |
| `make_manifest.dart` verifies each artifact's signature with the update key embedded in the app before it writes `latest.json` | Before, nothing in the pipeline proved that the signatures in `latest.json` verify with the key installed copies trust. A wrong key or an artifact changed after signing would have reached users as an update that every copy refuses. That check had been run by hand before each publish |
| The asset check of `latest.json` runs in the job that uploads it | One fewer job to wait for a runner. The check is unchanged: the version, all four platform keys, URLs that point at this release's downloads, and assets that exist |
| A release that passes every check publishes itself as the latest release | The draft step only waited for a person to press publish after the automated checks had already passed. A version with a pre-release suffix such as `-rc.1` is published as a pre-release and never becomes the latest |
| The `workflow_call` entry point and `skip-bundle` input are removed from `ci.yml` | The release no longer calls CI |

## What still guards a release

- Only admins can push `v*` tags (the `release-tags` ruleset), so the tag push is the one human decision.
- The signing key lives only in the `release` environment, which releases it only to runs from `v*` tags.
- The tag must equal the `pubspec.yaml` version, and the CHANGELOG must have a dated section for it.
- The commit must be on `main` and must have passed `CI OK`.
- `latest.json` is written only from signatures that verify with the app's update key, and it is checked against the uploaded assets.
- Build provenance is attested before publishing.

## Human step

Remove the required reviewer from the `release` environment: Settings → Environments → release → untick **Required reviewers** → **Save protection rules**. Keep the deployment branch and tag rule `v*`, and keep both signing secrets in the environment. Until this is done, the builds still wait for approval, though only once per release, since they now start together.

## Rollback

Restore the previous `release.yml` and `ci.yml` from git. To bring back the approval, tick **Required reviewers** again on the `release` environment and add yourself. To pull a published release, edit it back to a draft. `releases/latest` then points at the previous release again.
