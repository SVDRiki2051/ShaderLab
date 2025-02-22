Shader "Lambert"
{
    Properties
    {
        _MainTex("MainTex",2D)="White"{ }
        _BaseColor("BaseColor",Color)=(1,1,1,1)

    }

    SubShader
    {
        Tags //Tags 块用于定义Shader的一些元数据，这些元数据会影响Shader的行为和如何被渲染管线处理。
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque"

        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPreMaterial)
            //每个使用这个Shader的材质都可以有自己的常量缓冲区
            float4 _MainTex_ST;     //包含了纹理的平铺和偏移值
            half4 _BaseColor;    
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct a2v
        {
            float4 positionOS:POSITION;
            float3 normal:NORMAL;
            float2 texcoord:TEXCOORD0;
        };

        struct v2f
        {
            float4 positionCS:SV_POSITION;
            float2 texcoord:TEXCOORD0;
            //为了把在顶点着色器中计算得到的光照颜色传递给片元着色器， 我们需要在v2f中定义一个color变量，且并不是必须使用 COLOR语义，一些资料中会使用TEXCOORDO语义。
            float3 normalWS:TEXCOORD1;
        };
        ENDHLSL

        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord = TRANSFORM_TEX(i.texcoord, _MainTex);  //计算经过平铺和偏移后的纹理坐标
                o.normalWS = TransformObjectToWorldNormal(i.normal, true);
                return o;
            }

            half4 frag(v2f i):SV_TARGET
            {
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord) * _BaseColor;
                Light mlight = GetMainLight();
                half4 LightColor = half4(mlight.color, 1);
                float3 LightDir = normalize(mlight.direction);
                float LightAten = saturate(dot(LightDir, i.normalWS));
                return tex * LightAten * LightColor;
                return  tex * (LightAten*0.5+0.5) * LightColor;       //半兰伯特
            }
            ENDHLSL
        }

    }
}