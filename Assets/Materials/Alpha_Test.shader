Shader "Unlit/Alpha_Test"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("Color",Color)=(1,1,1,1)
        _CutOff("Alpha CutOff",Range(0,1))=0.6
        _AlphaTex("Alpha Test",2D)="White"{}
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "Queue"="AlphaTest"
        }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _BaseColor;
        float _CutOff;
        float4 _AlphaTex_ST;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_AlphaTex);
        SAMPLER(sampler_AlphaTex);

        struct a2v
        {
            float4 positionOS:POSITION;
            float2 texcoord:TEXCOORD0;
            float3 normalOS:NORMAL;
        };

        struct v2f
        {
            float4 positionCS:SV_POSITION;
            float4 texcoord:TEXCOORD0;
            float3 normalWS:NORMAL;
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

            v2f VERT(a2v i)
            {
                v2f o;
                o.positionCS=TransformObjectToHClip(i.positionOS);
                o.texcoord.xy=TRANSFORM_TEX(i.texcoord,_MainTex);
                o.texcoord.zw=TRANSFORM_TEX(i.texcoord,_AlphaTex);
                o.normalWS=normalize(TransformObjectToWorldNormal(i.normalOS));
                return o;
            }

            half4 FRAG(v2f i):SV_TARGET
            {
                Light mlight=GetMainLight();
                half4 LightColor=half4(mlight.color,1);
                float3 LightDir=normalize(mlight.direction);
                half4 tex=SAMPLE_TEXTURE2D(_AlphaTex,sampler_AlphaTex,i.texcoord.zw);
                clip(tex.a-_CutOff);
                //half4 diff=tex*LightColor*_BaseColor*saturate(dot(LightDir,i.normalWS));
                half4 diff=tex*LightColor*_BaseColor*(saturate(dot(LightDir,i.normalWS))*0.5+0.5);
                return diff;
            }
            ENDHLSL
            
        }
    }
    
}
