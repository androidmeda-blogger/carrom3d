import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'matrix_utils.dart' as matrix;
import 'mesh_data.dart';
import 'texture_loader.dart';

/// GameRenderer - Direct port of GameRenderer.java
/// Render logic is kept 1:1 as much as possible; implementation uses Canvas.
class GameRenderer {
  // Matrices
  late Float32List modelMatrix;
  late Float32List viewMatrix;
  late Float32List tmpViewMatrix;
  late Float32List projectionMatrix;
  late Float32List mvpMatrix;
  late Float32List mvMatrix;

  // Mesh data (mirrors GameRenderer.java fields)
  late Float32List cubePositions;
  late Float32List cubeTextureCoordinates;
  late Float32List cylinderPositions;
  late Float32List cylinderTextureCoordinates;
  late Float32List diskPositions;
  late Float32List arrowHeadPositions;
  late Float32List arrowTailPositions;
  late Float32List arrowTailTextureCoordinates;
  late Float32List arcPositions;
  late Float32List objectColors; // kept for completeness, but color is constant
  late Float32List floorPositions;
  late Float32List floorTextureCoordinates;
  late Float32List boardSurfacePositions;
  late Float32List boardSurfaceTextureCoordinates;

  // “Texture handles” -> images
  ui.Image? frameTexture;
  ui.Image? surfaceTexture;
  ui.Image? redTexture;
  ui.Image? whiteTexture;
  ui.Image? blackTexture;
  ui.Image? diskTexture;
  ui.Image? hDiskTexture;
  ui.Image? rDiskTexture;
  ui.Image? floorTexture;
  ui.Image? wallTexture;
  ui.Image? chairLegTexture;

  ui.Image? rDiskBorderTexture;
  ui.Image? hDiskBorderTexture;
  ui.Image? diskBorderTexture;
  ui.Image? whiteBorderTexture;
  ui.Image? blackBorderTexture;
  ui.Image? redBorderTexture;

  // Shader programs
  ui.FragmentShader? postProcessShader; // Post-processing lighting shader
  ui.FragmentShader? colorShader;       // Used for solid-color shapes

  // Post-processing / lighting parameters
  bool enablePostProcessing = true;
  
  // Directional light - vector pointing FROM surface TO light source
  // Light comes from viewer's direction (front-left-above)
  // Coordinate system: Y is UP, Z is toward viewer (front)
  double lightDirX = -0.5;   // Light slightly from left
  double lightDirY = 0.7;    // Light from above (Y is up) - makes tops bright
  double lightDirZ = 0.5;    // Light from front (toward viewer)
  
  // Post-processing parameters
  double ambient = 0.5;      // Ambient factor for shader
  double diffuse = 0.7;      // Diffuse factor for shader
  double specular = 0.6;     // Specular/shine intensity (higher = more shiny)
  double shininess = 32.0;   // Specular tightness
  double brightness = 1.05;  // Slight brightness boost
  
  double vignette = 0.35;    // Vignette strength
  double contrast = 1.08;    // Contrast boost for punch
  double saturation = 1.1;   // Slightly more vivid colors
  
  // Shadow parameters
  // Light from user's left-front → shadows cast to back-right (away from user)
  // Game coords: +X is right, +Y is toward back of board (away from viewer)
  bool enableShadows = true;
  double shadowOffsetX = 0.025;  // Shadow to the right (reduced by ~1/3)
  double shadowOffsetY = 0.035;  // Shadow toward back (reduced by ~1/3)
  double shadowOpacity = 0.25;   // Lighter shadow (was 0.4)
  double shadowScale = 1.15;     // Shadow size relative to piece

  // Piece positions and states
  List<double> xposPieces = List.filled(32, 0.0);
  List<double> yposPieces = List.filled(32, 0.0);
  List<int> presents = List.filled(32, 0);
  List<bool> zRaised = List.filled(32, false);
  bool aboutToCancel = false;

  double screenWidth = 0;
  double screenHeight = 0;

  // View / camera parameters
  double yangle = 0;
  double xangle = 0;
  double eyedisp = 0;
  double scale = 1;
  bool rotateXFirst = true;

  // Camera position
  double eyeX = 0.0;
  double eyeY = 3.5;
  double eyeZ = 0.0;

  // Look-at target
  final double lookX = 0.0;
  final double lookY = -5.0;
  final double lookZ = 0.0;

  // Up vector
  final double upX = 0.0;
  double upY = 0.0;
  double upZ = -1.0;

  // Shooting mode
  bool shootingMode = false;
  bool readyToShoot = false;
  bool shooting = false;
  double shootingX = 0;
  double shootingY = 0;

  // Arrows
  List<double> arrowX = List.filled(16, 0.0);
  List<double> arrowY = List.filled(16, 0.0);
  List<double> arrowLen = List.filled(16, 0.0);
  List<double> arrowAngle = List.filled(16, 0.0);
  bool arrowReady = false;
  int arrowCount = 0;
  bool showArrows = false;

  double arrowHeadWidth = 0.06;
  double arrowWidth = 0.02;

  // Arcs
  bool showArcs = false;
  double arcAngle = 0;

  // Cross (cancel indicator)
  double crossX1 = 0.3;
  double crossY1 = 0.6;
  double crossX2 = 0.3;
  double crossY2 = 0.6;
  double crossAngle = 0;

  GameRenderer() {
    // Matrices
    modelMatrix = matrix.MatrixUtils.identity();
    viewMatrix = matrix.MatrixUtils.identity();
    tmpViewMatrix = matrix.MatrixUtils.identity();
    projectionMatrix = matrix.MatrixUtils.identity();
    mvpMatrix = matrix.MatrixUtils.identity();
    mvMatrix = matrix.MatrixUtils.identity();

    // Mesh data (equivalent to MeshData.initData(this) in Java ctor)
    MeshData.initData(this);
  }

  /// Load shaders (equivalent to onSurfaceCreated shader compilation)
  Future<void> loadShaders() async {
    try {
      // Load post-processing shader (lighting + effects)
      final postProcessProgram = await ui.FragmentProgram.fromAsset(
        'shaders/texture_shader.frag',
      );
      postProcessShader = postProcessProgram.fragmentShader();

      // Load color shader for solid-color shapes
      final colorProgram = await ui.FragmentProgram.fromAsset(
        'shaders/color_shader.frag',
      );
      colorShader = colorProgram.fragmentShader();
      
      print('Shaders loaded: postProcess=${postProcessShader != null}, color=${colorShader != null}');
    } catch (e) {
      print('Error loading shaders: $e');
      // Don't rethrow - allow game to run without post-processing
      enablePostProcessing = false;
    }
  }

  /// Load textures (equivalent to onSurfaceCreated texture loading)
  Future<void> loadTextures() async {
    final textures = await TextureLoader.loadAllTextures();

    frameTexture = textures['frame'];
    surfaceTexture = textures['surface'];
    redTexture = textures['red'];
    whiteTexture = textures['white'];
    blackTexture = textures['black'];
    diskTexture = textures['disk'];
    hDiskTexture = textures['hdisk'];
    rDiskTexture = textures['rdisk'];
    floorTexture = textures['floor'];
    wallTexture = textures['wall'];
    chairLegTexture = frameTexture; // matches Java using frame texture

    rDiskBorderTexture = textures['rdisk_border'];
    hDiskBorderTexture = textures['hdisk_border'];
    diskBorderTexture = textures['disk_border'];
    whiteBorderTexture = textures['white_border'];
    blackBorderTexture = textures['black_border'];
    redBorderTexture = textures['red_border'];
  }

  /// Equivalent to Java initView() (camera reset)
  void initView() {
    yangle = 0;
    xangle = -30;
    eyedisp = 0;
    scale = 1;
    rotateXFirst = true;
    upY = 0;
    upZ = -1;
  }

  /// Equivalent to Java updateEye()
  void updateEye(double ydiff, double xdiff, double scalediff, double eyediff) {
    yangle += ydiff;
    xangle += xdiff;
    scale += scalediff;
    eyedisp += eyediff;

    matrix.MatrixUtils.setLookAt(
      tmpViewMatrix,
      eyeX,
      eyeY,
      eyeZ,
      lookX,
      lookY,
      lookZ,
      upX,
      upY,
      upZ,
    );

    matrix.MatrixUtils.translate(tmpViewMatrix, eyedisp, 0, 0);

    if (rotateXFirst) {
      matrix.MatrixUtils.rotate(tmpViewMatrix, xangle, 1, 0, 0);
      matrix.MatrixUtils.rotate(tmpViewMatrix, yangle, 0, 1, 0);
    } else {
      matrix.MatrixUtils.rotate(tmpViewMatrix, yangle, 0, 1, 0);
      matrix.MatrixUtils.rotate(tmpViewMatrix, xangle, 1, 0, 0);
    }

    matrix.MatrixUtils.scale(tmpViewMatrix, scale, scale, scale);

    // swap
    final temp = viewMatrix;
    viewMatrix = tmpViewMatrix;
    tmpViewMatrix = temp;
  }

  /// Equivalent to Java onSurfaceChanged()
  void onSurfaceChanged(double width, double height) {
    screenWidth = width;
    screenHeight = height;

    double scaleFactor;
    if (width > height) {
      scaleFactor = 0.30;
    } else {
      final ratio = width / height;
      scaleFactor = 0.467 * 0.63 / ratio;
    }

    final ratio = width / height;
    final left = -ratio * scaleFactor;
    final right = ratio * scaleFactor;
    final bottom = -scaleFactor;
    final top = scaleFactor;
    const near = 1.0;
    const far = 18.0;

    matrix.MatrixUtils.frustum(
      projectionMatrix,
      left,
      right,
      bottom,
      top,
      near,
      far,
    );
  }

  /// Equivalent to Java onDrawFrame()
  void onDrawFrame(Canvas canvas, Size size) {
    // Check if post-processing is enabled and safe to use
    final canUsePostProcessing = enablePostProcessing && 
                                  postProcessShader != null &&
                                  _skipPostProcessFrames <= 0 &&
                                  _postProcessFailCount < _maxPostProcessFails;
    
    if (canUsePostProcessing) {
      // Render scene to offscreen canvas, then apply post-processing
      _renderWithPostProcessing(canvas, size);
    } else {
      // Direct rendering without post-processing
      // Still decrement skip counter if needed
      if (_skipPostProcessFrames > 0) {
        _skipPostProcessFrames--;
      }
      _renderScene(canvas, size);
    }
  }

  // Track post-processing state
  int _postProcessFailCount = 0;
  static const int _maxPostProcessFails = 3;
  
  // Skip frames after resume to let GPU context stabilize
  int _skipPostProcessFrames = 0;
  static const int _framesToSkipAfterResume = 30; // ~0.5 seconds at 60fps

  /// Render scene with post-processing lighting
  void _renderWithPostProcessing(Canvas canvas, Size size) {
    // Note: Safety checks are now done in onDrawFrame before calling this method
    
    // Validate size
    final width = size.width.toInt();
    final height = size.height.toInt();
    if (width <= 0 || height <= 0 || width > 4096 || height > 4096) {
      _renderScene(canvas, size);
      return;
    }

    ui.Image? sceneImage;
    
    try {
      // 1. Create offscreen canvas to render the scene
      final recorder = ui.PictureRecorder();
      final offscreenCanvas = Canvas(recorder);
      
      // 2. Render the entire scene to offscreen canvas
      _renderScene(offscreenCanvas, size);
      
      // 3. Convert to image
      final picture = recorder.endRecording();
      sceneImage = picture.toImageSync(width, height);
      
      // 4. Apply post-processing shader
      _applyPostProcessing(canvas, size, sceneImage);
      
      // Success - reset failure count
      _postProcessFailCount = 0;
    } catch (e) {
      // Increment failure count
      _postProcessFailCount++;
      print('Post-processing failed (attempt $_postProcessFailCount): $e');
      
      // Fallback: render directly without post-processing
      _renderScene(canvas, size);
    } finally {
      // Clean up resources
      sceneImage?.dispose();
    }
  }

  /// Reset post-processing state (call on app resume)
  void resetPostProcessing() {
    _postProcessFailCount = 0;
    // Skip post-processing for several frames to let GPU stabilize
    _skipPostProcessFrames = _framesToSkipAfterResume;
    print('Post-processing paused for $_framesToSkipAfterResume frames');
  }

  /// Apply post-processing lighting shader
  void _applyPostProcessing(Canvas canvas, Size size, ui.Image sceneImage) {
    final shader = postProcessShader!;
    
    // Set scene texture (sampler at index 0)
    shader.setImageSampler(0, sceneImage);
    
    // Set resolution (floats start at index 0)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    
    // Normalize light direction
    final lightLen = math.sqrt(lightDirX * lightDirX + lightDirY * lightDirY + lightDirZ * lightDirZ);
    shader.setFloat(2, lightDirX / lightLen);
    shader.setFloat(3, lightDirY / lightLen);
    shader.setFloat(4, lightDirZ / lightLen);
    
    // Set lighting parameters
    shader.setFloat(5, ambient);
    shader.setFloat(6, diffuse);
    shader.setFloat(7, specular);
    shader.setFloat(8, shininess);
    
    // Set effect parameters
    shader.setFloat(9, vignette);
    shader.setFloat(10, contrast);
    shader.setFloat(11, saturation);
    shader.setFloat(12, brightness);
    
    // Draw full-screen quad with shader
    final paint = Paint()..shader = shader;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  /// Render the scene (called by both direct and post-processing paths)
  void _renderScene(Canvas canvas, Size size) {
    // Clear to white like glClearColor(1,1,1,1)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Java: first program is texture program -> we draw textured stuff first.

    // Background (floor, walls, legs)
    drawBackground(canvas, size);

    // Board
    matrix.MatrixUtils.setIdentity(modelMatrix);
    drawCube(canvas, size);
    drawBoardFace(canvas, size);

    // Draw piece shadows first (before pieces)
    if (enableShadows) {
      _drawPieceShadows(canvas, size);
    }

    // Pieces
    final sortedPieces = <_PieceSortEntry>[];
    for (int i = 0; i < 20; i++) {
      if (presents[i] == 0) continue;

      matrix.MatrixUtils.setIdentity(modelMatrix);

      double height = 0;
      if (presents[i] == MeshData.HOLE_ANI_LIMIT - 1) {
        height =
            -MeshData.HEIGHT *
            (MeshData.HOLE_ANI_LIMIT - presents[i]) /
            MeshData.HOLE_ANI_LIMIT;
      }

      if (zRaised[i]) {
        height += MeshData.HEIGHT;
      }

      matrix.MatrixUtils.translate(
        modelMatrix,
        xposPieces[i],
        MeshData.BOARD_TOP + MeshData.HEIGHT / 2 + height,
        -yposPieces[i],
      );

      // Calculate NDC Z
      // Center of piece is (0,0,0) in local space
      final ndcZ = _getNDC_Z(modelMatrix, 0, 0, 0);
      sortedPieces.add(
        _PieceSortEntry(i, ndcZ, Float32List.fromList(modelMatrix)),
      );
    }

    // Sort by NDC Z descending (furthest first)
    // In OpenGL NDC, -1 is near, 1 is far. So larger Z is further away.
    // Wait, standard OpenGL depth range is -1 to 1.
    // But Flutter/Skia might differ?
    // Let's assume standard GL. If 1 is far, we want to draw 1 first.
    // So descending sort.
    sortedPieces.sort((a, b) => b.ndcZ.compareTo(a.ndcZ));

    for (final entry in sortedPieces) {
      // Restore model matrix
      for (int k = 0; k < 16; k++) modelMatrix[k] = entry.matrix[k];
      // opaque cylinder
      drawCylinder(canvas, size, entry.index, false);
    }

    // Cross (cancel)
    if (aboutToCancel) {
      drawCross(canvas, size);
    }

    // Java switches to color program + blending here.
    // We mimic that by drawing transparent/colored shapes AFTER all opaque stuff
    // and using BlendMode.plus where appropriate.

    // Shooting guide ghost pieces
    if (readyToShoot && !aboutToCancel && (shootingX != 0 || shootingY != 0)) {
      double shootingDist = math.sqrt(
        shootingX * shootingX + shootingY * shootingY,
      );
      double adjustedShootingX = shootingX;
      double adjustedShootingY = shootingY;

      if (shootingDist > MeshData.DISK_SHOOTING_MAX_DIST) {
        adjustedShootingX =
            shootingX / shootingDist * MeshData.DISK_SHOOTING_MAX_DIST;
        adjustedShootingY =
            shootingY / shootingDist * MeshData.DISK_SHOOTING_MAX_DIST;
      }

      for (int i = 1; i <= 3; i++) {
        double x = xposPieces[0] + adjustedShootingX * i / 3;
        double y = yposPieces[0] + adjustedShootingY * i / 3;

        matrix.MatrixUtils.setIdentity(modelMatrix);
        matrix.MatrixUtils.translate(
          modelMatrix,
          x,
          MeshData.BOARD_TOP + MeshData.HEIGHT / 2,
          -y,
        );

        // transparent ghost disk
        drawCylinder(canvas, size, 0, true);
      }
    }

    // Arrows
    if (arrowReady && showArrows) {
      drawArrows(canvas, size);
    }

    // Arcs
    if (showArcs && !shootingMode) {
      drawArcs(canvas, size);
    }

    // Java then restores cull/depth/blend, which isn’t needed for Canvas.
  }

  // ---------- Board ----------

  void drawCube(Canvas canvas, Size size) {
    _drawMesh(
      canvas,
      size,
      cubePositions,
      0,
      6 * 13,
      frameTexture,
      texCoords: cubeTextureCoordinates,
      applyLighting: true, // Apply lighting to board frame
    );
  }

  void drawBoardFace(Canvas canvas, Size size) {
    _drawMesh(
      canvas,
      size,
      boardSurfacePositions,
      0,
      boardSurfacePositions.length ~/ 3,
      surfaceTexture,
      texCoords: boardSurfaceTextureCoordinates,
      applyLighting: true, // Apply lighting to board surface
    );
  }

  // ---------- Shadows ----------

  /// Draw shadows for all pieces on the board
  /// Shadows are drawn as flat ellipses ON the board surface in 3D space
  void _drawPieceShadows(Canvas canvas, Size size) {
    final shadowColor = Color.fromRGBO(0, 0, 0, shadowOpacity);
    
    for (int i = 0; i < 20; i++) {
      if (presents[i] == 0) continue;
      
      // Skip pieces that are sinking into holes
      if (presents[i] != MeshData.HOLE_ANI_LIMIT - 1 && presents[i] < MeshData.HOLE_ANI_LIMIT - 1) {
        continue;
      }
      
      // Get piece position
      final pieceX = xposPieces[i];
      final pieceY = yposPieces[i];
      
      // Calculate shadow position (offset based on light direction)
      final shadowX = pieceX + shadowOffsetX;
      final shadowY = pieceY + shadowOffsetY;
      
      // Get the shadow radius based on piece type
      final isStrikerDisk = (i == 0);
      final baseRadius = isStrikerDisk 
          ? MeshData.RADIUS * MeshData.DISK_RADIUS_FACTOR
          : MeshData.RADIUS;
      final shadowRadius = baseRadius * shadowScale;
      
      // Draw shadow as a flat circle on the board surface
      _drawFlatShadowOnBoard(canvas, size, shadowX, shadowY, shadowRadius, shadowColor);
    }
  }

  /// Draw a flat circular shadow on the board surface
  /// This creates proper 3D geometry that lies flat on the board
  void _drawFlatShadowOnBoard(
    Canvas canvas,
    Size size,
    double centerX,
    double centerY,
    double radius,
    Color shadowColor,
  ) {
    // Create vertices for a flat circle on the board (Y = BOARD_TOP)
    // Use triangle fan: center + points around circumference
    const int segments = 24; // Number of segments for the circle
    final List<Offset> screenPoints = [];
    final List<double> zValues = [];
    
    // Set up model matrix for shadow position
    matrix.MatrixUtils.setIdentity(modelMatrix);
    
    // Calculate MVP once
    matrix.MatrixUtils.multiplyMM(mvMatrix, viewMatrix, modelMatrix);
    matrix.MatrixUtils.multiplyMM(mvpMatrix, projectionMatrix, mvMatrix);
    
    // Transform center point (on board surface)
    final centerPoint = matrix.MatrixUtils.transformPoint(
      mvpMatrix,
      centerX,
      MeshData.BOARD_TOP + 0.001, // Just above board to prevent z-fighting
      -centerY, // Note: Y in game coords maps to -Z in 3D
    );
    
    // Skip if center is behind camera
    if (centerPoint[2] > 0.95 || centerPoint[2] < -2) return;
    
    // Add center point
    screenPoints.add(Offset(
      (centerPoint[0] + 1) * size.width / 2,
      (1 - centerPoint[1]) * size.height / 2,
    ));
    zValues.add(centerPoint[2]);
    
    // Add circumference points
    for (int i = 0; i <= segments; i++) {
      final angle = (i / segments) * 2 * math.pi;
      final px = centerX + radius * math.cos(angle);
      final py = centerY + radius * math.sin(angle);
      
      // Transform point on board surface
      final point = matrix.MatrixUtils.transformPoint(
        mvpMatrix,
        px,
        MeshData.BOARD_TOP + 0.001,
        -py,
      );
      
      // Skip if behind camera
      if (point[2] > 0.95 || point[2] < -2) continue;
      
      screenPoints.add(Offset(
        (point[0] + 1) * size.width / 2,
        (1 - point[1]) * size.height / 2,
      ));
      zValues.add(point[2]);
    }
    
    // Need at least 3 points to draw
    if (screenPoints.length < 3) return;
    
    // Create triangle fan indices (center -> each pair of adjacent points)
    final List<Offset> vertices = [];
    final List<int> indices = [];
    
    for (int i = 0; i < screenPoints.length; i++) {
      vertices.add(screenPoints[i]);
    }
    
    // Triangle fan: center (0) connects to each pair
    for (int i = 1; i < vertices.length - 1; i++) {
      indices.add(0);      // Center
      indices.add(i);      // Current point
      indices.add(i + 1);  // Next point
    }
    
    if (indices.isEmpty) return;
    
    // Draw with blur for soft shadow edges
    final shadowPaint = Paint()
      ..color = shadowColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        vertices,
        indices: indices,
      ),
      BlendMode.srcOver,
      shadowPaint,
    );
  }

  // ---------- Cylinders / disks ----------

  void drawCylinder(
    Canvas canvas,
    Size size,
    int pieceIndex,
    bool transparent,
  ) {
    final positions = pieceIndex == 0 ? diskPositions : cylinderPositions;

    if (transparent) {
      // Java: uses color program + blending, ignores textures.
      final totalVerts =
          6 * MeshData.CIRC_SEGMENTS + 3 * MeshData.CIRC_SEGMENTS;
      _drawColoredMesh(canvas, size, positions, 0, totalVerts);
      return;
    }

    ui.Image? borderTexture;
    ui.Image? topTexture;

    if (pieceIndex == 0) {
      if (aboutToCancel) {
        borderTexture = rDiskBorderTexture;
        topTexture = rDiskTexture;
      } else if (shootingMode) {
        borderTexture = hDiskBorderTexture;
        topTexture = hDiskTexture;
      } else {
        borderTexture = diskBorderTexture;
        topTexture = diskTexture;
      }
    } else if (pieceIndex == 1) {
      borderTexture = redBorderTexture;
      topTexture = redTexture;
    } else if (pieceIndex > 1 && pieceIndex < 11) {
      borderTexture = whiteBorderTexture;
      topTexture = whiteTexture;
    } else {
      borderTexture = blackBorderTexture;
      topTexture = blackTexture;
    }

    // Border (sides) - apply lighting based on face normals
    _drawMesh(
      canvas,
      size,
      positions,
      0,
      6 * MeshData.CIRC_SEGMENTS,
      borderTexture,
      texCoords: cylinderTextureCoordinates,
      applyLighting: true, // Enable per-face lighting for piece sides
    );

    // Top - apply lighting (mostly uniform since top faces up)
    _drawMesh(
      canvas,
      size,
      positions,
      6 * MeshData.CIRC_SEGMENTS,
      3 * MeshData.CIRC_SEGMENTS,
      topTexture,
      texCoords: cylinderTextureCoordinates,
      applyLighting: true, // Enable per-face lighting for piece top
    );
  }

  // ---------- Arrows ----------

  void drawArrows(Canvas canvas, Size size) {
    const factor = 1.1;

    for (int i = 0; i < arrowCount && i < 16; i++) {
      matrix.MatrixUtils.setIdentity(modelMatrix);
      final xscale = arrowLen[i];
      final yscale = MeshData.HEIGHT * factor;
      final zscale = arrowWidth;

      matrix.MatrixUtils.rotate(modelMatrix, arrowAngle[i], 0, 1, 0);
      matrix.MatrixUtils.scale(modelMatrix, xscale, yscale, zscale);
      matrix.MatrixUtils.translate(
        modelMatrix,
        arrowX[i] / xscale,
        MeshData.BOARD_TOP / yscale,
        -arrowY[i] / zscale,
      );

      drawArrowTail(canvas, size);
    }

    if (arrowCount > 0 && arrowCount < 16) {
      matrix.MatrixUtils.setIdentity(modelMatrix);
      final xscale = arrowHeadWidth;
      final yscale = MeshData.HEIGHT * factor;
      final zscale = arrowHeadWidth;

      matrix.MatrixUtils.rotate(
        modelMatrix,
        arrowAngle[arrowCount - 1],
        0,
        1,
        0,
      );
      matrix.MatrixUtils.scale(modelMatrix, xscale, yscale, zscale);
      matrix.MatrixUtils.translate(
        modelMatrix,
        (arrowX[arrowCount - 1] + arrowLen[arrowCount - 1]) / xscale,
        MeshData.BOARD_TOP / yscale,
        -arrowY[arrowCount - 1] / zscale,
      );

      drawArrowHead(canvas, size);
    }
  }

  void drawArrowHead(Canvas canvas, Size size) {
    final vertexCount = arrowHeadPositions.length ~/ 3; // 6*3+3 = 21
    _drawColoredMesh(canvas, size, arrowHeadPositions, 0, vertexCount);
  }

  void drawArrowTail(Canvas canvas, Size size) {
    _drawColoredMesh(canvas, size, arrowTailPositions, 0, 6 * 5);
  }

  // ---------- Cross (cancel) ----------

  void drawCross(Canvas canvas, Size size) {
    const factor = 1.1;
    const crossLen = 0.15;

    // First slash
    matrix.MatrixUtils.setIdentity(modelMatrix);
    final xscale = crossLen;
    final yscale = MeshData.HEIGHT * factor;
    final zscale = 0.02;

    matrix.MatrixUtils.rotate(modelMatrix, crossAngle + 45, 0, 1, 0);
    matrix.MatrixUtils.scale(modelMatrix, xscale, yscale, zscale);
    matrix.MatrixUtils.translate(
      modelMatrix,
      (crossX1 - crossLen / 2) / xscale,
      MeshData.BOARD_TOP / yscale,
      -crossY1 / zscale,
    );

    drawCrossModel(canvas, size);

    // Second slash
    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, crossAngle - 45, 0, 1, 0);
    matrix.MatrixUtils.scale(modelMatrix, xscale, yscale, zscale);
    matrix.MatrixUtils.translate(
      modelMatrix,
      (crossX2 - crossLen / 2) / xscale,
      MeshData.BOARD_TOP / yscale,
      -crossY2 / zscale,
    );

    drawCrossModel(canvas, size);
  }

  void drawCrossModel(Canvas canvas, Size size) {
    _drawMesh(
      canvas,
      size,
      arrowTailPositions,
      0,
      6 * 5,
      rDiskTexture,
      texCoords: arrowTailTextureCoordinates,
    );
  }

  // ---------- Arcs ----------

  void drawArcs(Canvas canvas, Size size) {
    drawArcHead(canvas, size, arcAngle, 1);
    drawArcHead(canvas, size, arcAngle + MeshData.ARG_ANGLE_LIMIT - 1.5, -1);
    drawArcHead(canvas, size, arcAngle + 180, 1);
    drawArcHead(
      canvas,
      size,
      arcAngle + MeshData.ARG_ANGLE_LIMIT - 1.5 + 180,
      -1,
    );

    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, arcAngle, 0, 1, 0);
    drawArcModel(canvas, size);

    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, arcAngle + 180, 0, 1, 0);
    drawArcModel(canvas, size);
  }

  void drawArcHead(Canvas canvas, Size size, double baseDegree, int sideSign) {
    matrix.MatrixUtils.setIdentity(modelMatrix);
    const xscale = 0.04;
    final yscale = MeshData.ARC_HEIGHT;
    const zscale = 0.04;
    final radius = (6.3 + 7.0) * MeshData.RADIUS / 2;

    matrix.MatrixUtils.rotate(modelMatrix, baseDegree - sideSign * 90, 0, 1, 0);
    matrix.MatrixUtils.scale(modelMatrix, xscale, yscale, zscale);
    matrix.MatrixUtils.translate(
      modelMatrix,
      0,
      MeshData.BOARD_TOP / yscale,
      -sideSign * radius / zscale,
    );

    drawArrowHead(canvas, size);
  }

  void drawArcModel(Canvas canvas, Size size) {
    final limit = MeshData.ARG_ANGLE_LIMIT * MeshData.CIRC_SEGMENTS ~/ 360;
    _drawColoredMesh(canvas, size, arcPositions, 0, 6 * limit * 3);
  }

  // ---------- Background (floor, walls, legs) ----------

  // ---------- Background (floor, walls, legs) ----------

  void drawBackground(Canvas canvas, Size size) {
    final List<_RenderTriangle> backgroundTriangles = [];

    // Helper to collect triangles
    void collect(
      Float32List m,
      Float32List positions,
      ui.Image? texture,
      Float32List texCoords,
    ) {
      // Calculate MVP for this object
      matrix.MatrixUtils.multiplyMM(mvMatrix, viewMatrix, m);
      matrix.MatrixUtils.multiplyMM(mvpMatrix, projectionMatrix, mvMatrix);

      _collectTriangles(
        backgroundTriangles,
        positions,
        0,
        positions.length ~/ 3,
        texture,
        mvpMatrix,
        size,
        texCoords: texCoords,
      );
    }

    // Floor
    {
      final m = matrix.MatrixUtils.identity();
      matrix.MatrixUtils.translate(
        m,
        -MeshData.FLOOR_WIDTH / 2,
        -1,
        -MeshData.FLOOR_WIDTH / 2,
      );
      // Draw floor immediately (always behind walls/legs)
      matrix.MatrixUtils.multiplyMM(mvMatrix, viewMatrix, m);
      matrix.MatrixUtils.multiplyMM(mvpMatrix, projectionMatrix, mvMatrix);
      _drawTransformedMesh(
        canvas,
        size,
        floorPositions,
        0,
        floorPositions.length ~/ 3,
        floorTexture!,
        mvpMatrix,
        texCoords: floorTextureCoordinates,
      );
    }

    // Walls
    // Wall 1
    {
      final m = matrix.MatrixUtils.identity();
      matrix.MatrixUtils.rotate(m, 90, 1, 0, 0);
      matrix.MatrixUtils.translate(
        m,
        -MeshData.FLOOR_WIDTH / 2,
        -MeshData.FLOOR_WIDTH / 2,
        -MeshData.FLOOR_WIDTH + 2,
      );
      collect(m, floorPositions, wallTexture, floorTextureCoordinates);
    }

    // Wall 2
    {
      final m = matrix.MatrixUtils.identity();
      matrix.MatrixUtils.rotate(m, 90, -1, 0, 0);
      matrix.MatrixUtils.translate(
        m,
        -MeshData.FLOOR_WIDTH / 2,
        -MeshData.FLOOR_WIDTH / 2,
        -2,
      );
      collect(m, floorPositions, wallTexture, floorTextureCoordinates);
    }

    // Wall 3
    {
      final m = matrix.MatrixUtils.identity();
      matrix.MatrixUtils.rotate(m, 90, 0, 0, 1);
      matrix.MatrixUtils.translate(
        m,
        -2,
        -MeshData.FLOOR_WIDTH / 2,
        -MeshData.FLOOR_WIDTH / 2,
      );
      collect(m, floorPositions, wallTexture, floorTextureCoordinates);
    }

    // Wall 4
    {
      final m = matrix.MatrixUtils.identity();
      matrix.MatrixUtils.rotate(m, 90, 0, 0, -1);
      matrix.MatrixUtils.translate(
        m,
        -MeshData.FLOOR_WIDTH + 2,
        -MeshData.FLOOR_WIDTH / 2,
        -MeshData.FLOOR_WIDTH / 2,
      );
      collect(m, floorPositions, wallTexture, floorTextureCoordinates);
    }

    // Table legs
    void collectLeg(double x, double y, double z) {
      final m = matrix.MatrixUtils.identity();
      matrix.MatrixUtils.rotate(m, -90, 0, 0, 1);
      matrix.MatrixUtils.scale(m, 1, 0.1, 0.05);
      matrix.MatrixUtils.translate(m, x, y, z);

      // Legs use arrowTailPositions (cube-like) and no texture in original code?
      // Wait, original code used _drawTableLeg which used arrowTailPositions.
      // And it used chairLegTexture?
      // Let's check definitions.
      // drawTableLeg uses arrowTailPositions.
      // Texture?
      // In Java: drawTableLeg uses chairLegTexture.
      // In Dart: drawTableLeg uses arrowTailPositions and... wait, I need to check what texture it used.
      // In my previous view of drawTableLeg (lines 694-702), it used arrowTailPositions.
      // Texture? It wasn't shown in the snippet but likely chairLegTexture.
      // Let's assume chairLegTexture and arrowTailTextureCoordinates.

      collect(
        m,
        arrowTailPositions,
        chairLegTexture,
        arrowTailTextureCoordinates,
      );
    }

    collectLeg(0, -4, -8);
    collectLeg(0, -4, 8);
    collectLeg(0, 4, -8);
    collectLeg(0, 4, 8);

    // Sort all background triangles by depth (far to near)
    backgroundTriangles.sort((a, b) => b.z.compareTo(a.z));

    // Draw them
    _drawSortedTriangles(canvas, backgroundTriangles);
  }

  void drawFloor(Canvas canvas, Size size) {
    _drawMesh(
      canvas,
      size,
      floorPositions,
      0,
      6 * MeshData.FLOOR_SECTIONS * MeshData.FLOOR_SECTIONS,
      floorTexture,
      texCoords: floorTextureCoordinates,
    );
  }

  void drawWall(Canvas canvas, Size size) {
    _drawMesh(
      canvas,
      size,
      floorPositions,
      0,
      6 * MeshData.FLOOR_SECTIONS * MeshData.FLOOR_SECTIONS,
      wallTexture,
      texCoords: floorTextureCoordinates,
    );
  }

  void drawTableLeg(Canvas canvas, Size size) {
    _drawMesh(
      canvas,
      size,
      arrowTailPositions,
      0,
      6 * 6,
      chairLegTexture,
      texCoords: arrowTailTextureCoordinates,
    );
  }

  // ---------- Core draw helpers ----------

  void _drawMesh(
    Canvas canvas,
    Size size,
    Float32List positions,
    int offset,
    int vertexCount,
    ui.Image? texture, {
    Float32List? texCoords,
    bool applyLighting = false,
  }) {
    if (texture == null) return;

    // mv = view * model
    matrix.MatrixUtils.multiplyMM(mvMatrix, viewMatrix, modelMatrix);
    // mvp = projection * mv
    matrix.MatrixUtils.multiplyMM(mvpMatrix, projectionMatrix, mvMatrix);

    _drawTransformedMesh(
      canvas,
      size,
      positions,
      offset,
      vertexCount,
      texture,
      mvpMatrix,
      texCoords: texCoords,
      applyLighting: applyLighting,
    );
  }

  void _drawColoredMesh(
    Canvas canvas,
    Size size,
    Float32List positions,
    int offset,
    int vertexCount,
  ) {
    matrix.MatrixUtils.multiplyMM(mvMatrix, viewMatrix, modelMatrix);
    matrix.MatrixUtils.multiplyMM(mvpMatrix, projectionMatrix, mvMatrix);

    _drawTransformedColoredMesh(
      canvas,
      size,
      positions,
      offset,
      vertexCount,
      mvpMatrix,
    );
  }

  /// Calculate lighting factor for a triangle face based on its normal
  /// Returns value between shadowMin (shadow) and 1.0 (fully lit)
  double _calculateFaceLighting(
    double x1, double y1, double z1,
    double x2, double y2, double z2,
    double x3, double y3, double z3,
  ) {
    // Calculate two edge vectors
    final e1x = x2 - x1;
    final e1y = y2 - y1;
    final e1z = z2 - z1;
    
    final e2x = x3 - x1;
    final e2y = y3 - y1;
    final e2z = z3 - z1;
    
    // Cross product to get face normal
    final nx = e1y * e2z - e1z * e2y;
    final ny = e1z * e2x - e1x * e2z;
    final nz = e1x * e2y - e1y * e2x;
    
    // Normalize the normal
    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len < 0.0001) return 0.7; // Degenerate triangle
    
    final nnx = nx / len;
    final nny = ny / len;
    final nnz = nz / len;
    
    // Light direction vector pointing FROM surface TO light source
    // lightDirX/Y/Z define where the light is:
    //   lightDirX = -0.7 means light is to the LEFT
    //   lightDirY = 0.5 means light is ABOVE (Y is up)
    //   lightDirZ = 0.5 means light is in FRONT (positive Z toward viewer)
    // DO NOT flip - lightDir already points toward light
    final lx = lightDirX;
    final ly = lightDirY;
    final lz = lightDirZ;
    final llen = math.sqrt(lx * lx + ly * ly + lz * lz);
    final nlx = lx / llen;
    final nly = ly / llen;
    final nlz = lz / llen;
    
    // Dot product: how much face normal aligns with light direction
    // +1 = face points directly toward light (brightest)
    // -1 = face points directly away from light (darkest)
    final dot = nnx * nlx + nny * nly + nnz * nlz;
    
    // Map from [-1, 1] to [shadowMin, maxBright]
    // Lower shadowMin = darker shadows = more contrast = shinier look
    const shadowMin = 0.3;  // Darker shadows for more dramatic lighting
    const maxBright = 1.1;  // Slight overexposure for shine effect
    
    // Non-linear mapping for more realistic falloff
    final normalizedDot = (dot + 1.0) / 2.0; // Map to [0, 1]
    final curved = normalizedDot * normalizedDot; // Quadratic for sharper falloff
    final lighting = shadowMin + (maxBright - shadowMin) * curved;
    
    return lighting.clamp(shadowMin, maxBright);
  }

  void _collectTriangles(
    List<_RenderTriangle> triangles,
    Float32List positions,
    int offset,
    int vertexCount,
    ui.Image? texture,
    Float32List mvp,
    Size size, {
    Float32List? texCoords,
    bool applyLighting = false,
  }) {
    for (int i = 0; i < vertexCount; i += 3) {
      final idx = (offset + i) * 3;
      if (idx + 8 >= positions.length) break;

      // Get original (untransformed) positions for normal calculation
      final ox1 = positions[idx];
      final oy1 = positions[idx + 1];
      final oz1 = positions[idx + 2];
      final ox2 = positions[idx + 3];
      final oy2 = positions[idx + 4];
      final oz2 = positions[idx + 5];
      final ox3 = positions[idx + 6];
      final oy3 = positions[idx + 7];
      final oz3 = positions[idx + 8];

      final v1 = matrix.MatrixUtils.transformPoint(mvp, ox1, oy1, oz1);
      final v2 = matrix.MatrixUtils.transformPoint(mvp, ox2, oy2, oz2);
      final v3 = matrix.MatrixUtils.transformPoint(mvp, ox3, oy3, oz3);

      // basic z clipping
      if (v1[2] < -2 ||
          v1[2] > 2 ||
          v2[2] < -2 ||
          v2[2] > 2 ||
          v3[2] < -2 ||
          v3[2] > 2) {
        continue;
      }

      if (v1[2] > 0.9 && v2[2] > 0.9 && v3[2] > 0.9) {
        continue;
      }

      final zDepth = (v1[2] + v2[2] + v3[2]) / 3.0;

      final p1 = _toScreen(v1, size);
      final p2 = _toScreen(v2, size);
      final p3 = _toScreen(v3, size);
      
      // Calculate per-face lighting if enabled
      double lightingFactor = 1.0;
      if (applyLighting) {
        // Transform positions by model matrix only (not view/projection) for correct world-space normals
        // Actually, we need to use the original positions relative to the model
        // The model matrix rotation affects the normals
        lightingFactor = _calculateFaceLighting(ox1, oy1, oz1, ox2, oy2, oz2, ox3, oy3, oz3);
      }

      final List<Offset>? uvs;
      if (texture != null) {
        if (texCoords != null && texCoords.length > (offset + i) * 2 + 5) {
          final uvIdx = (offset + i) * 2;
          final tw = texture.width.toDouble();
          final th = texture.height.toDouble();

          uvs = [
            Offset(texCoords[uvIdx] * tw, texCoords[uvIdx + 1] * th),
            Offset(texCoords[uvIdx + 2] * tw, texCoords[uvIdx + 3] * th),
            Offset(texCoords[uvIdx + 4] * tw, texCoords[uvIdx + 5] * th),
          ];
        } else {
          uvs = [
            const Offset(0, 0),
            Offset(texture.width.toDouble(), 0),
            Offset(0, texture.height.toDouble()),
          ];
        }
      } else {
        uvs = null;
      }

      triangles.add(_RenderTriangle(zDepth, [p1, p2, p3], uvs, texture, lightingFactor));
    }
  }

  void _drawTransformedMesh(
    Canvas canvas,
    Size size,
    Float32List positions,
    int offset,
    int vertexCount,
    ui.Image texture,
    Float32List mvp, {
    Float32List? texCoords,
    bool applyLighting = false,
  }) {
    // 1. Transform all vertices and collect valid triangles
    final List<_RenderTriangle> triangles = [];
    _collectTriangles(
      triangles,
      positions,
      offset,
      vertexCount,
      texture,
      mvp,
      size,
      texCoords: texCoords,
      applyLighting: applyLighting,
    );

    if (triangles.isEmpty) return;

    triangles.sort((a, b) => b.z.compareTo(a.z));
    _drawSortedTriangles(canvas, triangles);
  }

  void _drawSortedTriangles(Canvas canvas, List<_RenderTriangle> triangles) {
    if (triangles.isEmpty) return;

    // Simple batching: group by texture
    int startIndex = 0;
    while (startIndex < triangles.length) {
      final currentTexture = triangles[startIndex].texture;
      int endIndex = startIndex + 1;

      while (endIndex < triangles.length &&
          triangles[endIndex].texture == currentTexture) {
        endIndex++;
      }

      _drawTriangleBatch(
        canvas,
        triangles,
        startIndex,
        endIndex,
        currentTexture,
      );
      startIndex = endIndex;
    }
  }

  void _drawTriangleBatch(
    Canvas canvas,
    List<_RenderTriangle> triangles,
    int start,
    int end,
    ui.Image? texture,
  ) {
    final List<Offset> vertices = [];
    final List<Offset> textureCoordinates = [];
    final List<Color> vertexColors = [];
    final List<int> indices = [];

    int vertexIndex = 0;
    for (int i = start; i < end; i++) {
      final tri = triangles[i];
      vertices.addAll(tri.points);
      if (tri.texCoords != null) {
        textureCoordinates.addAll(tri.texCoords!);
      }
      
      // Create vertex colors based on lighting factor
      // Lighting factor: 0.35 (shadow) to 1.0 (fully lit)
      final brightness = (tri.lightingFactor * 255).round().clamp(0, 255);
      final lightColor = Color.fromARGB(255, brightness, brightness, brightness);
      // All 3 vertices of this triangle get the same lighting color
      vertexColors.add(lightColor);
      vertexColors.add(lightColor);
      vertexColors.add(lightColor);
      
      indices.addAll([vertexIndex, vertexIndex + 1, vertexIndex + 2]);
      vertexIndex += 3;
    }

    final paint =
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high;

    if (texture != null) {
      paint.shader = ImageShader(
        texture,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      );
    } else {
      paint.color = Colors.grey;
    }

    // Use BlendMode.modulate to multiply texture color with vertex color (lighting)
    canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        vertices,
        textureCoordinates:
            textureCoordinates.isNotEmpty ? textureCoordinates : null,
        colors: vertexColors,
        indices: indices,
      ),
      BlendMode.modulate, // Multiplies texture with vertex colors for lighting
      paint,
    );
  }

  void _drawTransformedColoredMesh(
    Canvas canvas,
    Size size,
    Float32List positions,
    int offset,
    int vertexCount,
    Float32List mvp,
  ) {
    final List<_RenderTriangle> triangles = [];

    for (int i = 0; i < vertexCount; i += 3) {
      final idx = (offset + i) * 3;
      if (idx + 8 >= positions.length) break;

      final v1 = matrix.MatrixUtils.transformPoint(
        mvp,
        positions[idx],
        positions[idx + 1],
        positions[idx + 2],
      );
      final v2 = matrix.MatrixUtils.transformPoint(
        mvp,
        positions[idx + 3],
        positions[idx + 4],
        positions[idx + 5],
      );
      final v3 = matrix.MatrixUtils.transformPoint(
        mvp,
        positions[idx + 6],
        positions[idx + 7],
        positions[idx + 8],
      );

      if (v1[2] < -2 ||
          v1[2] > 2 ||
          v2[2] < -2 ||
          v2[2] > 2 ||
          v3[2] < -2 ||
          v3[2] > 2) {
        continue;
      }

      if (v1[2] > 0.9 && v2[2] > 0.9 && v3[2] > 0.9) {
        continue;
      }

      final zDepth = (v1[2] + v2[2] + v3[2]) / 3.0;

      final p1 = _toScreen(v1, size);
      final p2 = _toScreen(v2, size);
      final p3 = _toScreen(v3, size);

      triangles.add(_RenderTriangle(zDepth, [p1, p2, p3], null, null));
    }

    if (triangles.isEmpty) return;

    triangles.sort((a, b) => b.z.compareTo(a.z));

    final List<Offset> vertices = [];
    final List<int> indices = [];

    int vertexIndex = 0;
    for (final tri in triangles) {
      vertices.addAll(tri.points);
      indices.addAll([vertexIndex, vertexIndex + 1, vertexIndex + 2]);
      vertexIndex += 3;
    }

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.plus;

    // Use color shader if available
    if (colorShader != null) {
      // Set color uniform (RGBA - 4 floats)
      colorShader!.setFloat(0, 0x33 / 255.0); // R
      colorShader!.setFloat(1, 0x33 / 255.0); // G
      colorShader!.setFloat(2, 0x33 / 255.0); // B
      colorShader!.setFloat(3, 0xE6 / 255.0); // A
      
      paint.shader = colorShader;
    } else {
      // Fallback to direct color
      paint.color = const Color(0xE6333333);
    }

    canvas.drawVertices(
      ui.Vertices(ui.VertexMode.triangles, vertices, indices: indices),
      BlendMode.plus,
      paint,
    );
  }

  Offset _toScreen(List<double> ndc, Size size) {
    final x = (ndc[0] + 1) * size.width / 2;
    final y = (1 - ndc[1]) * size.height / 2;
    return Offset(x, y);
  }
}

class _RenderTriangle {
  final double z;
  final List<Offset> points;
  final List<Offset>? texCoords;
  final ui.Image? texture;
  final double lightingFactor; // 0.0 = dark (shadow), 1.0 = bright (lit)

  _RenderTriangle(this.z, this.points, this.texCoords, this.texture, [this.lightingFactor = 1.0]);
}

class _PieceSortEntry {
  final int index;
  final double ndcZ;
  final Float32List matrix;

  _PieceSortEntry(this.index, this.ndcZ, this.matrix);
}

// Helper for sorting
extension GameRendererHelpers on GameRenderer {
  double _getNDC_Z(Float32List modelM, double x, double y, double z) {
    // MVP = Projection * View * Model
    final vp = Float32List(16);
    matrix.MatrixUtils.multiplyMM(vp, projectionMatrix, viewMatrix);

    final mvp = Float32List(16);
    matrix.MatrixUtils.multiplyMM(mvp, vp, modelM);

    final w = mvp[3] * x + mvp[7] * y + mvp[11] * z + mvp[15];
    final z_clip = mvp[2] * x + mvp[6] * y + mvp[10] * z + mvp[14];

    if (w == 0) return 0;
    return z_clip / w;
  }
}
