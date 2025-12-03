#version 460 core
#include <flutter/runtime_effect.glsl>

// ==============================================================================
// POST-PROCESSING DIRECTIONAL LIGHTING SHADER
// ==============================================================================
// 
// Applies directional lighting from a specific angle (like sunlight).
// Light comes from the left-top at an angle towards the board.
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

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    vec4 sceneColor = texture(uScene, uv);
    
    // Skip processing for fully transparent pixels
    if (sceneColor.a < 0.01) {
        fragColor = sceneColor;
        return;
    }
    
    // ========== DIRECTIONAL LIGHTING ==========
    
    // Normalize light direction (should already be normalized, but just in case)
    vec3 lightDir = normalize(uLightDir);
    
    // Create a pseudo-normal that varies across the screen
    // This simulates a surface that faces slightly different directions
    // creating the illusion of 3D depth
    vec3 normal = normalize(vec3(
        (uv.x - 0.5) * 0.3,  // Slight X tilt based on position
        (uv.y - 0.5) * 0.3,  // Slight Y tilt based on position
        1.0                   // Mostly facing camera
    ));
    
    // Ambient component (constant base illumination)
    vec3 ambient = uAmbient * sceneColor.rgb;
    
    // Diffuse component (directional, no falloff for distant light)
    float diff = max(dot(normal, lightDir), 0.0);
    // Add a gradient based on screen position to enhance directional feel
    // Light coming from left means left side is brighter
    float directionalGradient = 0.7 + 0.3 * (1.0 - uv.x); // Brighter on left
    diff *= directionalGradient;
    vec3 diffuse = uDiffuse * diff * sceneColor.rgb;
    
    // Specular component (Blinn-Phong)
    vec3 viewDir = vec3(0.0, 0.0, 1.0); // Camera looking at screen
    vec3 halfDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(normal, halfDir), 0.0), uShininess);
    // Specular also affected by position (highlights on left side)
    spec *= directionalGradient;
    vec3 specular = uSpecular * spec * vec3(1.0, 0.98, 0.95); // Slightly warm specular
    
    // Combine lighting
    vec3 litColor = ambient + diffuse + specular;
    
    // Apply brightness
    litColor *= uBrightness;
    
    // ========== POST-PROCESSING EFFECTS ==========
    
    // Vignette (darken edges, slightly offset towards right to enhance directional feel)
    vec2 vignetteCoord = uv - vec2(0.4, 0.5); // Offset vignette center slightly left
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
