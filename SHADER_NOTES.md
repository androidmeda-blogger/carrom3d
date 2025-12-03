# Flutter Shader Implementation Notes

## Current Implementation

The renderer now supports **post-processing lighting** applied to the entire rendered scene.

### How It Works

1. **Render scene** to an offscreen image (using `PictureRecorder`)
2. **Apply post-processing shader** that adds lighting effects
3. **Draw the processed image** to the screen

### Lighting Features

- **Ambient lighting** - Base illumination
- **Diffuse lighting** - Direction-dependent shading
- **Specular highlights** - Shiny reflections
- **Distance attenuation** - Light falloff
- **Vignette effect** - Darkened edges
- **Contrast/Saturation** - Color adjustments

### Configurable Parameters (in `game_renderer.dart`)

```dart
// Post-processing toggle
enablePostProcessing = true;

// Directional light (from left-top at an angle)
lightDirX = -0.6;    // Light from left side
lightDirY = -0.4;    // Light from top
lightDirZ = 0.7;     // Light from above

// Lighting intensities
ambient = 0.35;      // Base illumination (0-1)
diffuse = 0.75;      // Directional shading (0-1)
specular = 0.25;     // Specular highlights (0-1)
shininess = 24.0;    // Highlight tightness
brightness = 1.05;   // Overall brightness

// Effects
vignette = 0.4;      // Edge darkening (0-1)
contrast = 1.05;     // Contrast (1.0 = normal)
saturation = 1.1;    // Saturation (1.0 = normal)

// Shadows
enableShadows = true;
shadowOffsetX = 0.03;   // Shadow X offset (game units)
shadowOffsetY = 0.02;   // Shadow Y offset (game units)
shadowOpacity = 0.3;    // Shadow darkness (0-1)
shadowScale = 1.2;      // Shadow size relative to piece
```

---

## Critical Limitation (for Mesh Texturing)

**Flutter fragment shaders CANNOT access interpolated per-vertex data from `Canvas.drawVertices`.**

### What This Means

- `FlutterFragCoord()` returns **screen pixel coordinates**, not mesh texture coordinates
- You CANNOT sample textures using mesh UVs in a custom fragment shader
- Custom fragment shaders work for **screen-space post-processing only**

### Why the Previous Implementation Caused Artifacts

The shader was doing:
```glsl
vec2 uv = FlutterFragCoord().xy / uResolution;
vec4 texColor = texture(uTexture, uv);
```

This sampled the texture based on **where on the screen** each pixel was, NOT based on the mesh's texture coordinates. This caused:
- Black triangular artifacts (where screen coords mapped outside texture bounds)
- Incorrect texture mapping (texture stretched across screen, not mesh)

## Correct Approach

### For Texture Mapping (Mesh UVs) ✅

Use `ImageShader` - it properly uses `textureCoordinates` from `drawVertices`:

```dart
paint.shader = ImageShader(
  texture,
  TileMode.clamp,
  TileMode.clamp,
  Matrix4.identity().storage,
);

canvas.drawVertices(
  ui.Vertices(
    ui.VertexMode.triangles,
    screenPositions,
    textureCoordinates: meshUVs,  // ImageShader uses these!
    indices: indices,
  ),
  BlendMode.srcOver,
  paint,
);
```

### For Solid Colors ✅

Use `Paint.color` or a simple color shader:

```dart
paint.color = const Color(0xE6333333);
// OR
colorShader!.setFloat(0, r);
colorShader!.setFloat(1, g);
colorShader!.setFloat(2, b);
colorShader!.setFloat(3, a);
paint.shader = colorShader;
```

### For Screen-Space Post-Processing ✅

Custom fragment shaders work for full-screen effects where screen position IS the correct coordinate:

```glsl
// This works for post-processing because we WANT screen-based sampling
vec2 uv = FlutterFragCoord().xy / uResolution;
vec4 color = texture(uFramebuffer, uv);
// Apply blur, vignette, color grading, etc.
```

## Summary

| Use Case | Correct Approach |
|----------|-----------------|
| Mesh textures | `ImageShader` + `textureCoordinates` |
| Solid colors | `Paint.color` or simple color shader |
| Post-processing | Custom fragment shader with screen coords |
| Per-vertex colors | `colors` parameter in `Vertices` |

## Current Implementation

The current renderer uses:
- **`ImageShader`** for all textured objects (board, pieces, walls, floor)
- **`Paint.color`** or **color shader** for transparent colored objects (arrows, arcs)

This correctly replicates the Java OpenGL ES 2.0 behavior where:
- Java vertex shader passed `v_TexCoordinate` to fragment shader
- Java fragment shader sampled `texture2D(u_Texture, v_TexCoordinate)`

In Flutter, `ImageShader` + `textureCoordinates` achieves the same result.

## Future: Adding Lighting

To add lighting effects in Flutter, options include:

1. **Bake lighting into textures** (pre-computed)
2. **Use vertex colors** to simulate lighting (per-vertex shading)
3. **Post-processing pass** with a fragment shader over the final rendered image
4. **Multiple render passes** (render to texture, then apply lighting shader)

Option 3 (post-processing) is the most practical for Flutter since it uses screen-space coordinates where fragment shaders work correctly.

