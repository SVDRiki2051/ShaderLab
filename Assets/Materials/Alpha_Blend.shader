Shader "Unlit/Alpha_Blend"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _AlphaTex("AlphaTex",2D)="white"{}
        _AlphaScale("AlphaScale",Range(0,1))=1   //用于在透明纹理的基础上控制整体的透明度
    }
    SubShader
    {
        Tags
        {
            "RednderPipeline"="UniversalRenderPipeline"
            //通常，使用了透明度混合的Shader都应该在SubShader中设置这3个标签
            "IgnoreProjector"="True"      //IgnoreProjector设置为True，这意味着这个shader；不会受到投影器（Projectors）的影响
            "RenderType"="Transparent"    //RenderType标签可以让Unity把这个Shader归入到提前定义的组，用来指明该Shader是一个使用了透明度混合的Shader
            "Queue"="Transparent"
            
        }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        float4 _AlphaTex_ST;
        float _AlphaScale;
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
            
            ZWrite Off                       //深度写入设置为关闭
            //开启并设置了该Pass的混合模式。将源颜色（该片元着色器产生的颜色）的混合因子设为SrcAlpha，
            //把目标颜色（已经存在于颜色缓冲中的颜色）的混合因子设为OneMinusSrcAlpha
            Blend SrcAlpha OneMinusSrcAlpha  
            
            
            HLSLPROGRAM
            #pragma vertex VERT
            #pragma fragment FRAG

            v2f VERT(a2v i)
            {
                v2f o;
                o.positionCS=TransformObjectToHClip(i.positionOS);
                o.texcoord.xy=TRANSFORM_TEX(i.texcoord,_MainTex);
                o.texcoord.zw=TRANSFORM_TEX(i.texcoord,_AlphaTex);
                o.normalWS=TransformObjectToWorldNormal(i.normalOS,true);
                return o;
            }

            half4 FRAG(v2f i):SV_TARGET
            {
                half4 tex=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord.xy)*_BaseColor;
                float alpha=SAMPLE_TEXTURE2D(_AlphaTex,sampler_AlphaTex,i.texcoord.zw).x;  //取alpha贴图的r通道作为a（混合因子）去混合
                //half4 alpha=SAMPLE_TEXTURE2D(_AlphaTex,sampler_AlphaTex,i.texcoord.zw);
                // Light mlight=GetMainLight();
                // half4 LightColor=half4(mlight.color,1);
                // float3 LightDir=normalize(mlight.direction);
                //half4 diff=tex*LightColor*(saturate(dot(i.normalWS,LightDir)));
                // half4 diff=tex*LightColor*(dot(i.normalWS,LightDir)*0.5+0.5);
                return half4(tex.xyz,alpha*_AlphaScale);  //设置了该片元着色器返回值中的透明通道，它是纹理像素的透明通道和材质参数_AlphaScale的乘积
                //return half4(diff.xyz,alpha*_AlphaScale);
                //return tex*alpha;
                //return diff*alpha;
            }
            ENDHLSL
        }
    }
}
