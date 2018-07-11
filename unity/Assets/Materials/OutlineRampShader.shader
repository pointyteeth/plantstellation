Shader "Plantstellation/Outline Ramp" {
	Properties {
		_MainTex("Texture", 2D) = "white" {}
		_RampTex("Ramp", 2D) = "white" {}
		_Color("Color", Color) = (1, 1, 1, 1)
		_Specularity("Specularity", Range(0, 1)) = 1
		_OutlineExtrusion("Outline Extrusion", float) = 0
		_OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
		_OutlineDot("Outline Dot", float) = 0.25
	}

	SubShader {
		// Regular color & lighting pass
		Pass {
            Tags {
				"LightMode" = "ForwardBase" // allows shadow rec/cast
				"RenderType" = "Transparent"
				"Queue" = "Transparent"
			}

			Blend SrcAlpha OneMinusSrcAlpha

			// Write to Stencil buffer (so that outline pass can read)
			Stencil {
				Ref 4
				Comp always
				Pass replace
				ZFail keep
			}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase // shadows
			#include "AutoLight.cginc"
			#include "UnityCG.cginc"

			// Properties
			sampler2D _MainTex;
			sampler2D _RampTex;
			float4 _Color;
			float4 _LightColor0; // provided by Unity
			float _Specularity;

			struct vertexInput {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float3 texCoord : TEXCOORD0;
			};

			struct vertexOutput {
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float3 texCoord : TEXCOORD0;
				LIGHTING_COORDS(1,2) // shadows
			};

			vertexOutput vert(vertexInput input) {
				vertexOutput output;

				// convert input to world space
				output.pos = UnityObjectToClipPos(input.vertex);
				float4 normal4 = float4(input.normal, 0.0); // need float4 to mult with 4x4 matrix
				output.normal = normalize(mul(normal4, unity_WorldToObject).xyz);

				output.texCoord = input.texCoord;

                TRANSFER_VERTEX_TO_FRAGMENT(output); // shadows
				return output;
			}

			float4 frag(vertexOutput input) : COLOR {
				// lighting mode

				// convert light direction to world space & normalize
				// _WorldSpaceLightPos0 provided by Unity
				float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);

				// finds location on ramp texture that we should sample
				// based on angle between surface normal and light direction
				float ramp = clamp(dot(input.normal, lightDir), 0, 1.0);
				float3 lighting = tex2D(_RampTex, float2(ramp, 0.5)).rgb;

				// sample texture for color
				float4 albedo = tex2D(_MainTex, input.texCoord.xy);

				float attenuation = LIGHT_ATTENUATION(input); // shadow value
				float3 rgb = albedo.rgb * _LightColor0.rgb * lighting * _Color.rgb * attenuation;
				return float4(rgb, lerp(Luminance(lighting), _Specularity, _Color.a));
			}

			ENDCG
		}

		// Additional lights Pass
		Pass {
			Tags {
				"LightMode" = "ForwardAdd" // allows shadow rec/cast
				"RenderType" = "Transparent"
				"Queue" = "Transparent"
			}

			Blend One One

			// Write to Stencil buffer (so that outline pass can read)
			Stencil {
				Ref 4
				Comp always
				Pass replace
				ZFail keep
			}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase // shadows
			#include "AutoLight.cginc"
			#include "UnityCG.cginc"

			// Properties
			sampler2D _MainTex;
			sampler2D _RampTex;
			float4 _Color;
			float4 _LightColor0; // provided by Unity
			float _Specularity;

			struct vertexInput {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float3 texCoord : TEXCOORD0;
			};

			struct vertexOutput {
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float3 texCoord : TEXCOORD0;
				LIGHTING_COORDS(1,2) // shadows
			};

			vertexOutput vert(vertexInput input) {
				vertexOutput output;

				// convert input to world space
				output.pos = UnityObjectToClipPos(input.vertex);
				float4 normal4 = float4(input.normal, 0.0); // need float4 to mult with 4x4 matrix
				output.normal = normalize(mul(normal4, unity_WorldToObject).xyz);

				output.texCoord = input.texCoord;

				TRANSFER_VERTEX_TO_FRAGMENT(output); // shadows
				return output;
			}

			float4 frag(vertexOutput input) : COLOR {
				// lighting mode

				// convert light direction to world space & normalize
				// _WorldSpaceLightPos0 provided by Unity
				float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);

				// finds location on ramp texture that we should sample
				// based on angle between surface normal and light direction
				float ramp = clamp(dot(input.normal, lightDir), 0, 1.0);
				float3 lighting = tex2D(_RampTex, float2(ramp, 0.5)).rgb;

				// sample texture for color
				float4 albedo = tex2D(_MainTex, input.texCoord.xy);

				float attenuation = LIGHT_ATTENUATION(input); // shadow value
				float3 rgb = albedo.rgb * _LightColor0.rgb * lighting * _Color.rgb * attenuation;
				return float4(rgb, lerp(Luminance(lighting), _Specularity, _Color.a));
			}

			ENDCG
		}

		// Shadow pass
		Pass {
            Tags {
				"LightMode" = "ShadowCaster"
			}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct v2fs {
                V2F_SHADOW_CASTER;
            };

            v2fs vert(appdata_base v) {
                v2fs o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag(v2fs i) : SV_Target {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
    	}

		// Outline pass
		Pass {

			Name "OUTLINE"
			Tags { "LightMode" = "Always" }
			Cull Front
			ZWrite On
			ColorMask RGB
			Blend SrcAlpha OneMinusSrcAlpha
			//Offset 50,50

			CGINCLUDE
			#include "UnityCG.cginc"

			struct appdata {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct v2f {
				float4 pos : POSITION;
				float4 color : COLOR;
			};

			uniform float _OutlineExtrusion;
			uniform float4 _OutlineColor;

			v2f vert(appdata v) {
				// just make a copy of incoming vertex data but scaled according to normal direction
				v2f o;

				float4 newPos = v.vertex;

				// normal extrusion technique
				float3 normal = mul ((float3x3)UNITY_MATRIX_IT_MV, v.normal);
				newPos += float4(normal, 0.0) * _OutlineExtrusion;

				// convert to world space
				o.pos = UnityObjectToClipPos(newPos);

				o.color = _OutlineColor;
				return o;
			}
			ENDCG

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			half4 frag(v2f i) :COLOR { return i.color; }
			ENDCG
		}
	}
}
