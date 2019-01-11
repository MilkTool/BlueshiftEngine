#ifndef BRDF_LIBRARY_INCLUDED
#define BRDF_LIBRARY_INCLUDED

float pow4(float f) {
    float f2 = f * f;
    return f2 * f2;
}

float pow5(float f) {
    float f2 = f * f;
    return f2 * f2 * f;
}

// Convert perceptual glossiness to specular power from [0, 1] to [2, 8192]
float glossinessToSpecularPower(float glossiness) {
    return exp2(11.0 * glossiness + 1.0); 
}

// 
// diffuse lighting function - multiplied by PI
//

float litDiffuseLambert(in float NdotL) {
    return NdotL;
}

float litDiffuseBurley(in float NdotL, in float NdotV, in float VdotH, in float roughness) {
    float Fd90 = 0.5 + 2.0 * VdotH * VdotH * roughness;
    float FdL = 1.0 + (Fd90 - 1.0) * pow5(1.0 - NdotL);
    float FdV = 1.0 + (Fd90 - 1.0) * pow5(1.0 - NdotV);
    return NdotL * FdL * FdV;
}

float litDiffuseOrenNayar(in float NdotL, in float NdotV, in float LdotV, in float roughness) { 
    float sigma2 = roughness * roughness;
    float A = 1.0 - sigma2 * (0.5 / (sigma2 + 0.33) + 0.17 / (sigma2 + 0.13));
    float B = 0.45 * sigma2 / (sigma2  + 0.09);

    // A tiny improvement of Oren-Nayar [Yasuhiro Fujii]
    // http://mimosa-pudica.net/improved-oren-nayar.html
    //float A = 1.0 / (PI + 0.90412966 * roughness);
    //float B = roughness / (PI + 0.90412966 * roughness);

    float s = LdotV - NdotL * NdotV;
    float t = mix(1.0, max(NdotL, NdotV), step(0.0, s));
    
    return NdotL * (A + B * s / t);
}

//---------------------------------------------------
// Normal distribution functions
//---------------------------------------------------

float D_Blinn(float NdotH, float a) {
    float a2 = a * a;
    float n = 2.0 / a2 - 2.0;
    n = max(n, 1e-4); // prevent possible zero
    return pow(NdotH, n) * (n + 2.0) * INV_TWO_PI;
}

float D_Beckmann(float NdotH, float a) {
    float a2 = a * a;
    float NdotH2 = NdotH * NdotH;
    return exp((NdotH2 - 1.0) / (a2 * NdotH2)) * INV_PI / (a2 * NdotH2 * NdotH2);
}

// Trowbridge-Reitz aka GGX
float D_GGX(float NdotH, float a) {
    float a2 = a * a;
    float denom = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 * INV_PI / (denom * denom + 1e-7);
}

float D_GGXAniso(float NdotH, float XdotH, float YdotH, float ax, float ay) {
    float ax2 = ax * ax;
    float ay2 = ay * ay;
    float axy = ax * ay;
    float denom = XdotH * XdotH / ax2 + YdotH * YdotH / ay2 + NdotH * NdotH;
    return INV_PI * axy * denom * denom;
}

//---------------------------------------------------
// Geometric visibility functions - divided by (NdotL * NdotV)
//---------------------------------------------------

float G_Neumann(float NdotV, float NdotL) {
    return 1.0 / max(NdotL, NdotV);
}

float G_Kelemen(float VdotH) {
    return 1.0 / (VdotH * VdotH);
}

float G_CookTorrance(float NdotV, float NdotL, float NdotH, float VdotH) {
    float G = min(1.0, min(2.0 * NdotH * NdotV / VdotH, (2.0 * NdotH * NdotL) / VdotH));
    return G / (NdotL * NdotV);
}

float G_SchlickGGX(float NdotV, float NdotL, float k) {
    float oneMinusK = 1.0 - k;
    float GV = NdotV * oneMinusK + k;
    float GL = NdotL * oneMinusK + k;
    return 1.0 / (GL * GV);
}

//---------------------------------------------------
// Fresnel functions
//---------------------------------------------------

// Fresnel using Schlick's approximation
vec3 F_Schlick(vec3 F0, float cosTheta) {
    return F0 + (vec3(1.0) - F0) * pow5(1.0 - cosTheta);
}

// Fresnel using Schlick's approximation with spherical Gaussian approximation
vec3 F_SchlickSG(vec3 F0, float cosTheta) {
    return F0 + (vec3(1.0) - F0) * exp2((-5.55473 * cosTheta - 6.98316) * cosTheta);
}

// Fresnel injected roughness term
vec3 F_SchlickRoughness(vec3 F0, float roughness, float cosTheta) {
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow5(1.0 - cosTheta);
}

#endif
