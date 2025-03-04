Shader "Unlit/Multi_Light"
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
            #pragma vertex VERT
            #pragma fragment FRAG
            #pragma shader_feature _ADD_LIGHT_ON _ADD_LIGHT_OFF

            v2f VERT(a2v i)
            {
                v2f o;
                o.positionCS=TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);
                o.WS_N=normalize(TransformObjectToWorldNormal(i.normalOS.xyz));
                o.WS_P=TransformObjectToWorld(i.positionOS.xyz);
                o.WS_V=normalize(_WorldSpaceCameraPos-o.WS_P);
                return o;
            }

            half4 FRAG(v2f i):SV_TARGET
            {
                half4 tex=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord)*_BaseColor;
                Light mlight=GetMainLight();
                float3 WS_Light=normalize(mlight.direction);
                float3 WS_Normal=i.WS_N;
                float3 WS_View=i.WS_V;
                //float3 WS_H=normalize(WS_View+WS_Light);
                float3 WS_Pos=i.WS_P;
                float4 Maincolor=(dot(WS_Light,WS_Normal)*0.5+0.5)*tex*float4(mlight.color,1);

                //Calculate AdditionalLight
                half4 addcolor=half4(0,0,0,1);
                #if _ADD_LIGHT_ON
                    int additionalLightCount=GetAdditionalLightsCount();
                    for (int index=0;index<additionalLightCount;index++){
                        Light addlight=GetAdditionalLight(index,WS_Pos);
                        float3 WS_addLightDir=normalize(addlight.direction);
                        addcolor+=(dot(WS_Normal,WS_addLightDir)*0.5+0.5)*half4(addlight.color,1)*tex*addlight.distanceAttenuation*addlight.shadowAttenuation;
                    }
                #else
                    addcolor=half4(0,0,0,1);
                #endif

                return Maincolor+addcolor;
            }
            ENDHLSL
        }
    }
}
