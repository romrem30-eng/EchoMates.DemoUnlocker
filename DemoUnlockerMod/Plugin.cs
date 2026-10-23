using System.Reflection;
using BepInEx;
using BepInEx.Configuration;
using HarmonyLib;
using UnityEngine;
using UnityEngine.InputSystem;
using VoiceWalker;

namespace EchoMatesMod
{
    [BepInPlugin("com.modder.echomates.sandbox", "Echo Mates Sandbox & Unlocker", "1.3.0")]
    public class Plugin : BaseUnityPlugin
    {
        public static ConfigEntry<bool> CfgUnlockDemo;
        public static ConfigEntry<int> CfgMaxDepth;
        public static ConfigEntry<int> CfgMaxPlayers;
        public static ConfigEntry<bool> CfgBlockTelemetry;
        public static ConfigEntry<bool> CfgEnableDevMenu;
        public static ConfigEntry<bool> CfgEnableExorcistNeck;
        public static ConfigEntry<bool> CfgShowWatermark;

        public static bool ExorcistNeck = false;
        private static DevSpawnMenu _spawnMenuInstance;

        private void Awake()
        {
            // Настройка файла конфигурации (BepInEx/config/com.modder.echomates.sandbox.cfg)
            CfgUnlockDemo = Config.Bind("Features", "UnlockDemoLimits", true, 
                "Разблокировать всю игру: снятие ограничений демки, чертежи, чипы, исследования и постройки базы.");

            CfgMaxDepth = Config.Bind("Features", "MaxCampaignDepth", 99, 
                "Максимальная глубина кампании (в оригинальной игре 10; ставим 99 для бесконечного спуска без остановки).");

            CfgMaxPlayers = Config.Bind("Network", "MaxPlayers", 8, 
                "Количество слотов для игроков в лобби хоста (по умолчанию в игре 4; рекомендуется 6-8, максимум 16).");
            
            CfgBlockTelemetry = Config.Bind("Features", "BlockTelemetry", true, 
                "Полностью заглушить телеметрию, отсылаемую разработчикам игры.");
            
            CfgEnableDevMenu = Config.Bind("Features", "EnableDevMenu", false, 
                "Включить меню спавна разработчиков по клавише F1. (По умолчанию ВЫКЛЮЧЕНО).");
            
            CfgEnableExorcistNeck = Config.Bind("Features", "EnableExorcistNeck", false, 
                "Включить троллинг-режим поворота шеи на 180 градусов по клавише X. (По умолчанию ВЫКЛЮЧЕНО).");

            CfgShowWatermark = Config.Bind("UI", "ShowWatermark", false, 
                "Показывать зелёную плашку со статусом мода в левом верхнем углу экрана.");

            var harmony = new Harmony("com.modder.echomates.sandbox");
            harmony.PatchAll();

            Logger.LogInfo("=== [Echo Mates Mod - Host Edition] Loaded successfully with Config ===");
            Logger.LogInfo($"UnlockDemoLimits: {CfgUnlockDemo.Value}");
            Logger.LogInfo($"MaxCampaignDepth: {CfgMaxDepth.Value}");
            Logger.LogInfo($"MaxPlayers: {CfgMaxPlayers.Value}");
            Logger.LogInfo($"BlockTelemetry: {CfgBlockTelemetry.Value}");
            Logger.LogInfo($"EnableDevMenu: {CfgEnableDevMenu.Value}");
            Logger.LogInfo($"EnableExorcistNeck: {CfgEnableExorcistNeck.Value}");
        }

        public static DevSpawnMenu GetDevMenu()
        {
            if (_spawnMenuInstance == null)
            {
                _spawnMenuInstance = Object.FindAnyObjectByType<DevSpawnMenu>();
                if (_spawnMenuInstance == null)
                {
                    var host = new GameObject("Mod_DevSpawnMenu_Host");
                    Object.DontDestroyOnLoad(host);
                    _spawnMenuInstance = host.AddComponent<DevSpawnMenu>();
                }
            }
            return _spawnMenuInstance;
        }

        private void Update()
        {
            var keyboard = Keyboard.current;
            if (keyboard == null) return;

            // F1 — Меню разработчиков (работает ТОЛЬКО если включено в конфиге)
            if (CfgEnableDevMenu.Value)
            {
                if (keyboard.f1Key.wasPressedThisFrame)
                {
                    var menu = GetDevMenu();
                    if (DevSpawnMenu.IsOpen)
                    {
                        Traverse.Create(menu).Method("Close").GetValue();
                        Logger.LogInfo("DevSpawnMenu closed by F1.");
                    }
                    else
                    {
                        Traverse.Create(menu).Method("Open").GetValue();
                        Logger.LogInfo("DevSpawnMenu opened by F1.");
                    }
                }

                // ESC — закрыть меню, если оно открыто
                if (DevSpawnMenu.IsOpen && keyboard.escapeKey.wasPressedThisFrame)
                {
                    var menu = GetDevMenu();
                    Traverse.Create(menu).Method("Close").GetValue();
                    Logger.LogInfo("DevSpawnMenu closed by Escape.");
                }
            }

            // X — Режим экзорциста (работает ТОЛЬКО если включено в конфиге)
            if (CfgEnableExorcistNeck.Value)
            {
                if (keyboard.xKey.wasPressedThisFrame)
                {
                    ExorcistNeck = !ExorcistNeck;
                    Logger.LogInfo($"ExorcistNeck toggled: {ExorcistNeck}");
                }
            }
        }

        private void OnGUI()
        {
            // Показываем плашку только если включено в конфиге
            if (!CfgShowWatermark.Value && !DevSpawnMenu.IsOpen) return;

            GUI.color = Color.green;
            string status = $"[MOD ACTIVE] DemoUnlocked: {CfgUnlockDemo.Value} | TelemetryBlocked: {CfgBlockTelemetry.Value}";
            if (CfgEnableDevMenu.Value) status += $" | F1 DevMenu: {(DevSpawnMenu.IsOpen ? "OPEN" : "CLOSED")}";
            if (CfgEnableExorcistNeck.Value) status += $" | X Neck: {ExorcistNeck}";
            GUI.Label(new Rect(10, 10, 700, 25), status);
        }
    }

    // ==========================================
    // 1. РАЗБЛОКИРОВКА DEV МЕНЮ И СЕТЕВЫХ КОМАНД
    // ==========================================

    [HarmonyPatch(typeof(DevSpawnMenu), "Update")]
    public static class PatchDevSpawnMenuUpdate
    {
        static bool Prefix()
        {
            if (!Plugin.CfgEnableDevMenu.Value) return true;
            return false;
        }
    }

    [HarmonyPatch(typeof(DevSpawnMenu), "Open")]
    public static class PatchDevSpawnMenuOpen
    {
        static bool Prefix(DevSpawnMenu __instance)
        {
            if (!Plugin.CfgEnableDevMenu.Value) return true;

            var rebuildMethod = typeof(DevSpawnMenu).GetMethod("RebuildCatalog", BindingFlags.NonPublic | BindingFlags.Static);
            if (rebuildMethod != null)
            {
                rebuildMethod.Invoke(null, null);
            }

            var mc = MatchController.Instance;
            if (mc != null)
            {
                var tr = Traverse.Create(__instance);
                tr.Field("_targetDepth").SetValue(0);
                tr.Field("_noMobs").SetValue(mc.DevNoMobs);
                tr.Field("_forceTurrets").SetValue(mc.DevForceTurrets);
                tr.Field("_noTurrets").SetValue(mc.DevNoTurrets);
                tr.Field("_noSnares").SetValue(mc.DevNoSnares);
                tr.Field("_noWorms").SetValue(mc.DevNoWorms);
                tr.Field("_forceWorms").SetValue(mc.DevForceWorms);
                tr.Field("_forceZone").SetValue(mc.DevForceZone);
            }

            Traverse.Create(typeof(DevSpawnMenu)).Property("IsOpen").SetValue(true);
            Traverse.Create(__instance).Field("_cursorWasLocked").SetValue(Cursor.lockState == CursorLockMode.Locked);
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
            return false;
        }
    }

    [HarmonyPatch(typeof(NetGuard), "Dev")]
    public static class PatchNetGuardDev
    {
        static bool Prefix(ref bool __result)
        {
            if (!Plugin.CfgEnableDevMenu.Value) return true;
            __result = true;
            return false;
        }
    }

    // ==========================================
    // 2. ПОЛНАЯ БЛОКИРОВКА ТЕЛЕМЕТРИИ (STEALTH)
    // ==========================================

    [HarmonyPatch(typeof(Telemetry), "get_Active")]
    public static class SilenceTelemetryActive
    {
        static bool Prefix(ref bool __result)
        {
            if (!Plugin.CfgBlockTelemetry.Value) return true;
            __result = false;
            return false;
        }
    }

    [HarmonyPatch(typeof(Telemetry), "Send")]
    public static class BlockTelemetrySend
    {
        static bool Prefix() => !Plugin.CfgBlockTelemetry.Value;
    }

    [HarmonyPatch(typeof(Telemetry), "Track")]
    public static class BlockTelemetryTrack
    {
        static bool Prefix() => !Plugin.CfgBlockTelemetry.Value;
    }

    [HarmonyPatch(typeof(Telemetry), "Enqueue")]
    public static class BlockTelemetryEnqueue
    {
        static bool Prefix() => !Plugin.CfgBlockTelemetry.Value;
    }

    // ==========================================
    // 3. СНЯТИЕ ОГРАНИЧЕНИЙ ДЕМО-ВЕРСИИ
    // ==========================================

    [HarmonyPatch(typeof(GameVersion), "get_IsDemo")]
    public static class BypassGameVersionIsDemo
    {
        static bool Prefix(ref bool __result)
        {
            if (!Plugin.CfgUnlockDemo.Value) return true;
            __result = false;
            return false;
        }
    }

    [HarmonyPatch(typeof(DemoLimits), "get_Active")]
    public static class BypassDemoActive
    {
        static bool Prefix(ref bool __result)
        {
            if (!Plugin.CfgUnlockDemo.Value) return true;
            __result = false;
            return false;
        }
    }

    [HarmonyPatch(typeof(DemoLimits), "DepthLocked")]
    public static class BypassDepthLock
    {
        static bool Prefix(ref bool __result)
        {
            if (!Plugin.CfgUnlockDemo.Value) return true;
            __result = false;
            return false;
        }
    }

    [HarmonyPatch(typeof(DemoLimits), "LastDepth")]
    public static class BypassLastDepth
    {
        static bool Prefix(ref int __result)
        {
            if (!Plugin.CfgUnlockDemo.Value) return true;
            __result = Plugin.CfgMaxDepth.Value;
            return false;
        }
    }

    [HarmonyPatch(typeof(LevelTypes), "MaxDepth")]
    public static class BypassLevelTypesMaxDepth
    {
        static bool Prefix(ref int __result)
        {
            if (!Plugin.CfgUnlockDemo.Value) return true;
            __result = Plugin.CfgMaxDepth.Value;
            return false;
        }
    }

    [HarmonyPatch(typeof(VoiceWalkerConfig), "Get")]
    public static class PatchVoiceWalkerConfigGet
    {
        static void Postfix(VoiceWalkerConfig __result)
        {
            if (__result != null)
            {
                if (Plugin.CfgMaxPlayers != null)
                {
                    __result.steamLobbyMaxMembers = Mathf.Clamp(Plugin.CfgMaxPlayers.Value, 2, 16);
                }
                if (Plugin.CfgMaxDepth != null)
                {
                    __result.maxDepth = Plugin.CfgMaxDepth.Value;
                }
            }
        }
    }

    [HarmonyPatch(typeof(CampaignSave), "get_DemoCompleted")]
    public static class BypassCampaignDemoCompleted
    {
        static bool Prefix(ref bool __result)
        {
            if (!Plugin.CfgUnlockDemo.Value) return true;
            __result = false;
            return false;
        }
    }

    [HarmonyPatch(typeof(DemoLimits), "GearLocked")]
    public static class BypassGearLock
    {
        static bool Prefix(ref bool __result)
        {
            if (!Plugin.CfgUnlockDemo.Value) return true;
            __result = false;
            return false;
        }
    }

    [HarmonyPatch(typeof(DemoLimits), "BuildingAllowed")]
    public static class BypassBuildingAllowed
    {
        static bool Prefix(ref bool __result)
        {
            if (!Plugin.CfgUnlockDemo.Value) return true;
            __result = true;
            return false;
        }
    }

    [HarmonyPatch(typeof(DemoLimits), "get_ChipsLocked")]
    public static class BypassChipsLock
    {
        static bool Prefix(ref bool __result)
        {
            if (!Plugin.CfgUnlockDemo.Value) return true;
            __result = false;
            return false;
        }
    }

    // ==========================================
    // 4. ВЫВОРОТ ГОЛОВЫ НА 180° (ЭКЗОРЦИСТ)
    // ==========================================

    [HarmonyPatch(typeof(PlayerHeadAim), "LateUpdate")]
    public static class ExorcistHeadPatch
    {
        static void Postfix(PlayerHeadAim __instance)
        {
            if (Plugin.CfgEnableExorcistNeck.Value && Plugin.ExorcistNeck && __instance.HeadBone != null)
            {
                __instance.HeadBone.Rotate(Vector3.up, 180f, Space.Self);
            }
        }
    }
}
