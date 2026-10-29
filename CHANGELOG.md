# Changelog

Releases of this fork. Each release is a kit (`kit` branch) plus the matching code on `repo-0.5.0`; the build scripts
download the kit of their version. The original project's history is in
[Dobutsu/repo-quest-vr](https://github.com/Dobutsu/repo-quest-vr/releases).

## 1.0.7-qc2

Tooling for game updates; the APK is built exactly as with 1.0.7-qc1.

- **`QuestBuilder.Cli check`**: what a game update broke, in minutes and without Unity. It bakes RepoXR's patches
  into the new game code and reports failed patch classes, invalid IL, class-type mismatches (what clang rejects),
  patched methods that did not change or changed only at their end, references between the game, RepoXR,
  RepoXR.Standalone and SteamShim that no longer resolve, and changes in the Unity version, Addressables, package DLLs
  and the set of DLLs (`scripts/check_game.py` against `scripts/game_fingerprints.json`).
- `scripts/build-mac.sh` and `scripts/build-windows.ps1` run the check by themselves when the game version is not
  among the kit's tested ones, and stop on failures (`FORCE=1` / `-Force` builds anyway).
- `scripts/repoxr-patch.sh`: a new RepoXR patch for a game version (`start`, `save`).
- `scripts/release-fork.sh`: a release in one command (kit, versions in the build scripts, tag, kit branch, GitHub
  release).
- `tools/IlCheck refs`: unresolved references; IlCheck runs inside the builder as the `il-check` tool.
- Docs: [`docs/updating.md`](docs/updating.md) — what to do when R.E.P.O. updates.

## 1.0.7-qc1

First port to **R.E.P.O. 0.5.0** (Unity 6000.3.17f1), on top of repo-quest-vr 1.0.7. Testing build: the pipeline
builds the APK; testing on a Quest 3 is in progress.

- RepoXR patch 0009 for 0.5.0's code: renamed and moved members, new overloads, the text prompt page, climbing,
  menu clicks through `InputKey.UIClick`, the camera sent over the network.
- Builder: Unity 6000.3.17f1, the export without PlayerSettings, the Addressables 2.x binary catalog, WAV headers.
- Unity packages matched to 0.5.0 (Input System 1.19.0, uGUI 2.0.0 with TextMeshPro, Localization 1.5.12,
  Addressables 2.9.1, PostProcessing 3.5.4 and others).
- SteamShim: the Steam APIs 0.5.0 calls; the in-headset Steam login on 0.5.0's text prompt page.
- Performance: level culling (settings in *VR Settings → Rendering*), IL2CPP Master, CPU/GPU at SUSTAINED_HIGH.
- Build scripts for macOS and Windows; docs in English and Russian.
