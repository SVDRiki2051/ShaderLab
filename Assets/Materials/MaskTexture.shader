Shader "MaskTexture"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("Color",Color)=(1,1,1,1)
        _NormalTex("Normal Map",2D)="bump"{}
        _NormalScale("Normal Scale",Range(0,1))=1
        _SpecularMask("Specular Mask",2D)="white"{}   //使用的高光反射遮罩纹理
        _SpecularMaskScale("Specular Scale",Range(0,1))=1   //控制遮罩影响度的系数
        _SpecularColor("Specular Color",Color)=(1,1,1,1)
        _Gloss("Gloss",Range(8,256))=20
    }
    SubShader
    {
        Tags {
            "RenderPipline"="UniversalRenderPipeline"
            "RenderType"="Opaque"
        }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        float4 _NormalTex_ST;
        float _NormalScale;
        float4 _SpecularMask_ST;
        float _SpecularMaskScale;
        half4 _SpecularColor;
        float _Gloss;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        TEXTURE2D(_NormalTex);
        TEXTURE2D(_SpecularMask);
        SAMPLER(sampler_MainTex);
        SAMPLER(sampler_NormalTex);
        SAMPLER(sampler_SpecularMask);

        struct a2v
        {
            float3 positionOS:POSITION;
            float2 texcoord:TEXCOORD0;
            float3 normalOS:NORMAL;
            float4 tangentOS:TANGENT;
            
        };

        struct v2f
        {
            float4 positionCS:SV_POSITION;
            float4 texcoord:TEXCOORD0;
            float4 tangentWS:TANGENT;
            float4 normalWS:NORMAL;
            float4 BtangentWS:TEXCOORD1;
            float2 Masktexcoord:TEXCOORD2;
        };
        ENDHLSL
        
        Pass
        {
            Name "MainPass"
            Tags
            {
                "LightMode"="UniversalForward"   //LightMode标签是Pass标签的一种，用于定义该Pass在Unity的光照流水线中的角色
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma  fragment frag
            
            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS=TransformObjectToHClip(i.positionOS);
                o.texcoord.xy=TRANSFORM_TEX(i.texcoord,_MainTex);
                o.texcoord.zw=TRANSFORM_TEX(i.texcoord,_NormalTex);
                o.Masktexcoord=TRANSFORM_TEX(i.texcoord,_SpecularMask);
                o.normalWS.xyz=normalize(TransformObjectToWorldNormal(i.normalOS));
                o.tangentWS.xyz=TransformObjectToWorldDir(i.tangentOS,true);
                o.BtangentWS.xyz=cross(o.normalWS.xyz,o.tangentWS.xyz)*i.tangentOS.w*unity_WorldTransformParams.w;
                float3 positionWS=TransformObjectToWorld(i.positionOS);
                o.tangentWS.w=positionWS.x;
                o.BtangentWS.w=positionWS.y;
                o.normalWS.w=positionWS.z;
                return o;
            }

            half4 frag(v2f i):SV_TARGET
            {
                float3 positionWS=float3(i.tangentWS.w,i.BtangentWS.w,i.normalWS.w);
                float3x3 T2W={i.tangentWS.xyz,i.BtangentWS.xyz,i.normalWS.xyz};
                float4 NorTex=SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,i.texcoord.zw);
                float3 NormalTS=UnpackNormalScale(NorTex,_NormalScale);
                NormalTS.z=pow((1.0-pow(NormalTS.x,2)-pow(NormalTS.y,2)),0.5);
                float3 NorWS=mul(NormalTS,T2W);
                Light mlight = GetMainLight();
                half speMask=SAMPLE_TEXTURE2D(_SpecularMask,sampler_SpecularMask,i.Masktexcoord).r*_SpecularMaskScale;
                float halflambert=0.5+0.5*(dot(NorWS,normalize(mlight.direction)));
                half4 diff=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord.xy)*halflambert*_BaseColor*half4(mlight.color,1);
                float spe=saturate(dot(normalize(normalize(mlight.direction)+normalize(_WorldSpaceCameraPos-positionWS)),NorWS));
                spe= pow(spe,_Gloss)*_SpecularColor*speMask;
                return diff+spe;   
            }
            ENDHLSL
        }


        
    }
}
