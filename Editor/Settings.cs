using System.Globalization;
using System;
using UnityEditor;

namespace jp.lilxyzw.lilpbr
{
    [FilePath("jp.lilxyzw/lilpbr.asset", FilePathAttribute.Location.PreferencesFolder)]
    internal class Settings : ScriptableSingleton<Settings>
    {
        public string language = CultureInfo.CurrentCulture.Name;
        [NonSerialized]
        public bool useSafeMaterialGui = true;

        internal void Save() => Save(true);
    }
}
