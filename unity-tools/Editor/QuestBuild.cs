using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.Rendering;

namespace RepoQuest.Editor
{
    /// <summary>
    /// Batch build of the exported R.E.P.O. project for Meta Quest (Android, ARM64, IL2CPP), in two editor runs:
    /// settings changes schedule a domain reload, and BuildPlayer refuses to run until it has happened.
    ///   1. -executeMethod RepoQuest.Editor.QuestBuild.Prepare [-addressablesEntries &lt;entries.json&gt;]
    ///   2. -executeMethod RepoQuest.Editor.QuestBuild.BuildApk -apkPath &lt;file&gt; [-developmentBuild] [-profiling]
    ///      [-versionName &lt;x.y.z&gt;] [-versionCode &lt;n&gt;]
    /// The builder's UnityBuildStep (builder/QuestBuilder.Core) runs both.
    /// </summary>
    public static class QuestBuild
    {
        private const string PackageName = "io.repoxr.quest";

        /// <summary>BuildApk -profiling: see <see cref="ProfileableManifest"/></summary>
        internal static bool Profiling { get; private set; }

        public static void Prepare()
        {
            ConfigurePlayer();

            // Import artifacts made before the game assembly was renamed (Assembly-CSharp -> REPO.Game) keep their
            // MonoBehaviours without data: Map - Valuable shipped with every reference null. The builder's UnityBuildStep
            // passes the assets that use game scripts once for a Library made before the rename
            var reimportList = ArgumentValue("-reimportList");
            if (reimportList != null)
                ReimportAssets(File.ReadAllLines(reimportList));

            // The exported project has the addressable assets but not the editor-side Addressables setup
            var entries = ArgumentValue("-addressablesEntries");
            if (entries != null)
                AddressablesRestore.Apply(entries);

            TmpFontAtlasFix.Apply();

            // VR builds also carry QuestXRSetup (it needs the XR packages, so it is not referenced directly)
            var xrSetup = AppDomain.CurrentDomain.GetAssemblies()
                .Select(a => a.GetType("RepoQuest.Editor.QuestXRSetup"))
                .FirstOrDefault(t => t != null);
            xrSetup?.GetMethod("Apply")!.Invoke(null, null);

            AssetDatabase.SaveAssets();
            EditorApplication.Exit(0);
        }

        private static void ReimportAssets(string[] paths)
        {
            Debug.Log($"[QuestBuild] reimporting {paths.Length} assets that use game scripts");
            AssetDatabase.StartAssetEditing();
            try
            {
                foreach (var path in paths.Where(p => p.Length > 0))
                    AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceUpdate);
            }
            finally
            {
                AssetDatabase.StopAssetEditing();
            }
        }

        public static void BuildApk()
        {
            var apkPath = ArgumentValue("-apkPath") ?? Path.GetFullPath("Builds/repo-quest.apk");
            var development = Environment.GetCommandLineArgs().Contains("-developmentBuild");

            // A release build that simpleperf/Perfetto may sample (profileable from the shell) with IL2CPP symbols next
            // to the APK, so native hotspots have the game's method names; neither changes how fast the build runs
            Profiling = Environment.GetCommandLineArgs().Contains("-profiling");
            EditorUserBuildSettings.androidCreateSymbols =
                Profiling ? AndroidCreateSymbols.Debugging : AndroidCreateSymbols.Disabled;

            // The port's version (the builder's), shown in the main menu; versionCode grows with every release so an
            // update installs over the previous build
            var versionName = ArgumentValue("-versionName");
            if (versionName != null)
                PlayerSettings.bundleVersion = versionName;
            if (int.TryParse(ArgumentValue("-versionCode"), out var versionCode))
                PlayerSettings.Android.bundleVersionCode = versionCode;

            if (!AddressablesRestore.BuildContent())
            {
                EditorApplication.Exit(1);
                return;
            }

            var scenes = EditorBuildSettings.scenes.Where(s => s.enabled).Select(s => s.path).ToArray();
            Debug.Log($"[QuestBuild] building {scenes.Length} scenes -> {apkPath} (development: {development})");
            Directory.CreateDirectory(Path.GetDirectoryName(apkPath)!);

            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = scenes,
                locationPathName = apkPath,
                target = BuildTarget.Android,
                targetGroup = BuildTargetGroup.Android,
                options = development ? BuildOptions.Development : BuildOptions.None,
            });

            var summary = report.summary;
            Debug.Log($"[QuestBuild] result: {summary.result}, size: {summary.totalSize / (1024 * 1024)} MB, " +
                      $"time: {summary.totalTime}, errors: {summary.totalErrors}, warnings: {summary.totalWarnings}");

            foreach (var step in report.steps)
            foreach (var message in step.messages.Where(m => m.type is LogType.Error or LogType.Exception))
                Debug.Log($"[QuestBuild] error in '{step.name}': {message.content}");

            // Where the time went (the log's own timestamps cannot tell which part of BuildPlayer a silence belongs to)
            foreach (var step in report.steps.Where(s => s.duration.TotalSeconds >= 1))
                Debug.Log($"[QuestBuild] step {new string(' ', 2 * step.depth)}{step.name}: {step.duration.TotalSeconds:F0} s");

            EditorApplication.Exit(summary.result == BuildResult.Succeeded ? 0 : 1);
        }

        private static void ConfigurePlayer()
        {
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
            EditorUserBuildSettings.androidBuildSubtarget = MobileTextureSubtarget.ASTC;

            var android = NamedBuildTarget.Android;
            PlayerSettings.SetApplicationIdentifier(android, PackageName);
            PlayerSettings.Android.bundleVersionCode = 1;  // exported settings carry 0, which Gradle rejects
            PlayerSettings.SetScriptingBackend(android, ScriptingImplementation.IL2CPP);
            // CPU time: Master is IL2CPP's fully optimized C++ build (link-time optimization, no
            // per-method checks the Release configuration keeps); the game is CPU-bound on the Quest. Takes a few minutes
            // longer to build. Faster code over smaller code
            PlayerSettings.SetIl2CppCompilerConfiguration(android, Il2CppCompilerConfiguration.Master);
            PlayerSettings.SetIl2CppCodeGeneration(android, Il2CppCodeGeneration.OptimizeSpeed);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;

            // Quest 3 runs Horizon OS on Android 14 (API 34), which is also the newest platform Unity's SDK module
            // installs; Meta's minimum is 29
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel29;
            // Unity 6000.3: the newest platform the editor's SDK module installed; a target above the
            // headset's Android 14 still installs and runs there
            PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevelAuto;
            // Unity 6 starts new projects with GameActivity; the game, OpenXR's Meta loader setup and our manifest
            // edits use the classic UnityPlayerActivity (the game's own settings: androidApplicationEntry 1 = Activity)
            PlayerSettings.Android.applicationEntry = AndroidApplicationEntry.Activity;

            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android, false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android, new[] { GraphicsDeviceType.Vulkan });

            // The game's assemblies are precompiled and reached through reflection (Photon RPCs, RepoXR);
            // keep IL2CPP from stripping them
            PlayerSettings.SetManagedStrippingLevel(android, ManagedStrippingLevel.Minimal);
            PlayerSettings.stripEngineCode = false;

            PlayerSettings.Android.forceInternetPermission = true;
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;

            // The game is CPU-bound on the Quest. Meta recommends graphics jobs in Legacy mode for main-thread-bound
            // apps ("up to 2 FPS", developers.meta.com/horizon/documentation/unity/po-graphics-jobs); since 2022.3.35
            // they can only be set from script. They need multithreaded rendering
            PlayerSettings.SetMobileMTRendering(android, true);
            PlayerSettings.graphicsJobs = true;
            PlayerSettings.graphicsJobMode = GraphicsJobMode.Legacy;
            // Spreads garbage collection over frames instead of stalling one (the game allocates every frame)
            PlayerSettings.gcIncremental = true;
            // CPU and GPU frame times for PerfLog (Pico logs no VrApi lines); costs next to nothing
            PlayerSettings.enableFrameTimingStats = true;

            RestoreGameSettings();

            // Addressables 2.x reads binary catalogs unless ENABLE_JSON_CATALOG is defined; RepoXR's own
            // Android content (kit prebuilt/repoxr-android, built with Addressables 1.x) is catalog_0.1.json, which
            // AssetCollection loads with LoadContentCatalogAsync. With the define the game's rebuilt catalog is JSON too
            AddDefine("ENABLE_JSON_CATALOG");
        }

        private static void AddDefine(string define)
        {
            var android = NamedBuildTarget.Android;
            var defines = PlayerSettings.GetScriptingDefineSymbols(android);
            if (defines.Split(';').Contains(define))
                return;
            PlayerSettings.SetScriptingDefineSymbols(android, string.IsNullOrEmpty(defines) ? define : defines + ";" + define);
            Debug.Log($"[QuestBuild] scripting define {define}");
        }

        /// <summary>
        /// AssetRipper 2.0.0 cannot read R.E.P.O. 0.5.0's (Unity 6000.3) PlayerSettings ("Read 944 but
        /// expected 948 for asset type 129"), so the export has no ProjectSettings.asset and Unity makes a default one.
        /// What of the game's settings matters, read from its globalgamemanagers: company and product name, gamma color
        /// space, both input handlers (the game reads UnityEngine.Input as well as the Input System), and the preloaded
        /// assets: the Input System's project-wide actions and settings and the Localization settings.
        /// </summary>
        private static void RestoreGameSettings()
        {
            PlayerSettings.companyName = "semiwork";
            PlayerSettings.productName = "REPO";
            PlayerSettings.colorSpace = ColorSpace.Gamma;
            PlayerSettings.gpuSkinning = true;
            PlayerSettings.runInBackground = true;
            PlayerSettings.SplashScreen.show = false;
            // The widest API profile: the game's precompiled assemblies were built against Mono's full framework (their
            // own setting is lost with PlayerSettings); .NET Standard 2.1 assemblies (RepoXR) run on it as well
            PlayerSettings.SetApiCompatibilityLevel(NamedBuildTarget.Android, ApiCompatibilityLevel.NET_Unity_4_8);

            // activeInputHandler has no API; 2 = Both. Takes effect when the editor starts again (BuildApk is the next run)
            var playerSettings = Unsupported.GetSerializedAssetInterfaceSingleton("PlayerSettings");
            var serialized = new SerializedObject(playerSettings);
            var inputHandler = serialized.FindProperty("activeInputHandler");
            if (inputHandler != null && inputHandler.intValue != 2)
            {
                inputHandler.intValue = 2;
                serialized.ApplyModifiedPropertiesWithoutUndo();
                Debug.Log("[QuestBuild] active input handling: both");
            }

            var preloaded = PlayerSettings.GetPreloadedAssets().Where(a => a != null).ToList();
            void Preload(UnityEngine.Object asset, string what)
            {
                if (asset == null)
                {
                    Debug.LogError($"[QuestBuild] {what} not found in the export; not preloaded");
                    return;
                }
                if (!preloaded.Contains(asset))
                    preloaded.Add(asset);
                Debug.Log($"[QuestBuild] preloaded: {what} ({AssetDatabase.GetAssetPath(asset)})");
            }

            var actions = FindAsset("t:InputActionAsset InputSystem_Actions", "InputActionAsset", "InputSystem_Actions");
            var inputSettings = FindAsset("t:InputSettings", "InputSettings", null);
            Preload(actions, "Input System project-wide actions");
            Preload(inputSettings, "Input System settings");
            Preload(AssetDatabase.LoadMainAssetAtPath("Assets/Localization/Localization Settings.asset"), "Localization settings");
            PlayerSettings.SetPreloadedAssets(preloaded.ToArray());

            // The Input System also looks for both through these editor config objects (and adds them to the preloaded
            // assets itself while it builds)
            if (inputSettings != null)
                EditorBuildSettings.AddConfigObject("com.unity.input.settings", inputSettings, true);
            if (actions != null)
                EditorBuildSettings.AddConfigObject("com.unity.input.settings.actions", actions, true);
        }

        private static UnityEngine.Object FindAsset(string filter, string typeName, string name)
        {
            foreach (var guid in AssetDatabase.FindAssets(filter))
            {
                var path = AssetDatabase.GUIDToAssetPath(guid);
                foreach (var asset in AssetDatabase.LoadAllAssetsAtPath(path))
                    if (asset != null && asset.GetType().Name == typeName && (name == null || asset.name == name))
                        return asset;
            }
            return null;
        }

        private static string ArgumentValue(string name)
        {
            var args = Environment.GetCommandLineArgs();
            var index = Array.IndexOf(args, name);
            return index >= 0 && index + 1 < args.Length ? args[index + 1] : null;
        }
    }
}
