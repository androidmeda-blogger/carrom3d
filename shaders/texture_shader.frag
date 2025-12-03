#version 460 core
#include <flutter/runtime_effect.glsl>

// ==============================================================================
// POST-PROCESSING SHADER WITH REALISTIC LIGHTING EFFECTS
// ==============================================================================
// 
// Adds polish and realism:
// - Subtle ambient lighting gradient
// - Specular highlights/shine
// - Soft glow/bloom effect
// - Vignette and color grading
//
// ==============================================================================

uniform sampler2D uScene;      // Pre-rendered scene
uniform vec2 uResolution;      // Screen resolution

// Directional light parameters
uniform vec3 uLightDir;        // Light direction (normalized)
uniform float uAmbient;        // Ambient light intensity
uniform float uDiffuse;        // Diffuse intensity
uniform float uSpecular;       // Specular/shine intensity
uniform float uShininess;      // Specular tightness

// Effect parameters
uniform float uVignette;       // Vignette strength
uniform float uContrast;       // Contrast adjustment
uniform float uSaturation;     // Saturation adjustment
uniform float uBrightness;     // Overall brightness

out vec4 fragColor;

// Convert RGB to luminance
float luminance(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

// Soft glow/bloom - samples nearby bright pixels
vec3 sampleGlow(vec2 uv, vec2 texelSize) {
    vec3 glow = vec3(0.0);
    float total = 0.0;
    
    // Sample in a small radius for subtle glow
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 offset = vec2(float(x), float(y)) * texelSize * 2.0;
            vec3 sample_color = texture(uScene, uv + offset).rgb;
            
            // Weight by brightness - brighter pixels contribute more glow
            float brightness = luminance(sample_color);
            float weight = smoothstep(0.5, 1.0, brightness); // Only bright areas glow
            
            glow += sample_color * weight;
            total += weight;
        }
    }
    
    return total > 0.0 ? glow / total : vec3(0.0);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    vec2 texelSize = 1.0 / uResolution;
    vec4 sceneColor = texture(uScene, uv);
    
    // Skip processing for fully transparent pixels
    if (sceneColor.a < 0.01) {
        fragColor = sceneColor;
        return;
    }
    
    vec3 baseColor = sceneColor.rgb;
    
    // ========== AMBIENT LIGHTING GRADIENT ==========
    // Subtle gradient from light side (left) to shadow side (right)
    float xGradient = 1.0 - uv.x * 0.12;
    float yGradient = 1.0 - uv.y * 0.08;
    float ambientFactor = xGradient * yGradient;
    
    vec3 litColor = baseColor * ambientFactor;
    
    // ========== SPECULAR HIGHLIGHTS ==========
    // Add shine to bright areas (simulates reflective surfaces)
    float brightness = luminance(baseColor);
    
    // Specular hotspot position (where light reflects toward viewer)
    // Light from left-front means highlight appears on left side
    vec2 specularCenter = vec2(0.35, 0.4); // Upper-left area
    float specularDist = length(uv - specularCenter);
    float specularMask = 1.0 - smoothstep(0.0, 0.6, specularDist);
    
    // Only apply specular to already bright areas (the pieces/board)
    float specularIntensity = specularMask * brightness * uSpecular;
    vec3 specularColor = vec3(1.0, 0.98, 0.95); // Warm white highlight
    litColor += specularColor * specularIntensity * 0.15;
    
    // ========== SOFT GLOW/BLOOM ==========
    // Add subtle glow from bright areas
    vec3 glow = sampleGlow(uv, texelSize);
    litColor += glow * 0.08; // Subtle bloom
    
    // ========== BRIGHTNESS ==========
    litColor *= uBrightness;
    
    // ========== VIGNETTE ==========
    // Offset toward shadow side for dramatic effect
    vec2 vignetteCoord = uv - vec2(0.4, 0.5);
    float vignetteFactor = 1.0 - dot(vignetteCoord, vignetteCoord) * uVignette;
    vignetteFactor = clamp(vignetteFactor, 0.0, 1.0);
    vignetteFactor = smoothstep(0.0, 1.0, vignetteFactor); // Softer falloff
    litColor *= vignetteFactor;
    
    // ========== COLOR GRADING ==========
    // Contrast
    litColor = (litColor - 0.5) * uContrast + 0.5;
    
    // Saturation
    float lum = luminance(litColor);
    litColor = mix(vec3(lum), litColor, uSaturation);
    
    // Subtle warm tint in highlights, cool in shadows
    vec3 warmTint = vec3(1.02, 1.0, 0.97);
    vec3 coolTint = vec3(0.97, 0.98, 1.02);
    litColor *= mix(coolTint, warmTint, smoothstep(0.3, 0.7, lum));
    
    // ========== FINAL OUTPUT ==========
    litColor = clamp(litColor, 0.0, 1.0);
    
    fragColor = vec4(litColor, sceneColor.a);
}
