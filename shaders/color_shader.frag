#version 460 core
#include <flutter/runtime_effect.glsl>

// ==============================================================================
// COLOR SHADER - Simple solid color output
// ==============================================================================
//
// This shader outputs a solid color. It can be used with Canvas.drawVertices
// for colored shapes where all vertices have the same color.
//
// For per-vertex colors, use Paint.color or vertex colors in drawVertices.
//
// ==============================================================================

uniform vec4 uColor;

out vec4 fragColor;

void main() {
    // Output the uniform color directly
    fragColor = uColor;
}
