using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace jp.lilxyzw.lilpbr
{
    internal abstract class ZeroHeightDrawer : MaterialPropertyDrawer
    {
        public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor) {}
        public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor) => 0;
    }

    internal abstract class EzDrawer : MaterialPropertyDrawer
    {
        public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            MaterialEditor.BeginProperty(position, prop);
            EditorGUI.BeginChangeCheck();
            OnGUIEz(position, prop, label, editor);
            MaterialEditor.EndProperty();
        }

        protected abstract void OnGUIEz(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor);
    }

    internal class LILKeywordDecorator : ZeroHeightDrawer
    {
        public readonly string keyword;
        public LILKeywordDecorator(string keyword) => this.keyword = keyword;
    }

    internal class LILPropertyCacheDecorator : ZeroHeightDrawer { }
    internal class LILPropertyCacheClearDecorator : ZeroHeightDrawer { }

    internal class LILFoldoutDecorator : ZeroHeightDrawer
    {
        public readonly string label;
        public readonly string keyword;
        public LILFoldoutDecorator(string label) => this.label = label;
        public LILFoldoutDecorator(string label, string keyword)
        {
            this.label = label;
            this.keyword = keyword;
        }
    }

    internal class LILFoldoutEndDecorator : ZeroHeightDrawer { }
    internal class LILBoxDecorator : ZeroHeightDrawer { }
    internal class LILBoxEndDecorator : ZeroHeightDrawer { }

    internal class LILIfDecorator : ZeroHeightDrawer
    {
        public readonly string target;
        public readonly int[] values;
        public LILIfDecorator(string target, params float[] values)
        {
            this.target = target;
            this.values = values.Select(v => (int)v).ToArray();
        }
    }

    internal class LILRenderModeDrawer : EzDrawer
    {
        private static GUIContent[] options = { L10n.G("Opaque"), L10n.G("Cutout"), L10n.G("Dither"), L10n.G("Transparent") };
        protected override void OnGUIEz(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            var value = EditorGUI.Popup(position, label, (int)prop.floatValue, options);
            if (EditorGUI.EndChangeCheck())
            {
                prop.floatValue = value;
                var queue = -1;
                var zwrite = 1;
                string renderType = "";
                switch (value)
                {
                    case 0: queue = -1; zwrite = 1; renderType = ""; break;
                    case 1: queue = 2450; zwrite = 1; renderType = "TransparentCutout"; break;
                    case 2: queue = 2450; zwrite = 1; renderType = "TransparentCutout"; break;
                    case 3: queue = 3000; zwrite = 0; renderType = "Transparent"; break;
                }
                foreach (Material mat in editor.targets)
                {
                    mat.renderQueue = queue;
                    mat.SetFloat("_ZWrite", zwrite);
                    mat.SetFloat("_AlphaToMask", value == 1 ? 1 : 0);
                    mat.SetFloat("_SrcBlend", value == 3 ? (float)BlendMode.One : (float)BlendMode.One);
                    mat.SetFloat("_DstBlend", value == 3 ? (float)BlendMode.OneMinusSrcAlpha : (float)BlendMode.Zero);
                    mat.SetFloat("_SrcBlendAlpha", value == 3 ? (float)BlendMode.One : (float)BlendMode.One);
                    mat.SetFloat("_DstBlendAlpha", value == 3 ? (float)BlendMode.OneMinusSrcAlpha : (float)BlendMode.Zero);
                    mat.SetKeyword("_CUTOUT", value == 1);
                    mat.SetKeyword("_DITHER", value == 2);
                    mat.SetKeyword("_TRANSPARENT", value == 3);
                    mat.SetOverrideTag("RenderType", renderType);
                }
            }
        }
    }

    internal class LILVector3Drawer : EzDrawer
    {
        protected override void OnGUIEz(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            var value = EditorGUI.Vector3Field(position, label, prop.vectorValue);
            if (EditorGUI.EndChangeCheck()) prop.vectorValue = value;
        }
    }

    internal class LILVector2Drawer : EzDrawer
    {
        protected override void OnGUIEz(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            Vector4 current = prop.vectorValue;
            var value = EditorGUI.Vector2Field(position, label, new Vector2(current.x, current.y));
            if (EditorGUI.EndChangeCheck()) prop.vectorValue = new Vector4(value.x, value.y, current.z, current.w);
        }
    }

    internal class LILShaderLayerOneDrawer : EzDrawer
    {
        protected override void OnGUIEz(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            var value = EditorGUI.Popup(position, label, (int)prop.floatValue, Settings4Project.DisplayLayerContents);
            if (EditorGUI.EndChangeCheck()) prop.floatValue = value;
            if (GUILayout.Button("Open Shader Layer Setting")) SettingsService.OpenProjectSettings("Project/lilPBR");
        }
    }

    internal class LILHDRDrawer : EzDrawer
    {
        protected override void OnGUIEz(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            var value = EditorGUI.ColorField(position, label, prop.colorValue, true, true, true);
            if (EditorGUI.EndChangeCheck()) prop.colorValue = value;
        }
    }

    [CustomPropertyDrawer(typeof(runtime.ShaderLayerAttribute))]
    internal class LILShaderLayerDrawer : PropertyDrawer
    {
        public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
        {
            label = EditorGUI.BeginProperty(position, label, property);
            EditorGUI.BeginChangeCheck();
            var value = EditorGUI.MaskField(position, label, property.intValue, Settings4Project.DisplayLayerNames);
            if (EditorGUI.EndChangeCheck()) property.intValue = value;
            EditorGUI.EndProperty();

            if (GUILayout.Button("Open Shader Layer Setting")) SettingsService.OpenProjectSettings("Project/lilPBR");
        }
    }
}
