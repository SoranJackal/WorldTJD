Shader "Silent/QuestWater Transparent"
{
    Properties
    {
        [Header(Wave Settings)]
        [NoScaleOffset] _BumpMap ("Wave Normal Map", 2D) = "bump" {}
        _BumpScrollX1("Wave Scroll Speed X", Float) = 0
        _BumpScrollY1("Wave Scroll Speed Y", Float) = 0
        _BumpScale1("Wave Scale", Float) = 1
        _BumpStrength1("Wave Bump Strength", Float) = 0.05
        [NoScaleOffset] _BumpMap2 ("Offset Normal Map", 2D) = "bump" {}
        _BumpScrollX2("Offset Scroll Speed X", Float) = 0
        _BumpScrollY2("Offset Scroll Speed Y", Float) = 0
        _BumpScale2("Offset Scale", Float) = 1
        _BumpStrength2("Offset Bump Strength", Float) = 0.1
        [Header(Specular Settings)]
        _Shininess ("Shininess", Range (0.03, 1)) = 0.078125
        _ShininessExp ("Shininess Exp", Range (0, 1)) = 0.15
        _SpecIntensity ("Specular Intensity", Range (1, 100)) = 12
        [Header(Reflection Settings)]
        _ReflTex ("Reflection Cubemap", CUBE) = "white" {}
        _InteriorColour("Interior Colour", Color) = (0, 0, 0, 0)
        _IORConstant ("IOR Constant (def: 0.3)", Range (0, 1)) = 0.3
        _Opacity("Edge Opacity", Range(0, 1)) = 1
        _InteriorOpacity("Interior Opacity", Range(0, 1)) = 0
        [HideInInspector]__dummy ("Unused", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "Queue"="Transparent -1" "IgnoreProjector"="False" "RenderType"="Transparent" }
        ZWrite Off
        LOD 250

        CGPROGRAM
        #pragma surface surf MobileWater exclude_path:prepass nolightmap noforwardadd noambient alpha
        // Target 4.0 to force availability of precise operations, because Quest supports them
        #pragma target 4.0

        UNITY_DECLARE_TEX2D(_BumpMap);
        UNITY_DECLARE_TEX2D(_BumpMap2);
        UNITY_DECLARE_TEXCUBE(_ReflTex);
        half _Shininess;
        half _ShininessExp;
        half _SpecIntensity;
        half _IORConstant;
        fixed4 _InteriorColour;
        half _Opacity;
        half _InteriorOpacity;

        half _BumpScrollX1;
        half _BumpScrollY1;
        half _BumpScale1;
        half _BumpStrength1;
        half _BumpScrollX2;
        half _BumpScrollY2;
        half _BumpScale2;
        half _BumpStrength2;

        // normal and eyeVec in world space
        half FresnelValue(float R0, float3 normal, float3 eyeVec)
        {
            return R0 + (1.0f - R0) * pow(1.0f - dot(eyeVec, normal), 5.0f);
        }

        // lightDir, eyeDir and normal in world space
        half3 ReflectedRadiance(float shininess, float shininessExp, float specularIntensityIn, 
            half3 lightColor, float3 lightDir, float3 eyeDir, float3 normal, float fresnel)
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

        inline fixed4 LightingMobileWater (SurfaceOutput s, fixed3 lightDir, fixed3 halfDir, fixed atten)
        {
            half fresnel = FresnelValue(_IORConstant, s.Normal, halfDir);
            fixed4 c = 1.0;
            c.rgb = MeanSkyRadiance(UNITY_PASS_TEXCUBE(_ReflTex), halfDir, s.Normal)*fresnel;
            c.rgb = lerp(_InteriorColour, c.rgb, fresnel);
            c.rgb += ReflectedRadiance(_Shininess, _ShininessExp, _SpecIntensity, 
                _LightColor0.rgb, _WorldSpaceLightPos0, halfDir, s.Normal, fresnel);
            c.a = lerp(_InteriorOpacity, _Opacity, fresnel);
            return c;
        }

        struct Input
        {
            float2 uv__dummy;
            float3 worldPos;
            float4 color : COLOR;
        };

        void surf (Input IN, inout SurfaceOutput o)
        {
            o.Specular = _Shininess;

            float2 scroll2   = _Time.y * float2(_BumpScrollX2, _BumpScrollY2) * 0.1;
            float2 secondUVs = (_BumpScale2 * IN.uv__dummy + scroll2);
            half3 normal2 = UnpackScaleNormal (UNITY_SAMPLE_TEX2D(_BumpMap2, secondUVs), _BumpStrength2);

            float2 scroll1   = _Time.y * float2(_BumpScrollX1, _BumpScrollY1) * 0.1;
            float2 firstUVs  = (_BumpScale1 * IN.uv__dummy + scroll1);
            half3 normal1 = UnpackScaleNormal (UNITY_SAMPLE_TEX2D(_BumpMap, firstUVs + normal2 ), _BumpStrength1);
            o.Normal = normal1;
            o.Alpha = 0;
        }
        ENDCG
    }

}
