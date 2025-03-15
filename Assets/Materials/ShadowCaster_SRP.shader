Shader "Unlit/ShadowCaster"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor",Color)=(1,1,1,1)
        _Gloss("Gloss",Range(10,300))=50
        _SpecularColor("SpecularColor",Color)=(1,1,1,1)
        [KeywordEnum(ON,OFF)]_CUT("CUT",Float)=1
        _Cutoff("cutoff",Range(0,1))=1
        [KeywordEnum(ON,OFF)]_ADD_LIGHT("AddLight",Float)=1
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
        }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

        //不使用shader_feature是为了减少全局的关键词占用
        #pragma shader_feature_local _CUT_ON   //控制alphatest是否开启
        #pragma shader_feature_local _ADD_LIGHT_ON  //控制是否计算额外灯光
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS  
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        float _Gloss;
        float _Cutoff;
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
            float2 texcoord:TEXCOORD0;
            #ifdef _MAIN_LIGHT_SHADOWS
            float4  shadowcoord:TEXCOORD1;
            #endif
            float3 WS_P:TEXCOORD2;
            float3 WS_N:NORMAL;
            float3 WS_V:TEXCOORD3;
        };
        ENDHLSL

        Pass
        {
            Tags
            {
                "LightMode"="UniversalForward"
                "RenderType"="TransparentCutout"
                "Queue"="AlphaTest"
            }
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex VERT
            #pragma fragment FRAG
            

            v2f VERT(a2v i)
            {
                v2f o;
                o.positionCS=TransformObjectToHClip(i.positionOS.xyz);
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);
                o.WS_P=TransformObjectToWorld(i.positionOS.xyz);
                #ifdef _MAIN_LIGHT_SHADOWS
                    o.shadowcoord=TransformWorldToShadowCoord(o.WS_P);
                #endif

                o.WS_N=normalize(TransformObjectToWorldNormal(i.normalOS.xyz));
                o.WS_V=normalize(_WorldSpaceCameraPos-o.WS_P.xyz);
                return o;
            }

            half4 FRAG(v2f i):SV_TARGET
            {
                half4 tex=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord)*_BaseColor;
                #ifdef _CUT_ON
                clip(tex.a-_Cutoff);
                #endif

                float3 NormalWS=i.WS_N;
                float3 PositionWS=i.WS_P;
                float3 VeiwDir=i.WS_V;

                //MainLight
                #ifdef _MAIN_LIGHT_SHADOWS
                Light mlight=GetMainLight(i.shadowcoord);
                #else
                Light mlight=GetMainLight();
                #endif

                half4 MainColor=(dot(normalize(mlight.direction.xyz),NormalWS)*0.5+0.5)*half4(mlight.color,1);
                MainColor+=pow(saturate(dot(normalize(VeiwDir+normalize(mlight.direction.xyz)),NormalWS)),_Gloss)*_SpecularColor*half4(mlight.color,1);
                MainColor*=mlight.shadowAttenuation;

                //AddLights
                half4 AddColor=half4(0,0,0,1);
                #if _ADD_LIGHT_ON
                int addlightCount=GetAdditionalLightsCount();
                for (int index=0;index<addlightCount;index++)
                {
                    //float shadow = AdditionalLightRealtimeShadow(index, PositionWS);  //得到的好像是阴影衰减值
                    Light addlight=GetAdditionalLight(index,PositionWS,(1,1,1,1));
                    AddColor+=(dot(normalize(addlight.direction),NormalWS)*0.5+0.5)*half4(addlight.color,1)*addlight.shadowAttenuation*addlight.distanceAttenuation;
                }
                
                #endif
                
                return tex*(MainColor+AddColor);
            }
            
            ENDHLSL
        }

        //UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"

        Pass
        {
            //该Pass只把主灯光空间的深度图写到了shadowmap里，addlight灯光空间目前没有写进去，导致模型无法投射addlight的阴影，但是整个shader可以接受addlight的阴影
            //官方的
            Tags
            {
                "LightMode"="ShadowCaster"
            }
            
            HLSLPROGRAM
            #pragma vertex vertshadow
            #pragma fragment fragshadow

            half3 _LightDirection;

            v2f vertshadow(a2v i)
            {
                v2f o;
                o.texcoord=TRANSFORM_TEX(i.texcoord,_MainTex);
                float3 WSpos=TransformObjectToWorld(i.positionOS.xyz);
                //Light MainLight=GetMainLight();
                float3 WSnor=TransformObjectToWorldNormal(i.normalOS.xyz);
                o.positionCS=TransformWorldToHClip(ApplyShadowBias(WSpos,WSnor,_LightDirection));
                #if UNITY_REVERSED_Z
                o.positionCS.z=min(o.positionCS.z,o.positionCS.w*UNITY_NEAR_CLIP_VALUE);
                #else
                o.positionCS.z=max(o.positionCS.z,o.positionCS.w*UNITY_NEAR_CLIP_VALUE);
                #endif
                return o;
            }

            half4 fragshadow(v2f i):SV_TARGET
            {
                #ifdef _CUT_ON
                float alpha=SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.texcoord).a;
                clip(alpha-_Cutoff);
                #endif
                return 0;
            }
            ENDHLSL
        }
    }
}
