Shader "Texture"
{
    Properties
    {
        _MainTex("MainTex",2D)="white"{}
        _BaseColor("Color",Color)=(1,1,1,1)
        _SpecularColor("Specular",Color)=(1,1,1,1)
        _Gloss("Gloss",Range(8,256))=20
        [Normal]_NormalTex("Normal",2D)="bump"{}
        _NormalScale("NormalScale",Range(-2,2))=1
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

        CBUFFER_START(UnityPreMaterial)
            float4 _MainTex_ST;
            float4 _BaseColor;
            float4 _SpecularColor;
            float _Gloss;
            float4 _NormalTex_ST;
            float _NormalScale;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_NormalTex);
        SAMPLER(sampler_NormalTex);

        struct a2v //定义顶点着色器拿到数据的结构体，我们需要顶点位置，uv，顶点法线，顶点切线。
        {
            float4 positionOS:POSITION;
            float3 normal:NORMAL;
            float2 texcoord:TEXCOORD0;
            float4 tangentOS:TANGENT;
        };

        struct v2f
        {
            float4 positionCS:SV_POSITION;
            float4 texcoord:TEXCOORD0;
            float4 normalWS:NORMAL;
            float4 tangentWS:TANGENT;
            float4 BtangentWS:TEXCOORD1;
        };
        ENDHLSL

        Pass
        {
            Name "MainPass"
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
                o.texcoord.xy = TRANSFORM_TEX(i.texcoord, _MainTex);
                o.texcoord.zw = TRANSFORM_TEX(i.texcoord, _NormalTex);
                o.positionCS = TransformObjectToHClip(i.positionOS);
                o.normalWS.xyz = normalize(TransformObjectToWorldNormal(i.normal));
                o.tangentWS.xyz = TransformObjectToWorldDir(i.tangentOS, true);
                o.BtangentWS.xyz = cross(o.normalWS.xyz, o.tangentWS.xyz) * i.tangentOS.w * unity_WorldTransformParams.w; //这里乘一个unity_WorldTransformParams.w是为判断是否使用了奇数相反的缩放
                float3 positonWS = TransformObjectToWorld(i.positionOS);
                o.tangentWS.w = positonWS.x;
                o.BtangentWS.w = positonWS.y;
                o.normalWS.w = positonWS.z;
                return o;
            }

            half4 frag(v2f i):SV_TARGET
            {
                float3 posWS = float3(i.tangentWS.w, i.BtangentWS.w, i.normalWS.w);
                float3x3 T2W = {i.tangentWS.xyz, i.BtangentWS.xyz, i.normalWS.xyz};
                float4 nortex = SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.texcoord.zw);
                float3 normalTS = UnpackNormalScale(nortex, _NormalScale);        //该函数会先解包出法线向量的xyz分量，然后对xy进行缩放
                normalTS.z = pow((1.0 - pow(normalTS.x, 2) - pow(normalTS.y, 2)), 0.5);     
                float3 norWS = mul(normalTS, T2W);
                Light mlight = GetMainLight();
                float halflambert = 0.5+0.5*(dot(norWS, normalize(mlight.direction))) ;
                half4 diff = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord.xy) * halflambert * _BaseColor *
                    half4(mlight.color, 1);
                float spe = saturate(dot(normalize(normalize(mlight.direction) + normalize(_WorldSpaceCameraPos - posWS)), norWS));
                spe *= pow(spe, _Gloss);
                return diff + spe * _SpecularColor;
            }
            ENDHLSL
        }
    }

}