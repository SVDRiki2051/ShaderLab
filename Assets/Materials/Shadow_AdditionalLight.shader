Shader "Unlit/Shadow_AdditionalLight"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        [KeywordEnum(ON,OFF)]_ADD_LIGHT("AddLight",Float)=1
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            half4 _BaseColor;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct a2v
        {
            float4 positionOS:POSITION;
            float4 normalOS:NORMAL;
            float2 texcoord:TEXCOORD0;
        };

        struct v2f
        {
            float4 positionCS:SV_POSITION;
            float2 texcoord:TEXCOORD0;
            float3 WS_N:NORMAL;
            float3 WS_V:TEXCOORD1;
            float3 WS_P:TEXCOORD2;
        };
        ENDHLSL

        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex VERT;
            #pragma fragment FRAG;
            #pragma shader_feature _ADD_LIGHT_ON _ADD_LIGHT_OFF
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT

            v2f VERT(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord = TRANSFORM_TEX(i.texcoord, _MainTex);
                o.WS_N = normalize(TransformObjectToWorldNormal(i.normalOS.xyz));
                o.WS_V = normalize(_WorldSpaceCameraPos - TransformObjectToWorld(i.positionOS.xyz));
                o.WS_P = TransformObjectToWorld(i.positionOS);
                return o;
            }

            half4 FRAG(v2f i):SV_TARGET
            {
                half4 shadowTexcoord = TransformWorldToShadowCoord(i.WS_P);
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord) * _BaseColor;
                Light mlight = GetMainLight(shadowTexcoord);
                float3 WS_Light = normalize(mlight.direction);
                float3 WS_Normal = i.WS_N;
                float3 WS_View = i.WS_V;
                float3 WS_H = normalize(WS_Light + WS_View);
                float3 WS_POS = i.WS_P;

                //calculate mainlight
                float4 maincolor = (dot(WS_Light, WS_Normal) * 0.5 + 0.5) * tex * float4(mlight.color, 1) * mlight.
                    shadowAttenuation;

                //calculate addlight
                half4 addcolor = half4(0, 0, 0, 1);
                #if _ADD_LIGHT_ON
                    int addLightCounts = GetAdditionalLightsCount();
                    for (int index = 0; index < addLightCounts; index++)
                    {
                        Light addlight = GetAdditionalLight(index, WS_POS);
                        float3 WS_addLightDir = normalize(addlight.direction);
                        addcolor += (dot(WS_addLightDir, WS_Normal) * 0.5 + 0.5) * half4(addlight.color, 1) * tex * addlight.
                            distanceAttenuation * addlight.shadowAttenuation;
                    }
                #else
                    addcolor=half4(0,0,0,1);
                #endif

                return maincolor + addcolor;
            }
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"
    }
}