using System.IO;
using System.Text;
using UnityEditor;

namespace jp.lilxyzw.lilpbr
{
    internal static class ShaderModifier
    {
        [InitializeOnLoadMethod]
        private static void Init()
        {
            var packageInfo = UnityEditor.PackageManager.PackageInfo.FindForAssembly(typeof(ShaderModifier).Assembly);
            var path = packageInfo == null
                ? "Packages/jp.lilxyzw.lilpbr/Shaders/settings.hlsl"
                : Path.Combine(packageInfo.resolvedPath, "Shaders/settings.hlsl");
            var sb = new StringBuilder();
#if LIL_VRCLIGHTVOLUMES
            sb.AppendLine("#define LIL_VRCLIGHTVOLUMES");
#endif
#if LIL_LTCGI
            sb.AppendLine("#define LIL_LTCGI");
#endif
#if LIL_VRCHAT
            sb.AppendLine("#include \"platform_vrchat.hlsl\"");
#endif
            var text = sb.ToString();
            if (File.Exists(path) && File.ReadAllText(path, Encoding.UTF8) == text) return;
            File.WriteAllText(path, text, Encoding.UTF8);
        }
    }
}
