Shader "Silent/QuestWater"
{
    Properties
    {
        [Header(Wave Settings)]
        [NoScaleOffset] _BumpMap ("1st Normalmap", 2D) = "bump" {}
        _BumpProps1("1st Properties", Vector) = (0, 0, 1, 0.1)
        [NoScaleOffset] _BumpMap2 ("2nd Normalmap", 2D) = "bump" {}
        _BumpProps2("2nd Properties", Vector) = (0, 0, 1, 0.01)
        _Shininess ("Shininess", Range (0.03, 1)) = 0.078125
        _ShininessExp ("Shininess Exp", Range (0, 1)) = 0.15
        _SpecIntensity ("Specular Intensity", Range (1, 100)) = 12
        [Header(Reflection Settings)]
        _ReflTex ("Reflection Cubemap", CUBE) = "white" {}
        _IORConstant ("IOR", Range (0, 1)) = 0.3
        _InteriorColour("Interior Colour", Color) = (0, 0, 0, 0)
        [HideInInspector]__dummy ("Unused", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 250

        CGPROGRAM
        #pragma surface surf MobileBlinnPhong exclude_path:prepass nolightmap noforwardadd noambient
        // Target 4.0 to force availability of precise operations, because Quest supports them
        #pragma target 4.0

        sampler2D _BumpMap;
        sampler2D _BumpMap2;
        UNITY_DECLARE_TEXCUBE(_ReflTex);
        half _Shininess;
        half _ShininessExp;
        half _SpecIntensity;
        half _IORConstant;
        // XY scroll, Z scale, W strength
        fixed4 _BumpProps1;
        fixed4 _BumpProps2;
        fixed4 _InteriorColour;

        // refractionValues, x = index of refraction constant, y = refraction strength
        // normal and eyeVec in world space
        half FresnelValue(float R0, float3 normal, float3 eyeVec)
        {
            return R0 + (1.0f - R0) * pow(1.0f - dot(eyeVec, normal), 5.0f);
        }

        // lightDir, eyeDir and normal in world space
        half3 ReflectedRadiance(float shininess, float shininessExp, float specularIntensityIn, half3 lightColor, float3 lightDir, float3 eyeDir, float3 normal, float fresnel)
        {
            float specularIntensity = specularIntensityIn * 0.0075;
            float3 H = normalize(eyeDir + lightDir);
            float e = shininess * shininessExp * 800;
            float kS = saturate(dot(normal, lightDir));
            half3 specular = kS * specularIntensity * pow(saturate(dot(normal, H)), e) * sqrt((e + 1) / 2);
            specular *= lightColor;
            return specular;
        }

        // V, N, Tx, Ty in world space
        float3 U3(float2 zeta, float3 V, float3 N, float3 Tx, float3 Ty)
        {
            float3 f = normalize(float3(-zeta, 1.0)); // tangent space
            float3 F = f.x * Tx + f.y * Ty + f.z * N; // world space
            float3 R = 2.0 * dot(F, V) * F - V;
            return R;
        }
        
        // viewDir and normal in world space
        half3 MeanSkyRadiance(UNITY_ARGS_TEXCUBE(tex), float3 viewDir, half3 normal)
        {
            if (dot(viewDir, normal) < 0.0)
            {
                normal = reflect(normal, viewDir);
            }
            float3 ty = normalize(float3(0.0, normal.z, -normal.y));
            float3 tx = cross(ty, normal);
        
            const float eps = 0.001;
            float3 u0 = U3(float2(0, 0), viewDir, normal, tx, ty);
            float2 dux = 2.0 * (float2(eps, 0.0) - u0) / eps;
            float2 duy = 2.0 * (float2(0, eps) - u0) / eps;
            return UNITY_SAMPLE_TEXCUBE(tex, u0).rgb;
        }

        inline fixed4 LightingMobileBlinnPhong (SurfaceOutput s, fixed3 lightDir, fixed3 halfDir, fixed atten)
        {
            half fresnel = FresnelValue(_IORConstant, s.Normal, halfDir);
            fixed4 c;
            c.rgb = MeanSkyRadiance(UNITY_PASS_TEXCUBE(_ReflTex), halfDir, s.Normal)*fresnel;
            c.rgb = lerp(_InteriorColour, c.rgb, fresnel);
            c.rgb += ReflectedRadiance(_Shininess, _ShininessExp, _SpecIntensity, 
                _LightColor0.rgb, _WorldSpaceLightPos0, halfDir, s.Normal, fresnel);
            UNITY_OPAQUE_ALPHA(c.a);
            return c;
        }

        struct Input
        {
            float2 uv__dummy;
            float4 color : COLOR;
        };

        void surf (Input IN, inout SurfaceOutput o)
        {
            o.Specular = _Shininess;
            float2 scroll2   = _Time.y * _BumpProps2.xy;
            float2 secondUVs = (_BumpProps2.z * IN.uv__dummy + scroll2);
            half3 normal2 = UnpackScaleNormal (tex2D(_BumpMap2, secondUVs), _BumpProps2.w);

            float2 scroll1   = _Time.y * _BumpProps1.xy;
            float2 firstUVs  = (_BumpProps1.z * IN.uv__dummy + scroll1);
            half3 normal1 = UnpackScaleNormal (tex2D(_BumpMap, firstUVs + normal2 ), _BumpProps1.w);
            o.Normal = normal1;
        }
        ENDCG
    }

    FallBack "Mobile/VertexLit"
}
