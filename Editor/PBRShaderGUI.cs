using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;
using System.Runtime.ExceptionServices;
using System.Text;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace jp.lilxyzw.lilpbr
{
    internal class PBRShaderGUI : ShaderGUI
    {
        private static readonly Dictionary<Shader, ShaderGuiCache> shaderGuiCaches = new();
        private Dictionary<string, List<LILFoldoutDecorator>> foldoutStarts;
        private Dictionary<string, List<LILFoldoutEndDecorator>> foldoutEnds;
        private Dictionary<string, List<LILIfDecorator>> ifs;
        private Dictionary<string, int> boxStarts;
        private Dictionary<string, int> boxEnds;
        private Dictionary<string, string> keywords;
        private HashSet<string> needToCache;
        private HashSet<string> clearCache;

        void UseCache(ShaderGuiCache cache)
        {
            foldoutStarts = cache.foldoutStarts;
            foldoutEnds = cache.foldoutEnds;
            ifs = cache.ifs;
            boxStarts = cache.boxStarts;
            boxEnds = cache.boxEnds;
            keywords = cache.keywords;
            needToCache = cache.needToCache;
            clearCache = cache.clearCache;
            shaderImporter = cache.shaderImporter;
        }
        private int closedDepth = int.MaxValue;
        private int copyDepth = int.MaxValue;
        private int pasteDepth = int.MaxValue;
        private int resetDepth = int.MaxValue;
        private ProcessType processType;
        private LILFoldoutDecorator processAttr;
        private Shader shader;
        private ShaderImporter shaderImporter;
        private GUIStyle styleShuriken;
        private GUIStyle StyleShuriken => styleShuriken ??= new GUIStyle("ShurikenModuleTitle") { fixedHeight = 0 };
        private GUIStyle styleFoldout;
        private GUIStyle StyleFoldout => styleFoldout ??= new GUIStyle(EditorStyles.foldout) { fontStyle = FontStyle.Bold };
        private GUIStyle styleFoldoutLabel;
        private GUIStyle StyleFoldoutLabel => styleFoldoutLabel ??= new GUIStyle(EditorStyles.label) { fontStyle = FontStyle.Bold };
        [SerializeField] private List<string> openedTextures = new();
        private List<MaterialProperty> propertyCache = new();

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
        {
            if (!Initialize(materialEditor))
            {
                base.OnGUI(materialEditor, properties);
                return;
            }

            var wideMode = EditorGUIUtility.wideMode;
            EditorGUIUtility.wideMode = true;
            var indentLevel = EditorGUI.indentLevel;
            EditorGUI.indentLevel--;

            // 言語設定
            var langs = L10n.GetLanguages();
            var names = L10n.GetLanguageNames();
            EditorGUI.BeginChangeCheck();
            var ind = EditorGUILayout.Popup(L10n.G("Language"), Mathf.Max(0, Array.IndexOf(langs, L10n.CurrentLanguage)), names);
            if (EditorGUI.EndChangeCheck())
            {
                Settings.instance.language = langs[ind];
                Settings.instance.Save();
                L10n.Load();
            }

            foreach (var prop in properties)
            {
                // Box終了処理
                if (EditorGUI.indentLevel < closedDepth && boxEnds.TryGetValue(prop.name, out var endB))
                {
                    for (int i = 0; i < endB; i++) EditorGUILayout.EndVertical();
                }

                // Foldout終了処理
                if (foldoutEnds.TryGetValue(prop.name, out var ends))
                {
                    EditorGUI.indentLevel -= ends.Count;
                    if (EditorGUI.indentLevel < closedDepth) closedDepth = int.MaxValue;
                    if (EditorGUI.indentLevel < copyDepth) copyDepth = int.MaxValue;
                    if (EditorGUI.indentLevel < pasteDepth) pasteDepth = int.MaxValue;
                    if (EditorGUI.indentLevel < resetDepth) resetDepth = int.MaxValue;
                }

                // Foldout開始処理
                if (foldoutStarts.TryGetValue(prop.name, out var starts))
                {
                    int i = 0;
                    foreach (var start in starts)
                    {
                        i++;
                        var key = prop.name + i;
                        EditorGUI.indentLevel++;
                        if (EditorGUI.indentLevel - 1 < closedDepth)
                        {
                            var position = EditorGUILayout.GetControlRect(GUILayout.Height(EditorGUI.indentLevel == 0 ? 22f : 16f));
                            var positionIndent = EditorGUI.IndentedRect(position);
                            var labelRect = position;

                            // チェックボックスの処理
                            if (!string.IsNullOrEmpty(start.keyword))
                            {
                                var hasKeyword = materialEditor.HasKeyword(start.keyword, out var hasMixedValue);
                                labelRect.xMin += 16;
                                EditorGUI.BeginChangeCheck();
                                var enable = EditorGUI.Toggle(new(position) { xMax = positionIndent.x + 16 }, hasKeyword);
                                if (EditorGUI.EndChangeCheck())
                                {
                                    materialEditor.SetKeyword(start.keyword, enable);
                                }
                            }

                            // Foldoutの描画と処理
                            EditorGUI.BeginChangeCheck();
                            GUI.Button(new Rect(positionIndent) { xMin = positionIndent.xMin - 15f, xMax = Event.current.type == EventType.Repaint ? positionIndent.xMax : positionIndent.xMax - 20f, height = positionIndent.height + 4f }, GUIContent.none, StyleShuriken);
                            var isOpened = LILFoldoutSaver.IsOpened(key);
                            if (EditorGUI.EndChangeCheck())
                            {
                                isOpened = !isOpened;
                                if (isOpened) LILFoldoutSaver.Open(key);
                                else LILFoldoutSaver.Close(key);
                            }
                            if (!isOpened) closedDepth = EditorGUI.indentLevel;

                            // 要素の描画
                            if (!string.IsNullOrEmpty(start.keyword))
                            {
                                var hasKeyword = materialEditor.HasKeyword(start.keyword, out var hasMixedValue);
                                EditorGUI.showMixedValue = hasMixedValue;
                                var enable = EditorGUI.Toggle(new(position) { xMax = positionIndent.x + 16 }, hasKeyword);
                                EditorGUI.showMixedValue = false;
                            }
                            EditorGUI.Foldout(position, isOpened, GUIContent.none, EditorStyles.foldout);
                            EditorGUI.LabelField(labelRect, L10n.G(start.label), EditorStyles.boldLabel);

                            // コピペボタンの描画
                            if (GUI.Button(new Rect(positionIndent) { xMin = positionIndent.xMax - 20f }, EditorGUIUtility.IconContent("_Popup"), EditorStyles.label))
                            {
                                EditorUtility.DisplayCustomMenu(new Rect(Event.current.mousePosition, Vector2.one), new GUIContent[] { L10n.G("Copy"), L10n.G("Paste"), L10n.G("Reset") }, -1, (userdata, _, selected) =>
                                {
                                    processType = (ProcessType)selected;
                                    processAttr = userdata as LILFoldoutDecorator;
                                }, start);
                            }

                            // コピペボタンの処理
                            if (processAttr == start)
                            {
                                processAttr = null;
                                switch (processType)
                                {
                                    case ProcessType.Copy: copyDepth = EditorGUI.indentLevel; break;
                                    case ProcessType.Paste: pasteDepth = EditorGUI.indentLevel; break;
                                    case ProcessType.Reset: resetDepth = EditorGUI.indentLevel; break;
                                }
                            }
                        }
                    }
                }

                // Box開始処理
                if (EditorGUI.indentLevel < closedDepth && boxStarts.TryGetValue(prop.name, out var startB))
                {
                    for (int i = 0; i < startB; i++) EditorGUILayout.BeginVertical(EditorStyles.helpBox);
                }

                // シェーダーキーワードのセット
                void DoKeyword(MaterialProperty prop)
                {
                    if (keywords.TryGetValue(prop.name, out var keyword))
                    {
                        foreach (Material mat in materialEditor.targets)
                        {
                            if (prop.propertyType() == ShaderPropertyType.Float && prop.floatValue != 0 ||
                                prop.propertyType() == ShaderPropertyType.Range && prop.floatValue != 0 ||
                                prop.propertyType() == ShaderPropertyType.Int && prop.intValue != 0 ||
                                prop.propertyType() == ShaderPropertyType.Color && prop.colorValue.maxColorComponent != 0 ||
                                prop.propertyType() == ShaderPropertyType.Texture && prop.textureValue) SetKeywordIfChanged(mat, keyword, true);
                            else SetKeywordIfChanged(mat, keyword, false);
                        }
                    }
                }

                // コピー処理
                if (EditorGUI.indentLevel >= copyDepth)
                {
                    switch (prop.propertyType())
                    {
                        case ShaderPropertyType.Color: PropertyClipboard.Copy(prop.name, prop.colorValue); break;
                        case ShaderPropertyType.Vector: PropertyClipboard.Copy(prop.name, prop.vectorValue); break;
                        case ShaderPropertyType.Float: PropertyClipboard.Copy(prop.name, prop.floatValue); break;
                        case ShaderPropertyType.Range: PropertyClipboard.Copy(prop.name, prop.floatValue); break;
                        case ShaderPropertyType.Texture: PropertyClipboard.Copy(prop.name, prop.textureValue); break;
                        case ShaderPropertyType.Int: PropertyClipboard.Copy(prop.name, prop.intValue); break;
                    }
                    DoKeyword(prop);
                }

                // ペースト処理
                if (EditorGUI.indentLevel >= pasteDepth)
                {
                    switch (prop.propertyType())
                    {
                        case ShaderPropertyType.Color: if (PropertyClipboard.TryGet(prop.name, out Vector4 valueColor)) prop.colorValue = valueColor; break;
                        case ShaderPropertyType.Vector: if (PropertyClipboard.TryGet(prop.name, out Vector4 valueVector)) prop.vectorValue = valueVector; break;
                        case ShaderPropertyType.Float: if (PropertyClipboard.TryGet(prop.name, out float valueFloat)) prop.floatValue = valueFloat; break;
                        case ShaderPropertyType.Range: if (PropertyClipboard.TryGet(prop.name, out float valueRange)) prop.floatValue = valueRange; break;
                        case ShaderPropertyType.Texture: if (PropertyClipboard.TryGet(prop.name, out Texture valueTexture)) prop.textureValue = valueTexture; break;
                        case ShaderPropertyType.Int: if (PropertyClipboard.TryGet(prop.name, out int valueInt)) prop.intValue = valueInt; break;
                    }
                    DoKeyword(prop);
                }

                // リセット処理
                if (EditorGUI.indentLevel >= resetDepth)
                {
                    var index = shader.FindPropertyIndex(prop.name);
                    switch (prop.propertyType())
                    {
                        case ShaderPropertyType.Color: prop.colorValue = shader.GetPropertyDefaultVectorValue(index); break;
                        case ShaderPropertyType.Vector: prop.vectorValue = shader.GetPropertyDefaultVectorValue(index); break;
                        case ShaderPropertyType.Float: prop.floatValue = shader.GetPropertyDefaultFloatValue(index); break;
                        case ShaderPropertyType.Range: prop.floatValue = shader.GetPropertyDefaultFloatValue(index); break;
                        case ShaderPropertyType.Texture: prop.textureValue = prop.textureValue = shaderImporter ? shaderImporter.GetDefaultTexture(prop.name) : null; break;
                        case ShaderPropertyType.Int: prop.intValue = shader.GetPropertyDefaultIntValue(index); break;
                    }
                    DoKeyword(prop);
                }

                // プロパティの描画
                if (EditorGUI.indentLevel < closedDepth && !prop.propertyFlags().HasFlag(ShaderPropertyFlags.HideInInspector))
                {
                    // If処理
                    if (ifs.TryGetValue(prop.name, out var ifList))
                    {
                        if (ifList.Any(i => i.values.All(v => ((Material)materialEditor.targets[0]).GetInt(i.target) != v)))
                        {
                            if (clearCache.Contains(prop.name)) propertyCache.Clear();
                            continue;
                        }
                    }

                    // キャッシュ
                    if (needToCache.Contains(prop.name))
                    {
                        propertyCache.Add(prop);
                        continue;
                    }

                    if (clearCache.Contains(prop.name))
                    {
                        propertyCache.Clear();
                    }

                    // プロパティの描画
                    EditorGUI.BeginChangeCheck();
                    var count = propertyCache.Count;
                    if (prop.propertyType() == ShaderPropertyType.Texture)
                    {
                        bool hasScaleOffset = !prop.propertyFlags().HasFlag(ShaderPropertyFlags.NoScaleOffset);
                        if (hasScaleOffset) EditorGUI.indentLevel++;
                        Rect rect;
                        GUIContent label = L10n.G(prop.displayName);
                        if (count == 0 && MaterialGradientEditorCompatibility.IsGradientTexture(prop))
                        {
                            rect = EditorGUILayout.GetControlRect(false, EditorGUIUtility.singleLineHeight);
                            if (!MaterialGradientEditorCompatibility.TryDrawGradientTexture(rect, prop, label, materialEditor))
                            {
                                rect = materialEditor.TexturePropertySingleLine(label, prop);
                            }
                        }
                        else if (count == 0) rect = materialEditor.TexturePropertySingleLine(label, prop);
                        else if (count == 1) rect = materialEditor.TexturePropertySingleLine(label, prop, propertyCache[0]);
                        else rect = materialEditor.TexturePropertySingleLine(label, prop, propertyCache[0], propertyCache[1]);

                        if (hasScaleOffset)
                        {
                            bool isOpened = openedTextures.Contains(prop.name);
                            EditorGUI.BeginChangeCheck();
                            EditorGUI.Foldout(rect, isOpened, GUIContent.none);
                            if (EditorGUI.EndChangeCheck())
                            {
                                isOpened = !isOpened;
                                if (isOpened) openedTextures.Add(prop.name);
                                else openedTextures.Remove(prop.name);
                            }
                            if (isOpened)
                            {
                                EditorGUI.indentLevel += 2;
                                materialEditor.TextureScaleOffsetProperty(prop);
                                EditorGUI.indentLevel -= 2;
                            }
                            EditorGUI.indentLevel--;
                        }
                    }
                    else if (count > 0)
                    {
                        float propertyHeight = materialEditor.GetPropertyHeight(prop, prop.displayName);
                        Rect controlRect = EditorGUILayout.GetControlRect(true, propertyHeight, EditorStyles.layerMaskField);
                        float propWidth = (controlRect.width - EditorGUIUtility.labelWidth) / (count + 1);

                        controlRect.width = EditorGUIUtility.labelWidth + propWidth - propWidth * 0.5f - 4;
                        materialEditor.ShaderProperty(controlRect, prop, L10n.G(prop.displayName));
                        controlRect.x = controlRect.xMax + 4;
                        controlRect.width = propWidth + propWidth * 0.5f;
                        foreach (var p in propertyCache)
                        {
                            materialEditor.DefaultShaderProperty(controlRect, p, "");
                            controlRect.x += propWidth;
                        }
                    }
                    else
                    {
                        float propertyHeight = materialEditor.GetPropertyHeight(prop, prop.displayName);
                        Rect controlRect = EditorGUILayout.GetControlRect(true, propertyHeight, EditorStyles.layerMaskField);
                        materialEditor.ShaderProperty(controlRect, prop, L10n.G(prop.displayName));
                    }

                    // シェーダーキーワードのセット
                    if (EditorGUI.EndChangeCheck())
                    {
                        DoKeyword(prop);
                        foreach (var propc in propertyCache) DoKeyword(propc);
                    }

                    if (prop.name == "_ScreenSpaceAOSource")
                    {
                        EditorGUILayout.HelpBox(L10n.L("HTraceAO writes _ScreenSpaceOcclusionTexture. Insert HTraceAO before opaque/lit materials so this shader can read the AO result."), MessageType.Info);
                    }

                    propertyCache.Clear();
                }
            }
            closedDepth = int.MaxValue;
            copyDepth = int.MaxValue;
            pasteDepth = int.MaxValue;
            resetDepth = int.MaxValue;
            EditorGUIUtility.wideMode = wideMode;
            EditorGUI.indentLevel = indentLevel;

            // プロパティ以外の描画
            EditorGUILayout.Space(12);
            if (SupportedRenderingFeatures.active.editableMaterialRenderQueue)
            {
                materialEditor.RenderQueueField();
            }

            materialEditor.EnableInstancingField();
            materialEditor.DoubleSidedGIField();
        }

        private bool Initialize(MaterialEditor materialEditor)
        {
            var targetMaterial = materialEditor.target as Material;
            if (!targetMaterial || !targetMaterial.shader) return false;

            shader = targetMaterial.shader;
            if (!shaderGuiCaches.TryGetValue(shader, out var cache) || !cache.IsCurrent(shader))
            {
                cache = new ShaderGuiCache(shader);
                shaderGuiCaches[shader] = cache;
            }
            UseCache(cache);
            return foldoutStarts != null;
        }

        private static void SetKeywordIfChanged(Material mat, string keyword, bool enable)
        {
            if (mat.IsKeywordEnabled(keyword) == enable) return;
            if (enable) mat.EnableKeyword(keyword);
            else mat.DisableKeyword(keyword);
        }

        private class PropertyClipboard : ScriptableSingleton<PropertyClipboard>
        {
            public List<string> floatNames = new();
            public List<float> floatValues = new();
            public List<string> intNames = new();
            public List<int> intValues = new();
            public List<string> vectorNames = new();
            public List<Vector4> vectorValues = new();
            public List<string> textureNames = new();
            public List<Texture> textureValues = new();

            public static void Copy(string name, float value) => CopyInternal(instance.floatNames, instance.floatValues, name, value);
            public static void Copy(string name, int value) => CopyInternal(instance.intNames, instance.intValues, name, value);
            public static void Copy(string name, Vector4 value) => CopyInternal(instance.vectorNames, instance.vectorValues, name, value);
            public static void Copy(string name, Texture value) => CopyInternal(instance.textureNames, instance.textureValues, name, value);

            public static bool TryGet(string name, out float value) => TryGetInternal(instance.floatNames, instance.floatValues, name, out value);
            public static bool TryGet(string name, out int value) => TryGetInternal(instance.intNames, instance.intValues, name, out value);
            public static bool TryGet(string name, out Vector4 value) => TryGetInternal(instance.vectorNames, instance.vectorValues, name, out value);
            public static bool TryGet(string name, out Texture value) => TryGetInternal(instance.textureNames, instance.textureValues, name, out value);

            private static void CopyInternal<T>(List<string> names, List<T> values, string name, T value)
            {
                FitSize(names, values);
                var index = names.IndexOf(name);
                if (index >= 0) values[index] = value;
                else
                {
                    names.Add(name);
                    values.Add(value);
                }
            }

            private static bool TryGetInternal<T>(List<string> names, List<T> values, string name, out T value)
            {
                FitSize(names, values);
                var index = names.IndexOf(name);
                value = index != -1 ? values[index] : default;
                return index != -1;
            }

            private static void FitSize<T>(List<string> names, List<T> values)
            {
                if (names.Count > values.Count) names.RemoveRange(values.Count, names.Count - values.Count);
                if (values.Count > names.Count) values.RemoveRange(names.Count, values.Count - names.Count);
            }
        }

        private enum ProcessType
        {
            Copy,
            Paste,
            Reset
        }

        private sealed class ShaderGuiCache
        {
            public readonly Dictionary<string, List<LILFoldoutDecorator>> foldoutStarts = new();
            public readonly Dictionary<string, List<LILFoldoutEndDecorator>> foldoutEnds = new();
            public readonly Dictionary<string, List<LILIfDecorator>> ifs = new();
            public readonly Dictionary<string, int> boxStarts = new();
            public readonly Dictionary<string, int> boxEnds = new();
            public readonly Dictionary<string, string> keywords = new();
            public readonly HashSet<string> needToCache = new();
            public readonly HashSet<string> clearCache = new();
            public readonly ShaderImporter shaderImporter;
            private readonly string propertySignature;

            public ShaderGuiCache(Shader shader)
            {
                shaderImporter = AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(shader)) as ShaderImporter;
                propertySignature = CreatePropertySignature(shader);

                var count = shader.GetPropertyCount();
                for (int i = 0; i < count; i++)
                {
                    var name = shader.GetPropertyName(i);
                    var attributes = shader.GetPropertyAttributes(i);
                    foreach (var attr in attributes)
                    {
                        AddAttribute(name, attr);
                    }
                }
            }

            public bool IsCurrent(Shader shader) => propertySignature == CreatePropertySignature(shader);

            private static string CreatePropertySignature(Shader shader)
            {
                var builder = new StringBuilder();
                var count = shader.GetPropertyCount();
                builder.Append(count);
                for (int i = 0; i < count; i++)
                {
                    builder.Append('\n').Append(shader.GetPropertyName(i)).Append(':');
                    foreach (var attr in shader.GetPropertyAttributes(i))
                    {
                        builder.Append('[').Append(attr).Append(']');
                    }
                }
                return builder.ToString();
            }

            private void AddAttribute(string name, string attr)
            {
                if (TryGetAttributeArguments(attr, "LILFoldout", out var foldoutArgs))
                {
                    var args = SplitArguments(foldoutArgs);
                    var drawer = args.Count > 1 ? new LILFoldoutDecorator(args[0], args[1]) : new LILFoldoutDecorator(args.Count > 0 ? args[0] : name);
                    if (!foldoutStarts.TryGetValue(name, out var list)) list = new();
                    list.Add(drawer);
                    foldoutStarts[name] = list;
                    return;
                }

                if (attr == "LILFoldoutEnd")
                {
                    if (!foldoutEnds.TryGetValue(name, out var list)) list = new();
                    list.Add(new LILFoldoutEndDecorator());
                    foldoutEnds[name] = list;
                    return;
                }

                if (TryGetAttributeArguments(attr, "LILIf", out var ifArgs))
                {
                    var args = SplitArguments(ifArgs);
                    if (args.Count > 0)
                    {
                        var values = args.Skip(1).Select(ParseFloat).ToArray();
                        if (!ifs.TryGetValue(name, out var list)) list = new();
                        list.Add(new LILIfDecorator(args[0], values));
                        ifs[name] = list;
                    }
                    return;
                }

                if (attr == "LILBox")
                {
                    if (!boxStarts.TryGetValue(name, out var a)) a = 0;
                    boxStarts[name] = a + 1;
                    return;
                }

                if (attr == "LILBoxEnd")
                {
                    if (!boxEnds.TryGetValue(name, out var a)) a = 0;
                    boxEnds[name] = a + 1;
                    return;
                }

                if (TryGetAttributeArguments(attr, "LILKeyword", out var keywordArgs))
                {
                    var args = SplitArguments(keywordArgs);
                    if (args.Count > 0) keywords[name] = args[0];
                    return;
                }

                if (attr == "LILPropertyCache")
                {
                    needToCache.Add(name);
                    return;
                }

                if (attr == "LILPropertyCacheClear")
                {
                    clearCache.Add(name);
                }
            }

            private static bool TryGetAttributeArguments(string attr, string attributeName, out string args)
            {
                args = null;
                var prefix = attributeName + "(";
                if (!attr.StartsWith(prefix, StringComparison.Ordinal) || !attr.EndsWith(")", StringComparison.Ordinal)) return false;
                args = attr.Substring(prefix.Length, attr.Length - prefix.Length - 1);
                return true;
            }

            private static List<string> SplitArguments(string args)
            {
                return args.Split(',')
                    .Select(a => a.Trim())
                    .Where(a => a.Length > 0)
                    .ToList();
            }

            private static float ParseFloat(string value)
            {
                return float.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var result) ? result : 0f;
            }
        }
    }

    internal static class MaterialGradientEditorCompatibility
    {
        private const string ApiTypeName = "lilToon.URP.Extensions.Editor.MaterialGradient.HoMaterialGradientEditorApi";
        private const string ApiAssemblyName = "jp.lilxyzw.liltoon.urp.extensions.Editor";
        private static MethodInfo isGradientTextureMethod;
        private static MethodInfo tryDrawGradientTextureMethod;
        private static bool initialized;
        private static bool disabled;
        private static bool loggedFailure;

        public static bool IsGradientTexture(MaterialProperty property)
        {
            if (!EnsureInitialized()) return false;

            try
            {
                return (bool)isGradientTextureMethod.Invoke(null, new object[] { property });
            }
            catch (TargetInvocationException e) when (e.InnerException is ExitGUIException)
            {
                ExceptionDispatchInfo.Capture(e.InnerException).Throw();
                throw;
            }
            catch (TargetInvocationException e)
            {
                DisableAfterFailure(e.InnerException ?? e);
                return false;
            }
            catch (Exception e)
            {
                DisableAfterFailure(e);
                return false;
            }
        }

        public static bool TryDrawGradientTexture(Rect rect, MaterialProperty property, GUIContent label, MaterialEditor editor)
        {
            if (!EnsureInitialized()) return false;

            try
            {
                return (bool)tryDrawGradientTextureMethod.Invoke(null, new object[] { rect, property, label, editor });
            }
            catch (TargetInvocationException e) when (e.InnerException is ExitGUIException)
            {
                ExceptionDispatchInfo.Capture(e.InnerException).Throw();
                throw;
            }
            catch (TargetInvocationException e)
            {
                DisableAfterFailure(e.InnerException ?? e);
                return false;
            }
            catch (Exception e)
            {
                DisableAfterFailure(e);
                return false;
            }
        }

        private static bool EnsureInitialized()
        {
            if (disabled) return false;
            if (initialized) return isGradientTextureMethod != null && tryDrawGradientTextureMethod != null;

            initialized = true;
            Type apiType = Type.GetType(ApiTypeName + ", " + ApiAssemblyName);
            if (apiType == null)
            {
                apiType = AppDomain.CurrentDomain.GetAssemblies()
                    .Select(assembly => assembly.GetType(ApiTypeName))
                    .FirstOrDefault(type => type != null);
            }

            if (apiType == null) return false;

            isGradientTextureMethod = apiType.GetMethod(
                "IsGradientTexture",
                BindingFlags.Public | BindingFlags.Static,
                null,
                new[] { typeof(MaterialProperty) },
                null);

            tryDrawGradientTextureMethod = apiType.GetMethod(
                "TryDrawGradientTexture",
                BindingFlags.Public | BindingFlags.Static,
                null,
                new[] { typeof(Rect), typeof(MaterialProperty), typeof(GUIContent), typeof(MaterialEditor) },
                null);

            return isGradientTextureMethod != null && tryDrawGradientTextureMethod != null;
        }

        private static void DisableAfterFailure(Exception exception)
        {
            disabled = true;
            if (loggedFailure) return;
            loggedFailure = true;
            Debug.LogException(exception);
        }
    }

    internal static class Unity2022Suppport
    {
        public static ShaderPropertyType propertyType(this MaterialProperty property)
        {
            #if UNITY_6000_0_OR_NEWER
            return property.propertyType;
            #else
            return (ShaderPropertyType)property.type;
            #endif
        }
        public static ShaderPropertyFlags propertyFlags(this MaterialProperty property)
        {
            #if UNITY_6000_0_OR_NEWER
            return property.propertyFlags;
            #else
            return (ShaderPropertyFlags)property.flags;
            #endif
        }
    }
}
