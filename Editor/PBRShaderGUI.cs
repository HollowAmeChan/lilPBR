using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace jp.lilxyzw.lilpbr
{
    internal class PBRShaderGUI : ShaderGUI
    {
        private static Dictionary<string, List<LILFoldoutDecorator>> foldoutStarts;
        private static Dictionary<string, List<LILFoldoutEndDecorator>> foldoutEnds;
        private static Dictionary<string, List<LILIfDecorator>> ifs;
        private static Dictionary<string, int> boxStarts;
        private static Dictionary<string, int> boxEnds;
        private static Dictionary<string, string> keywords;
        private static HashSet<string> needToCache;
        private static HashSet<string> clearCache;
        void InitializeLists()
        {
            foldoutStarts = new();
            foldoutEnds = new();
            ifs = new();
            boxStarts = new();
            boxEnds = new();
            keywords = new();
            needToCache = new();
            clearCache = new();
        }
        private static readonly MethodInfo M_GetShaderPropertyDrawer = typeof(Editor).Assembly.GetType("UnityEditor.MaterialPropertyHandler").GetMethod("GetShaderPropertyDrawer", BindingFlags.NonPublic | BindingFlags.Static);
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
            Initialize(materialEditor);

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
                                prop.propertyType() == ShaderPropertyType.Texture && prop.textureValue) mat.EnableKeyword(keyword);
                            else mat.DisableKeyword(keyword);
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

                    // If処理
                    if (ifs.TryGetValue(prop.name, out var ifList))
                    {
                        if (ifList.Any(i => i.values.All(v => ((Material)materialEditor.targets[0]).GetInt(i.target) != v))) continue;
                    }

                    // プロパティの描画
                    EditorGUI.BeginChangeCheck();
                    var count = propertyCache.Count;
                    if (prop.propertyType() == ShaderPropertyType.Texture)
                    {
                        if (!prop.propertyFlags().HasFlag(ShaderPropertyFlags.NoScaleOffset)) EditorGUI.indentLevel++;
                        Rect rect;
                        GUIContent label = L10n.G(prop.displayName);
                        if (count == 0) rect = materialEditor.TexturePropertySingleLine(label, prop);
                        else if (count == 1) rect = materialEditor.TexturePropertySingleLine(label, prop, propertyCache[0]);
                        else rect = materialEditor.TexturePropertySingleLine(label, prop, propertyCache[0], propertyCache[1]);

                        if (!prop.propertyFlags().HasFlag(ShaderPropertyFlags.NoScaleOffset))
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

        private void Initialize(MaterialEditor materialEditor)
        {
            if (shader != (materialEditor.target as Material).shader)
            {
                shader = (materialEditor.target as Material).shader;
                shaderImporter = AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(shader)) as ShaderImporter;
                InitializeLists();

                var count = shader.GetPropertyCount();
                for (int i = 0; i < count; i++)
                {
                    var name = shader.GetPropertyName(i);
                    var attributes = shader.GetPropertyAttributes(i);
                    foreach (var attr in attributes)
                    {
                        if (M_GetShaderPropertyDrawer.Invoke(null, new object[] { attr, null }) is not MaterialPropertyDrawer drawer) continue;
                        if (drawer is LILFoldoutDecorator start)
                        {
                            if (!foldoutStarts.TryGetValue(name, out var list)) list = new();
                            list.Add(start);
                            foldoutStarts[name] = list;
                        }
                        if (drawer is LILFoldoutEndDecorator end)
                        {
                            if (!foldoutEnds.TryGetValue(name, out var list)) list = new();
                            list.Add(end);
                            foldoutEnds[name] = list;
                        }
                        if (drawer is LILIfDecorator ifdeco)
                        {
                            if (!ifs.TryGetValue(name, out var list)) list = new();
                            list.Add(ifdeco);
                            ifs[name] = list;
                        }
                        if (drawer is LILBoxDecorator)
                        {
                            if (!boxStarts.TryGetValue(name, out var a)) a = 0;
                            boxStarts[name] = a + 1;
                        }
                        if (drawer is LILBoxEndDecorator)
                        {
                            if (!boxEnds.TryGetValue(name, out var a)) a = 0;
                            boxEnds[name] = a + 1;
                        }
                        if (drawer is LILKeywordDecorator keyword)
                        {
                            keywords[name] = keyword.keyword;
                        }
                        if (drawer is LILPropertyCacheDecorator)
                        {
                            needToCache.Add(name);
                        }
                        if (drawer is LILPropertyCacheClearDecorator)
                        {
                            clearCache.Add(name);
                        }
                    }
                }
            }
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
