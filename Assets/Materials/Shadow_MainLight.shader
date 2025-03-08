Shader "Unlit/MainLightShadow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _Gloss("gloss",Range(10,300))=20
        _SpecularColor("SpecularColor",Color)=(1,1,1,1)
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
        half _Gloss;
        half4 _SpecularColor;
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
            float3 normalWS:NORMAL;
            float2 texcoord:TEXCOORD0;
            float3 positionWS:TEXCOORD1;
        };
        ENDHLSL

        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }
            
            HLSLPROGRAM
            #pragma vertex VERT
            #pragma fragment FRAG
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS   //_MAIN_LIGHT_SHADOWS会定义MAIN_LIGHT_CALCULATE_SHADOWS及其他关键字，这样才能计算阴影衰减
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE   //定义关键字，得到正确的阴影坐标
            #pragma multi_compile _ _SHADOWS_SOFT  //柔化阴影，得到软阴影

            v2f VERT(a2v i)
            {
                v2f o;
                o.positionCS=TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);
                o.positionWS=TransformObjectToWorld(i.positionOS.xyz);
                o.normalWS=TransformObjectToWorldNormal(i.normalOS);
                return o;
            }

            half4 FRAG(v2f i):SV_TARGET
            {
                half4 tex=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord)*_BaseColor;
                Light mlight=GetMainLight(TransformWorldToShadowCoord(i.positionWS));   //重载的GetMainLight
                float3 WS_L=normalize(mlight.direction);
                float3 WS_N=normalize(i.normalWS);
                float3 WS_V=normalize(_WorldSpaceCameraPos-i.positionWS);
                float3 WS_H=normalize(WS_L+WS_V);
                tex*=(dot(WS_L,WS_N)*0.5+0.5)*mlight.shadowAttenuation*half4(mlight.color,1);  //漫反射算上阴影衰减和光颜色
                float4 Specular=pow(saturate(dot(WS_H,WS_N)),_Gloss)*_SpecularColor*mlight.shadowAttenuation;  //高光反射算上阴影衰减
                return tex+Specular;
            }
            ENDHLSL
        }
        
        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"
    }
}
