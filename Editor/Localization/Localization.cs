using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace jp.lilxyzw.lilpbr
{
    internal partial class L10n : ScriptableSingleton<L10n>
    {
        public LocalizationAsset localizationAsset;
        private static string[] languages;
        private static string[] languageNames;
        private static readonly Dictionary<string, GUIContent> guicontents = new();
        private static string localizationFolder => AssetDatabase.GUIDToAssetPath("51be2e539426e71408b68600a577f98e");

        internal static void Load()
        {
            guicontents.Clear();
            var language = CurrentLanguage;
            var path = localizationFolder + "/" + language + ".po";
            instance.localizationAsset = File.Exists(path) ? AssetDatabase.LoadAssetAtPath<LocalizationAsset>(path) : null;

            if(!instance.localizationAsset) instance.localizationAsset = new LocalizationAsset();
        }

        internal static string CurrentLanguage
        {
            get
            {
                var language = NormalizeLanguage(Settings.instance.language);
                var availableLanguages = GetLanguages();
                if(!availableLanguages.Contains(language))
                {
                    language = availableLanguages.Contains("en-US") ? "en-US" : availableLanguages.FirstOrDefault();
                }
                if(!string.IsNullOrEmpty(language) && Settings.instance.language != language)
                {
                    Settings.instance.language = language;
                    Settings.instance.Save();
                }
                return language;
            }
        }

        private static string NormalizeLanguage(string language)
        {
            if(string.IsNullOrEmpty(language)) return "en-US";
            if(language.Equals("zh-CN", StringComparison.OrdinalIgnoreCase) || language.Equals("zh-SG", StringComparison.OrdinalIgnoreCase)) return "zh-Hans";
            if(language.Equals("zh-TW", StringComparison.OrdinalIgnoreCase) || language.Equals("zh-HK", StringComparison.OrdinalIgnoreCase) || language.Equals("zh-MO", StringComparison.OrdinalIgnoreCase)) return "zh-Hant";
            return language;
        }

        internal static string[] GetLanguages()
        {
            return languages ??= Directory.GetFiles(localizationFolder, "*.po").Select(f => Path.GetFileNameWithoutExtension(f)).Where(f => !f.StartsWith("._")).ToArray();
        }

        internal static string[] GetLanguageNames()
        {
            return languageNames ??= GetLanguages().Select(l => {
                if(l == "zh-Hans") return "简体中文";
                if(l == "zh-Hant") return "繁體中文";
                try
                {
                    return new CultureInfo(l).NativeName;
                }
                catch(CultureNotFoundException)
                {
                    return l;
                }
            }).ToArray();
        }

        internal static string L(string key)
        {
            if(string.IsNullOrEmpty(key)) return "";
            if(!instance.localizationAsset) Load();
            return instance.localizationAsset.GetLocalizedString(key);
        }

        public static GUIContent G(string key) => G(key, null, "");
        private static GUIContent G(string key, Texture image, string tooltip)
        {
            if(!instance.localizationAsset) Load();
            if(guicontents.TryGetValue(key, out var content)) return content;
            return guicontents[key] = new GUIContent(L(key), image, L(tooltip));
        }
    }
}
