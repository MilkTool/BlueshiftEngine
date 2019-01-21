$include "fragment_common.glsl"

#ifndef _ALBEDO
#define _ALBEDO 0
#endif

#ifndef _NORMAL
#define _NORMAL 0
#endif

#ifndef _SPECULAR
#define _SPECULAR 0
#endif

#ifndef _GLOSS
#define _GLOSS 0
#endif

#ifndef _METALLIC
#define _METALLIC 0
#endif

#ifndef _ROUGHNESS
#define _ROUGHNESS 0
#endif

#ifndef _ANISO
#define _ANISO 0
#endif

#ifndef _CLEARCOAT
#define _CLEARCOAT 0
#endif

#ifndef _CC_ROUGHNESS
#define _CC_ROUGHNESS 0
#endif

#ifndef _CC_NORMAL
#define _CC_NORMAL 0
#endif

#ifndef _PARALLAX
#define _PARALLAX 0
#endif

#ifndef _EMISSION
#define _EMISSION 0
#endif

in LOWP vec4 v2f_color;
in MEDIUMP vec2 v2f_tex;

#if _NORMAL == 0
    in LOWP vec3 v2f_normal;
#endif

#if _PARALLAX
    in vec3 v2f_tangentViewDir;
#endif

#ifdef DIRECT_LIGHTING
    in vec3 v2f_lightVector;
    in vec3 v2f_lightFallOff;
    in vec4 v2f_lightProjection;
#endif

#if defined(DIRECT_LIGHTING) || defined(INDIRECT_LIGHTING)
    in vec3 v2f_viewVector;

    #if _NORMAL == 0
        in vec3 v2f_worldPos;
    #else
        in vec4 v2f_toWorldAndPackedWorldPosS;
        in vec4 v2f_toWorldAndPackedWorldPosT;
        in vec4 v2f_toWorldAndPackedWorldPosR;
    #endif
#endif

#ifdef USE_SHADOW_MAP
    $include "ShadowLibrary.fp"
#endif

out vec4 o_fragColor : FRAG_COLOR;

//
// Material parameters
//
uniform sampler2D albedoMap;
uniform LOWP vec3 albedoColor;
uniform LOWP float albedoAlpha;
uniform LOWP float perforatedAlpha;

uniform LOWP float wrappedDiffuse;

uniform sampler2D normalMap;
uniform sampler2D detailNormalMap;
uniform MEDIUMP float detailRepeat;

uniform sampler2D specularMap;
uniform LOWP vec4 specularColor;

uniform sampler2D glossMap;
uniform LOWP float glossScale;

uniform sampler2D metallicMap;
uniform LOWP float metallicScale;

uniform sampler2D roughnessMap;
uniform LOWP float roughnessScale;

uniform sampler2D anisotropyMap
uniform LOWP float anisotropyRotation;
uniform LOWP float anisotropyScale;

uniform sampler2D clearCoatMap;
uniform LOWP float clearCoatScale;
uniform sampler2D clearCoatRoughnessMap;
uniform LOWP float clearCoatRoughnessScale;
uniform sampler2D clearCoatNormalMap;

uniform sampler2D heightMap;
uniform LOWP float heightScale;

uniform sampler2D occlusionMap;
uniform LOWP float occlusionStrength;

uniform sampler2D emissionMap;
uniform LOWP vec3 emissionColor;
uniform MEDIUMP float emissionScale;

uniform sampler2D subSurfaceColorMap;
uniform float subSurfaceRollOff;
uniform float subSurfaceShadowDensity;// = 0.5;

//
// Light parameters
//
uniform sampler2D lightProjectionMap;
uniform MEDIUMP vec4 lightColor;
uniform MEDIUMP float lightFallOffExponent;
uniform samplerCube lightCubeMap;
uniform bool useLightCube;
uniform bool useShadowMap;
uniform LOWP float ambientScale;

// IBL
uniform samplerCube envCubeMap;

uniform samplerCube irradianceEnvCubeMap0;
uniform samplerCube prefilteredEnvCubeMap0;
uniform vec3 probePosition0;
uniform vec3 probeMins0;
uniform vec3 probeMaxs0;

uniform samplerCube irradianceEnvCubeMap1;
uniform samplerCube prefilteredEnvCubeMap1;
uniform vec3 probePosition1;
uniform vec3 probeMins1;
uniform vec3 probeMaxs1;

uniform sampler2D integrationLUTMap;
uniform LOWP float ambientLerp;

struct MaterialParms {
    vec4 diffuse;
    vec4 specular;
    float roughness;

#ifdef LEGACY_PHONG_LIGHTING
    float specularPower;
#endif

#if _ANISO != 0
    float anisotropy;
#endif

#if _CLEARCOAT != 0
    float clearCoat;
    float clearCoatRoughness;
    vec3 clearCoatN;
#endif

#if _OCC != 0
    float occlusion;
#endif

#if _EMISSION != 0
    vec3 emission;
#endif
};

MaterialParms material;

#if defined(DIRECT_LIGHTING) || defined(INDIRECT_LIGHTING)
    $include "StandardBRDF.glsl"
    #ifdef LEGACY_PHONG_LIGHTING
        $include "PhongBRDF.glsl"
    #endif 
#endif

#if defined(INDIRECT_LIGHTING)
    #ifdef BRUTE_FORCE_IBL
        $include "IBL.glsl"
    #endif
#endif

#if _NORMAL == 2 && !defined(ENABLE_DETAIL_NORMALMAP)
    #undef _NORMAL
    #define _NORMAL 1
#endif

#if _PARALLAX == 1 && !defined(ENABLE_PARALLAXMAP)
    #undef _PARALLAX 
    #define _PARALLAX 0
#endif

#if _ALBEDO != 0 || _NORMAL != 0 || _SPECULAR != 0 || _GLOSS == 3 || _METALLIC >= 1 || (_ROUGHNESS == 1 || _ROUGHNESS == 2) || _PARALLAX != 0 || _EMISSION == 2 || _CLEARCOAT == 2 || _ANISO == 2 || (_CLEARCOAT != 0 && _CC_NORMAL == 1)
    #define NEED_BASE_TC
#endif

vec2 baseTc;

//#define PARALLAX_CORRECTED_INDIRECT_LIGHTING

void SetupMaterial(vec3 worldN, vec4 albedo) {
#if defined(STANDARD_SPECULAR_LIGHTING) || defined(LEGACY_PHONG_LIGHTING)
    material.diffuse = albedo;

    #if _SPECULAR == 0
        material.specular = specularColor;
    #elif _SPECULAR == 1
        material.specular = tex2D(specularMap, baseTc);
    #endif

    #if _GLOSS == 0
        float glossiness = glossScale;
    #elif _GLOSS == 1
        float glossiness = albedo.a * glossScale;
    #elif _GLOSS == 2
        float glossiness = material.specular.a * glossScale;
    #elif _GLOSS == 3
        float glossiness = tex2D(glossMap, baseTc).r * glossScale;
    #endif

    #if _ANISO != 0
        #if _ANISO == 1
            material.anisotropy = anisotropyScale;
        #elif _ANISO == 2
            material.anisotropy = tex2D(anisotropyMap, baseTc).r * anisotropyScale;
        #endif
    #endif

    #if _CLEARCOAT != 0
        #if _CLEARCOAT == 1
            material.clearCoat = clearCoatScale;
        #elif _CLEARCOAT == 2
            material.clearCoat = tex2D(clearCoatMap, baseTc).r * clearCoatScale;
        #elif _CLEARCOAT == 3
            material.clearCoat = albedo.a * clearCoatScale;
        #elif _CLEARCOAT == 4
            material.clearCoat = material.specular.a * clearCoatScale;
        #endif

        #if _CC_ROUGHNESS == 0
            material.clearCoatRoughness = clearCoatRoughnessScale;
        #elif _CC_ROUGHNESS == 1
            material.clearCoatRoughness = tex2D(clearCoatRoughnessMap, baseTc).r * clearCoatRoughnessScale;
        #elif _CC_ROUGHNESS == 2
            material.clearCoatRoughness = albedo.a * clearCoatRoughnessScale;
        #elif _CC_ROUGHNESS == 3
            material.clearCoatRoughness = material.specular.a * clearCoatRoughnessScale;
        #endif
    #endif

    #if _OCC == 1
        material.occlusion = tex2D(occlusionMap, baseTc).r;
    #elif _OCC == 2
        material.occlusion = albedo.a;
    #elif _OCC == 3
        material.occlusion = material.specular.a;
    #endif

    // Clamp the roughness to a minimum value to avoid divisions by 0 in the lighting code
    material.roughness = clamp(1.0 - glossiness, MIN_ROUGHNESS, 1.0);

    #ifdef LEGACY_PHONG_LIGHTING
        material.specularPower = glossinessToSpecularPower(glossiness);
    #endif
#elif defined(STANDARD_METALLIC_LIGHTING)
    #if _METALLIC == 0
        vec4 metallic = vec4(1.0, 0.0, 0.0, 0.0);
    #elif _METALLIC >= 1
        vec4 metallic = tex2D(metallicMap, baseTc);
    #endif

    #if _METALLIC == 0
        float metalness = metallicScale;
    #elif _METALLIC == 1
        float metalness = metallic.r * metallicScale;
    #elif _METALLIC == 2
        float metalness = metallic.g * metallicScale;
    #elif _METALLIC == 3
        float metalness = metallic.b * metallicScale;
    #elif _METALLIC == 4
        float metalness = metallic.a * metallicScale;
    #endif

    #if _ROUGHNESS == 0
        material.roughness = roughnessScale;
    #elif _ROUGHNESS == 1
        material.roughness = tex2D(roughnessMap, baseTc).r * roughnessScale;
    #elif _ROUGHNESS == 2
        material.roughness = (1.0 - tex2D(roughnessMap, baseTc).r) * roughnessScale;
    #elif _ROUGHNESS == 3
        material.roughness = metallic.r * roughnessScale;
    #elif _ROUGHNESS == 4
        material.roughness = metallic.g * roughnessScale;
    #elif _ROUGHNESS == 5
        material.roughness = metallic.b * roughnessScale;
    #elif _ROUGHNESS == 6
        material.roughness = metallic.a * roughnessScale;
    #endif

    // Clamp the roughness to a minimum value to avoid divisions by 0 in the lighting code
    material.roughness = clamp(material.roughness, MIN_ROUGHNESS, 1.0);

    #if _ANISO != 0
        #if _ANISO == 1
            material.anisotropy = anisotropyScale;
        #elif _ANISO == 2
            material.anisotropy = tex2D(anisotropyMap, baseTc).r * anisotropyScale;
        #endif
    #endif

    #if _CLEARCOAT != 0
        #if _CLEARCOAT == 1
            material.clearCoat = clearCoatScale;
        #elif _CLEARCOAT == 2
            material.clearCoat = tex2D(clearCoatMap, baseTc).r * clearCoatScale;
        #elif _CLEARCOAT == 3
            material.clearCoat = metallic.r * clearCoatScale;
        #elif _CLEARCOAT == 4
            material.clearCoat = metallic.g * clearCoatScale;
        #elif _CLEARCOAT == 5
            material.clearCoat = metallic.b * clearCoatScale;
        #elif _CLEARCOAT == 6
            material.clearCoat = metallic.a * clearCoatScale;
        #endif

        #if _CC_ROUGHNESS == 0
            material.clearCoatRoughness = clearCoatRoughnessScale;
        #elif _CC_ROUGHNESS == 1
            material.clearCoatRoughness = tex2D(clearCoatRoughnessMap, baseTc).r * clearCoatRoughnessScale;
        #elif _CC_ROUGHNESS == 2
            material.clearCoatRoughness = metallic.r * clearCoatRoughnessScale;
        #elif _CC_ROUGHNESS == 3
            material.clearCoatRoughness = metallic.g * clearCoatRoughnessScale;
        #elif _CC_ROUGHNESS == 4
            material.clearCoatRoughness = metallic.b * clearCoatRoughnessScale;
        #elif _CC_ROUGHNESS == 5
            material.clearCoatRoughness = metallic.a * clearCoatRoughnessScale;
        #endif
    #endif

    #if _OCC == 1
        material.occlusion = tex2D(occlusionMap, baseTc).r;
    #elif _OCC == 2
        material.occlusion = metallic.r;
    #elif _OCC == 3
        material.occlusion = metallic.g;
    #elif _OCC == 4
        material.occlusion = metallic.b;
    #elif _OCC == 5
        material.occlusion = metallic.a;
    #endif

    // A base reflectivity of 0.04 holds for most dielectrics
    material.specular = vec4(mix(vec3(0.04), albedo.rgb, metalness), 1.0);

    material.diffuse = vec4(albedo.rgb * (1.0 - metalness), albedo.a);
#endif

#if !defined(LEGACY_PHONG_LIGHTING) && _CLEARCOAT != 0
    material.specular.rgb = mix(material.specular.rgb, F0ToClearCoatToSurfaceF0(material.specular.rgb), material.clearCoat);

    // Remapping of clear coat roughness
    material.clearCoatRoughness = mix(MIN_CLEARCOAT_ROUGHNESS, MAX_CLEARCOAT_ROUGHNESS, material.clearCoatRoughness);

    #if _CC_NORMAL == 1
        vec3 tangentClearCoatN = normalize(GetNormal(clearCoatNormalMap, baseTc));

        // Convert coordinates from tangent space to GL world space
        material.clearCoatN.x = dot(toWorldMatrixS, tangentClearCoatN);
        material.clearCoatN.y = dot(toWorldMatrixT, tangentClearCoatN);
        material.clearCoatN.z = dot(toWorldMatrixR, tangentClearCoatN);
    #elif _NORMAL == 0
        material.clearCoatN = worldN;
    #else
        material.clearCoatN = normalize(vec3(toWorldMatrixS.z, toWorldMatrixT.z, toWorldMatrixR.z));
    #endif
#endif

#if defined(INDIRECT_LIGHTING)
    #if _EMISSION == 1
        material.emission = emissionColor * emissionScale;
    #elif _EMISSION == 2
        material.emission = tex2D(emissionMap, baseTc).rgb * emissionColor * emissionScale;
    #endif
#endif
}

void main() {
#ifdef NEED_BASE_TC
    #if _PARALLAX != 0
        float h = tex2D(heightMap, v2f_tex).x * 2.0 - 1.0;
        baseTc = v2f_tex + h * heightScale * 0.1 * (v2f_tangentViewDir.xy / v2f_tangentViewDir.z);
    #else
        baseTc = v2f_tex;
    #endif
#endif

#if _ALBEDO == 0
    vec4 albedo = vec4(albedoColor, albedoAlpha);
#elif _ALBEDO == 1
    vec4 albedo = tex2D(albedoMap, baseTc);
#endif

#ifdef PERFORATED
    if (albedo.a < perforatedAlpha) {
        discard;
    }
#endif

#if defined(DIRECT_LIGHTING) || defined(INDIRECT_LIGHTING)
    vec3 worldV = normalize(v2f_viewVector.yzx);

    #if _NORMAL != 0
        vec3 toWorldMatrixS = normalize(v2f_toWorldAndPackedWorldPosT.xyz);
        vec3 toWorldMatrixT = normalize(v2f_toWorldAndPackedWorldPosR.xyz);
        vec3 toWorldMatrixR = normalize(v2f_toWorldAndPackedWorldPosS.xyz);
        //vec3 toWorldMatrixR = normalize(cross(toWorldMatrixS, toWorldMatrixT) * v2f_toWorldT.w);
    #endif

    #if _NORMAL == 0
        vec3 worldN = normalize(v2f_normal.yzx);
    #else
        vec3 tangentN = normalize(GetNormal(normalMap, baseTc));

        #if _NORMAL == 2
            vec3 tangentN2 = vec3(tex2D(detailNormalMap, baseTc * detailRepeat).xy * 2.0 - 1.0, 0.0);
            tangentN = normalize(tangentN + tangentN2);
        #endif

        vec3 worldN;
        // Convert coordinates from tangent space to GL world space
        worldN.x = dot(toWorldMatrixS, tangentN);
        worldN.y = dot(toWorldMatrixT, tangentN);
        worldN.z = dot(toWorldMatrixR, tangentN);
    #endif

    #ifdef TWO_SIDED
        worldN = gl_FrontFacing ? worldN : -worldN;
    #endif

    SetupMaterial(worldN, albedo);
#endif

    vec3 shadingColor = vec3(0.0);

#ifdef INDIRECT_LIGHTING
    #ifdef BRUTE_FORCE_IBL
        #if defined(STANDARD_METALLIC_LIGHTING) || defined(STANDARD_SPECULAR_LIGHTING)
            shadingColor += IBLDiffuseLambertWithSpecularGGX(envCubeMap, worldN, worldV);
        #elif defined(LEGACY_PHONG_LIGHTING)
            shadingColor += IBLPhongWithFresnel(envCubeMap, worldN, worldV);
        #endif
    #else
        vec3 worldS = reflect(-worldV, worldN);

        #ifdef PARALLAX_CORRECTED_INDIRECT_LIGHTING
            #if _NORMAL == 0
                worldPos = v2f_worldPos.yzx;
            #else
                vec3 worldPos;
                worldPos.x = v2f_toWorldAndPackedWorldPosT.w;
                worldPos.y = v2f_toWorldAndPackedWorldPosR.w;
                worldPos.z = v2f_toWorldAndPackedWorldPosS.w;
            #endif

            vec4 sampleVec;
            sampleVec.xyz = BoxProjectedCubemapDirection(worldS, worldPos, vec4(0, 50, 250, 1.0), vec3(-2500, 0, -2500), vec3(2500, 250, 2500)); // FIXME
        #else
            vec4 sampleVec;
            sampleVec.xyz = worldS;
        #endif

        #if defined(STANDARD_METALLIC_LIGHTING) || defined(STANDARD_SPECULAR_LIGHTING)
            shadingColor += IndirectLit_Standard(worldN, worldV, sampleVec.xyz);
        #elif defined(LEGACY_PHONG_LIGHTING)
            shadingColor += IndirectLit_PhongFresnel(worldN, worldV, sampleVec.xyz);
        #endif
    #endif

    #if _OCC != 0
        shadingColor *= (1.0 - occlusionStrength) + material.occlusion * occlusionStrength;
    #endif

    #if _EMISSION != 0
        shadingColor += material.emission;
    #endif
#else
    shadingColor += albedo.rgb * ambientScale;
#endif

#ifdef DIRECT_LIGHTING
    float attenuation = 1.0 - min(dot(v2f_lightFallOff, v2f_lightFallOff), 1.0);
    attenuation = pow(attenuation, lightFallOffExponent);

    vec3 Cl = tex2Dproj(lightProjectionMap, v2f_lightProjection).xyz * lightColor.xyz * attenuation;

    #ifdef USE_SHADOW_MAP
        vec3 shadowLighting = ShadowFunc();
    #else
        vec3 shadowLighting = vec3(1.0);
    #endif

    vec3 worldL = normalize(v2f_lightVector.yzx);

    #ifdef USE_LIGHT_CUBE_MAP
        if (useLightCube) {
            Cl *= texCUBE(lightCubeMap, -worldL);
        }
    #endif

    #if defined(STANDARD_METALLIC_LIGHTING) || defined(STANDARD_SPECULAR_LIGHTING)
        vec3 lightingColor = DirectLit_Standard(worldL, worldN, worldV);
    #elif defined(LEGACY_PHONG_LIGHTING)
        vec3 lightingColor = DirectLit_PhongFresnel(worldL, worldN, worldV);
    #endif

    #if defined(_SUB_SURFACE_SCATTERING)
        float subLamb = smoothstep(-subSurfaceRollOff, 1.0, NdotL) - smoothstep(0.0, 1.0, NdotL);
        subLamb = max(subLamb, 0.0);
        lightingColor += subLamb * tex2D(subSurfaceColorMap, baseTc).xyz * (shadowLighting * (1.0 - subSurfaceShadowDensity) + subSurfaceShadowDensity);
    #endif

    shadingColor += Cl * lightingColor * shadowLighting;

    #if _OCC != 0
        shadingColor *= (1.0 - occlusionStrength) + material.occlusion * occlusionStrength;
    #endif
#endif

    vec4 finalColor = v2f_color * vec4(shadingColor, albedo.a);

#ifdef LOGLUV_HDR
    o_fragColor = encodeLogLuv(finalColor.xyz);
#else
    o_fragColor = finalColor;
#endif
}
