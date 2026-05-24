using UnityEngine;

namespace jp.lilxyzw.lilpbr.runtime
{
    [ExecuteAlways]
    public class ShaderLayerSetter : MonoBehaviour
    {
        [ShaderLayer] public int hiddenLayers;
        int _ID_HideShaderLayer;

        void OnEnable()
        {
            _ID_HideShaderLayer = GetPropertyID();
        }

        void OnPreRender()
        {
            SetHiddenLayers(_ID_HideShaderLayer, hiddenLayers);
        }

        void OnPostRender()
        {
            SetHiddenLayers(_ID_HideShaderLayer, 0);
        }

        public void SetHiddenLayers(int id, int hiddenLayers) => Shader.SetGlobalInteger(id, hiddenLayers);

        public int GetPropertyID() => Shader.PropertyToID("_HideShaderLayer");
    }
}
