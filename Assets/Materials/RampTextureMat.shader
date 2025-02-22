Shader "RampTextureMat"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
    }
    SubShader
    {
        Tags {
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque"
        }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        //sampler2D _MainTex;
        

        struct a2v
        {
            float4 positionOS:POSITION;
            float3 normalOS:NORMAL;
        };

        struct v2f
        {
            float4 positionCS:SV_POSITION;
            float3 normalWS:NORMAL;
        };
        ENDHLSL
        
        Pass
        {
            Tags {"LightMode"="UniversalForward"}
            
            HLSLPROGRAM
            #pragma vertex VERT
            #pragma fragment FRAG
            
            v2f VERT(a2v i)
            {
                v2f o;
                o.positionCS=TransformObjectToHClip(i.positionOS.xyz);
                o.normalWS=normalize(TransformObjectToWorldNormal(i.normalOS));
                return o;
            }

            half4 FRAG(v2f i):SV_TARGET
            {
                float3 LightDir=normalize(GetMainLight().direction);
                float dott=dot(i.normalWS,LightDir)*0.5+0.5;   //对Ramp贴图水平方向的采样
                half4 diff= SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, float2(dott,0.5)) *_BaseColor;
                //half4 tex= tex2D(_MainTex,  float2(dott,0.5)) *_BaseColor;
                
                return diff;
            }
            ENDHLSL
            
        }
    }
}
