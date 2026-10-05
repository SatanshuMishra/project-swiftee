---
description: Bump the version in pubspec.yaml; write the CHANGELOG entry; run /verify; open a release PR. Never pushes tags.
argument-hint: "patch|minor|major"
---

Validate `$ARGUMENTS` is one of `patch`, `minor`, `major`. Otherwise ask.

## Steps

1. **Read the current version** from `pubspec.yaml` (`version: X.Y.Z+B`). `pubspec.yaml` is the only place the app version lives; the release workflow refuses a tag that does not equal `X.Y.Z`.

2. **Compute the new version** by bumping the `$ARGUMENTS` SemVer component of `X.Y.Z`, and the new build number as `B + 1`.

3. **Edit `pubspec.yaml`** to `version: <new-version>+<B + 1>`.

4. **Write the CHANGELOG entry** in `CHANGELOG.md`:
   - If an `## [Unreleased]` section exists, rename its heading to `## [<new-version>] - YYYY-MM-DD` with today's date.
   - Otherwise generate one from `git log $(git describe --tags --abbrev=0)..HEAD --oneline`, grouped by `feat:` / `fix:` / `chore:` prefix into `### Added`, `### Fixed` and `### Changed`, under the same heading, above the previous release.
   - The section must have text: the release workflow publishes it as the release notes.

5. **Run the release check locally**: `dart run tool/release/check_release.dart v<new-version>`. It must print the notes and exit 0.

6. **Run `/verify`.** If it fails, revert the `pubspec.yaml` and `CHANGELOG.md` edits and stop.

7. **Create the branch and commit**:
   ```bash
   git checkout -b release/v<new-version>
   git add pubspec.yaml CHANGELOG.md
   git commit -m "chore: release v<new-version>"
   git push -u origin release/v<new-version>
   ```

8. **Open the release pull request** to `main` titled `release: v<new-version>`, with the new CHANGELOG section as its body, through the `pr` skill.

9. **Do NOT push tags.** The maintainer tags `v<new-version>` after the PR merges. The tag starts the release workflow. It waits for that commit's `CI OK` on `main`, builds and signs both platforms, writes `latest.json` from signatures that verify with the app's update key, attests the artifacts, and publishes the release as the latest one, with no manual step.

## Safety

- The hook `block-secrets.sh` runs on each file edit.
- The updater key in `lib/services/updater/update_config.dart` is not touched by a release; the release check refuses the development key.
- If `/verify` fails partway, revert both files before retrying.
