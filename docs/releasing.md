# Releasing a new version (both repositories)

**English** · [Русский](releasing.ru.md)

For maintainers. RepoXR changes are made and tested in the PC fork ([crimecock/RepoXR](https://github.com/crimecock/RepoXR),
branch `repo-0.5.0`) and come to this repository as a patch, so a typical release (a fix in RepoXR) touches both:
first the PC release (alpha N), then the Quest kit (1.0.7-qcNN) with the same code. A change only in the Quest
pipeline (scripts, builder) skips part A.

## Where the version lives

| What | PC fork | This repository (Quest) |
|---|---|---|
| Release name and tag | `v1.2.3-repo0.5.0-alpha.N` | `v1.0.7-qcNN` |
| Changelog | `CHANGELOG.md`: `# Unreleased` → `# 1.2.3-repo0.5.0-alpha.N (unofficial fork)` | `CHANGELOG.md` / `CHANGELOG.ru.md`: `## Unreleased` / `## Готовится` → `## 1.0.7-qcNN` |
| What players download | the release's two zips | `kit` branch: `repoquest-kit-1.0.7-qcNN.zip`, `SHA256SUMS`, its README |
| Pinned in code | README: the direct link to the all-in-one zip | `scripts/build-mac.sh` `VERSION`, `KIT_SHA`; `scripts/build-windows.ps1` `$Version`, `$KitSha` |
| Status text | README (status table, known issues), `docs/repo-0.5.0` | README (status, "What this fork changes"), `docs/playing` (known issues), `docs/updating` (example) |
| Stays | `Plugin.PLUGIN_VERSION = "1.2.3"` (RepoXR's own version) | `kit.json` in `builder/` (the kit gets its version when made) |

## A. The PC release (alpha N)

1. **Change and test**: change `Source/`, build
   (`dotnet build RepoXR.sln -c Release -p:DebugSymbols=false -p:GamePath=…`, [COMPILING.md](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/COMPILING.md)),
   copy the DLL into the game and play it.
2. **Docs**: in `CHANGELOG.md` rename `# Unreleased` to `# 1.2.3-repo0.5.0-alpha.N (unofficial fork)`; update the
   README (status table, known issues, the direct download link to `…-alpha.N-all-in-one.zip`) and, for a new problem
   solved, a row in `docs/repo-0.5.0(.ru).md`'s table (what changed in 0.5.0, what broke, the fix). Commit and push.
3. **Zips**: `python3 tools/package/make_release.py alpha.N` → `dist/RepoXR-repo0.5.0-alpha.N.zip` and
   `…-all-in-one.zip` ([what goes in](https://github.com/crimecock/RepoXR/blob/repo-0.5.0/COMPILING.md#the-release-zips--архивы-релиза)).
4. **Release**: on GitHub, a new release with tag `v1.2.3-repo0.5.0-alpha.N` on the pushed commit, marked pre-release,
   notes in English and Russian (the previous release is the template: what is new, known issues, install, update,
   SHA-256 of both zips); attach both zips.

## B. The Quest release (1.0.7-qcNN)

1. **Patch**: here, `git diff <PC commit of the previous patch> <PC commit of the release> -- Source >
   patches/repoxr/00NN-what-it-does.patch` (run in the PC fork, save here; `00NN` = the next number), and describe it in
   `scripts/prepare-repoxr.sh`'s header. Check: `bash scripts/prepare-repoxr.sh` builds, and the patched
   `work/repoxr-src/Source` is the PC fork's `Source` at that commit.
2. **Test on the headset**: `REPOXR_DLL=$PWD/work/repoxr-src/bin/Release/netstandard2.1/RepoXR.dll CODE_ONLY=1 bash
   scripts/build-mac.sh` ([build-repoxr.md](build-repoxr.md)).
3. **Docs**: `## Unreleased` / `## Готовится` → `## 1.0.7-qcNN` in both changelogs (the GitHub release notes are made
   from them); README status and "What this fork changes" (link the new patch), `docs/playing(.ru)` known issues,
   `docs/updating(.ru)` example (`qcOLD → qcNN`). Commit.
4. **Kit, scripts, tag, release** — `scripts/release-fork.sh` does all of it:

   ```bash
   GITHUB_TOKEN=... scripts/release-fork.sh 1.0.7-qcNN --dlls <folder> --prerelease
   ```

   `<folder>` holds `RepoXR.dll` (`work/repoxr-src/bin/Release/netstandard2.1`), `RepoXR.Standalone.dll` and
   `Facepunch.Steamworks.Win64.dll` (`tools/*/bin/Release/netstandard2.1` after `scripts/make-kit.sh`, or the current
   kit's `prebuilt/` when they did not change). The script takes the current kit, puts in this checkout's scripts,
   Unity tooling and the three DLLs, sets `kit.json`'s version, writes `VERSION`/`KIT_SHA` into both build scripts,
   commits, tags `v1.0.7-qcNN`, pushes the kit to the `kit` branch (with `SHA256SUMS`), checks the download and creates
   the GitHub release. `--dry-run` stops before committing. A tested game version: `--game <folder> --game-name v0.5.x`.
   After it: update the version in the `kit` branch's README if the patch range there changed.

   Without the script (how 1.0.7-qc23 to qc27 were made): unzip the current kit, replace `prebuilt/repoxr/RepoXR.dll`,
   set `kit.json`'s `version`, zip it again; add it and its line in `SHA256SUMS` to the `kit` branch; put the version and
   SHA-256 into `scripts/build-mac.sh` and `scripts/build-windows.ps1`; push both branches together; tag and create the
   release (notes from the changelogs, the kit's link and SHA-256).
5. **Check**: a clean `git clone` + `bash scripts/build-mac.sh` downloads the new kit (the SHA-256 check passes).

## What must not break

- The build scripts download exactly the kit named in them from the `kit` branch; GitHub releases, pre-releases or
  not, change nothing for them. Never change `VERSION`/`KIT_SHA` without the kit on the `kit` branch, and keep old kits
  there: older checkouts still name them.
- `scripts/prepare-repoxr.sh` (here) and `tools/package/make_release.py` (PC fork) take the Unity 6 XR libraries from
  the PC fork's alpha 6 release by URL and SHA-256: keep that release and its zips.
- Kits and APKs contain no game files; `make-kit.sh` and `release-fork.sh` refuse ones that do. Never publish an APK.
