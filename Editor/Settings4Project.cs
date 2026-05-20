using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.UIElements;

namespace jp.lilxyzw.lilpbr
{
    [FilePath("ProjectSettings/jp.lilxyzw.lilpbr.asset", FilePathAttribute.Location.ProjectFolder)]
    internal class Settings4Project : ScriptableSingleton<Settings4Project>
    {
        public string[] layerNames = new string[32];
        internal void Save()
        {
            displayLayerNames = null;
            displayLayerContents = null;
            Save(true);
        }

        private static string LayerName(int i)
        {
            if (instance.layerNames.Length > i) return $"{i}: {instance.layerNames[i]}";
            return $"{i}:";
        }

        private static string[] displayLayerNames;
        public static string[] DisplayLayerNames => displayLayerNames ??= Enumerable.Range(0, 32).Select(i => LayerName(i)).ToArray();

        private static GUIContent[] displayLayerContents;
        public static GUIContent[] DisplayLayerContents => displayLayerContents ??= Enumerable.Range(0, 32).Select(i => new GUIContent(LayerName(i))).ToArray();
    }

    [CustomEditor(typeof(Settings4Project))]
    public class Settings4ProjectEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            EditorGUI.BeginChangeCheck();
            serializedObject.UpdateIfRequiredOrScript();
            SerializedProperty iterator = serializedObject.GetIterator();
            iterator.NextVisible(true); // m_Script
            int depth = 0;

            while (iterator.NextVisible(false))
            {
                if (iterator.name == "layerNames")
                {
                    if (iterator.arraySize != 32) iterator.arraySize = 32;
                    EditorGUILayout.LabelField(L10n.G("Layer Names"));
                    iterator.NextVisible(true);
                    iterator.NextVisible(true);
                    depth = iterator.depth;
                    EditorGUI.indentLevel++;
                }

                if (depth != 0 && depth != iterator.depth)
                {
                    depth = 0;
                    EditorGUI.indentLevel--;
                }
                EditorGUILayout.PropertyField(iterator);
            }

            if(EditorGUI.EndChangeCheck())
            {
                serializedObject.ApplyModifiedProperties();
                Settings4Project.instance.Save();
            }
        }
    }

    internal class Settings4ProjectProvider : SettingsProvider
    {
        public ScriptableObject SO => Settings4Project.instance;
        private Editor _editor;

        public Settings4ProjectProvider(string path, SettingsScope scopes, IEnumerable<string> keywords) : base(path, scopes, keywords){}
        [SettingsProvider] public static SettingsProvider Create() => new Settings4ProjectProvider("Project/lilPBR", SettingsScope.Project, null);

        public override void OnActivate(string searchContext, VisualElement rootElement)
        {
            SO.hideFlags = HideFlags.HideAndDontSave & ~HideFlags.NotEditable;
            Editor.CreateCachedEditor(SO, null, ref _editor);
        }

        public override void OnGUI(string searchContext) => _editor.OnInspectorGUI();
    }
}
