#version 460 core
#include <flutter/runtime_effect.glsl>

// ==============================================================================
// POST-PROCESSING DIRECTIONAL LIGHTING SHADER
// ==============================================================================
// 
// Creates strong directional lighting where:
// - Light-facing areas are bright
// - Shadow-facing areas are dark
// - Creates realistic light/shadow transition across objects
//
// ==============================================================================

uniform sampler2D uScene;      // Pre-rendered scene
uniform vec2 uResolution;      // Screen resolution

// Directional light parameters
uniform vec3 uLightDir;        // Light direction (normalized, pointing TO light source)
uniform float uAmbient;        // Ambient light intensity (0.0 - 1.0)
uniform float uDiffuse;        // Diffuse light intensity (0.0 - 1.0)
uniform float uSpecular;       // Specular intensity (0.0 - 1.0)
uniform float uShininess;      // Specular shininess (higher = tighter highlight)

// Effect parameters
uniform float uVignette;       // Vignette strength (0.0 - 1.0)
uniform float uContrast;       // Contrast adjustment (1.0 = normal)
uniform float uSaturation;     // Saturation adjustment (1.0 = normal)
uniform float uBrightness;     // Overall brightness multiplier

out vec4 fragColor;

// Convert RGB to luminance
float luminance(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

// Smooth step for gradient transitions
float smoothGradient(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    vec4 sceneColor = texture(uScene, uv);
    
    // Skip processing for fully transparent pixels
    if (sceneColor.a < 0.01) {
        fragColor = sceneColor;
        return;
    }
    
    // ========== SUBTLE DIRECTIONAL LIGHTING ==========
    // Note: Strong per-object lighting is applied during rendering.
    // This post-process adds subtle ambient gradient.
    
    vec3 lightDir = normalize(uLightDir);
    
    // Subtle gradient: left side slightly brighter (light source side)
    // Keep this subtle since per-object lighting handles the main effect
    float xGradient = 1.0 - uv.x * 0.15; // Very subtle: 1.0 on left, 0.85 on right
    float yGradient = 1.0 - uv.y * 0.1;  // Very subtle top-to-bottom
    
    // Light factor for ambient variation (subtle)
    float lightFactor = xGradient * yGradient;
    
    // ========== SIMPLE LIGHTING ==========
    // Per-object lighting is done during rendering.
    // This shader just adds subtle ambient variation and effects.
    
    // Apply subtle lighting factor to scene
    vec3 litColor = sceneColor.rgb * lightFactor;
    
    // Apply brightness
    litColor *= uBrightness;
    
    // ========== POST-PROCESSING EFFECTS ==========
    
    // Vignette (offset towards right/shadow side)
    vec2 vignetteCoord = uv - vec2(0.35, 0.5);
    float vignetteFactor = 1.0 - dot(vignetteCoord, vignetteCoord) * uVignette;
    vignetteFactor = clamp(vignetteFactor, 0.0, 1.0);
    litColor *= vignetteFactor;
    
    // Contrast adjustment
    litColor = (litColor - 0.5) * uContrast + 0.5;
    
    // Saturation adjustment
    float lum = luminance(litColor);
    litColor = mix(vec3(lum), litColor, uSaturation);
    
    // Clamp to valid range
    litColor = clamp(litColor, 0.0, 1.0);
    
    fragColor = vec4(litColor, sceneColor.a);
}
