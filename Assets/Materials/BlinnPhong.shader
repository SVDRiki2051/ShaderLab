Shader "URPCustom/BlinnPhong" {
    Properties
    {
        _MainTex("Texture",2D)="White"{}
        _DiffuseColor("DiffuseColor",Color)=(1,1,1,1)
        _SpecularColor("SpecularColor",Color)=(1,1,1,1)   //控制材质的高光反射颜色
        _Gloss("Gloss",Range(8,32))=8   //用于控制高光区域的大小
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
        float4 _DiffuseColor;
        float _Gloss;
        float4 _SpecularColor;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct a2v
        {
            float4 positionOS:POSITION;
            float2 texcoord:TEXCOORD0;
            float3 normalOS:NORMAL;
        };

        struct v2f
        {
            float4 positionCS:SV_POSITION;
            float3 normalWS:NORMAL;
            float2 texcoord:TEXCOORD0;
            float3 viewDirWS:TEXCOORD1;
        };
        
        ENDHLSL
        
        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
            }
            HLSLPROGRAM

            #pragma vertex vert1
            #pragma fragment frag1

            v2f vert1(a2v i)
            {   
                v2f o;
                o.positionCS=TransformObjectToHClip(i.positionOS.xyz);
                o.normalWS=TransformObjectToWorldNormal(i.normalOS,true);
                o.viewDirWS=normalize(_WorldSpaceCameraPos.xyz-TransformObjectToWorld(i.positionOS.xyz));  //物体上的点在世界空间下的坐标到相机坐标的归一化向量表示世界空间的视图方向
                //o.viewDirWS=normalize(GetWorldSpaceViewDir(TransformObjectToWorld(i.positionOS.xyz)));   //和上面等价
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);
                return o; 
            }

            half4 frag1(v2f i):SV_TARGET
            {
                float4 tex=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord)*_DiffuseColor;
                Light mlight=GetMainLight();
                float3 LightDirWS=normalize(mlight.direction);
                float3 h=normalize(LightDirWS+i.viewDirWS);
                float diff=saturate(dot(h,i.normalWS));        //如果不用saturate截停，会出现超出物体的大范围反光！！！
                half4 specolor=_SpecularColor*pow(diff,_Gloss);
                half4 texcolor=(dot(LightDirWS,i.normalWS)*0.5+0.5)*tex;
                //half4 texcolor=saturate(dot(LightDirWS,i.normalWS))*tex;
                texcolor*=half4(mlight.color,1);
                return specolor+texcolor;
            }
            
            ENDHLSL
        }
        
    }
    
}
