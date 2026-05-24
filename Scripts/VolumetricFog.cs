using UnityEngine;

namespace jp.lilxyzw.lilpbr.runtime
{
    [ExecuteAlways]
    public class VolumetricFog : MonoBehaviour
    {
        public Texture2D _Noise;
        [Range(0,1)] public float _Density = 0.25f;
        public float _ScrollX = 1f;
        public float _ScrollZ = 1f;
        public float _HeightScale = 8f;
        public float _HeightOffset = -1f;
        public float _HeightSharpness = 0.3f;
        int _ID_VFogNoise;
        int _ID_VFogDensity;
        int _ID_VFogScrollX;
        int _ID_VFogScrollZ;
        int _ID_VFogHeightScale;
        int _ID_VFogHeightOffset;
        int _ID_VFogHeightSharpness;

        void OnEnable()
        {
            _ID_VFogNoise = Shader.PropertyToID("_VFogNoise");
            _ID_VFogDensity = Shader.PropertyToID("_VFogDensity");
            _ID_VFogScrollX = Shader.PropertyToID("_VFogScrollX");
            _ID_VFogScrollZ = Shader.PropertyToID("_VFogScrollZ");
            _ID_VFogHeightScale = Shader.PropertyToID("_VFogHeightScale");
            _ID_VFogHeightOffset = Shader.PropertyToID("_VFogHeightOffset");
            _ID_VFogHeightSharpness = Shader.PropertyToID("_VFogHeightSharpness");
            SetVariables();
        }

        void OnDisable()
        {
            ResetVariables();
        }

        void OnValidate()
        {
            if (isActiveAndEnabled) SetVariables();
            else ResetVariables();
        }

        public void SetVariables()
        {
            Shader.SetGlobalTexture(_ID_VFogNoise, _Noise);
            Shader.SetGlobalFloat(_ID_VFogDensity, _Density);
            Shader.SetGlobalFloat(_ID_VFogScrollX, _ScrollX);
            Shader.SetGlobalFloat(_ID_VFogScrollZ, _ScrollZ);
            Shader.SetGlobalFloat(_ID_VFogHeightScale, _HeightScale);
            Shader.SetGlobalFloat(_ID_VFogHeightOffset, _HeightOffset);
            Shader.SetGlobalFloat(_ID_VFogHeightSharpness, _HeightSharpness);
        }

        public void ResetVariables()
        {
            Shader.SetGlobalTexture(_ID_VFogNoise, null);
            Shader.SetGlobalFloat(_ID_VFogDensity, 0);
            Shader.SetGlobalFloat(_ID_VFogScrollX, 0);
            Shader.SetGlobalFloat(_ID_VFogScrollZ, 0);
            Shader.SetGlobalFloat(_ID_VFogHeightScale, 0);
            Shader.SetGlobalFloat(_ID_VFogHeightOffset, 0);
            Shader.SetGlobalFloat(_ID_VFogHeightSharpness, 0);
        }
    }
}
