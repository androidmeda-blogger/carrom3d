import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'matrix_utils.dart' as matrix;
import 'mesh_data.dart';
import 'texture_loader.dart';

/// GameRenderer - Direct port of GameRenderer.java
/// Handles all 3D rendering using Canvas API and fragment shaders
class GameRenderer {
  // Matrix storage
  late Float32List modelMatrix;
  late Float32List viewMatrix;
  late Float32List tmpViewMatrix;
  late Float32List projectionMatrix;
  late Float32List mvpMatrix;
  late Float32List mvMatrix;

  // Mesh data buffers (matching GameRenderer.java fields)
  late Float32List cubePositions;
  late Float32List cubeTextureCoordinates;
  late Float32List cylinderPositions;
  late Float32List cylinderTextureCoordinates;
  late Float32List diskPositions;
  late Float32List arrowHeadPositions;
  late Float32List arrowTailPositions;
  late Float32List arrowTailTextureCoordinates;
  late Float32List arcPositions;
  late Float32List objectColors;
  late Float32List floorPositions;
  late Float32List floorTextureCoordinates;

  // Texture handles (will be loaded as ui.Image)
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

  // Piece positions and states
  List<double> xposPieces = List.filled(32, 0.0);
  List<double> yposPieces = List.filled(32, 0.0);
  List<int> presents = List.filled(32, 0);
  List<bool> zRaised = List.filled(32, false);
  bool aboutToCancel = false;

  double screenWidth = 0;
  double screenHeight = 0;

  // View parameters
  double yangle = 0;
  double xangle = 0;
  double eyedisp = 0;
  double scale = 1;
  bool rotateXFirst = true;

  // Camera position (matching GameRenderer.java)
  double eyeX = 0.0;
  double eyeY = 3.5;
  double eyeZ = 0.0;

  // Look at point
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

  // Arrow display
  List<double> arrowX = List.filled(16, 0.0);
  List<double> arrowY = List.filled(16, 0.0);
  List<double> arrowLen = List.filled(16, 0.0);
  List<double> arrowAngle = List.filled(16, 0.0);
  bool arrowReady = false;
  int arrowCount = 0;
  bool showArrows = false;

  double arrowHeadWidth = 0.06;
  double arrowWidth = 0.02;

  // Arc display
  bool showArcs = false;
  double arcAngle = 0;

  // Cross display
  double crossX1 = 0.3;
  double crossY1 = 0.6;
  double crossX2 = 0.3;
  double crossY2 = 0.6;
  double crossAngle = 0;

  GameRenderer() {
    // Initialize matrices
    modelMatrix = matrix.MatrixUtils.identity();
    viewMatrix = matrix.MatrixUtils.identity();
    tmpViewMatrix = matrix.MatrixUtils.identity();
    projectionMatrix = matrix.MatrixUtils.identity();
    mvpMatrix = matrix.MatrixUtils.identity();
    mvMatrix = matrix.MatrixUtils.identity();

    // Initialize mesh data (matching Java: MeshData.initData(this))
    MeshData.initData(this);

    // Note: initView() is NOT called here (it's never called in Java either)
    // Camera is initialized by GameController/GameEngine calling updateEye()
  }

  /// Load all textures from assets
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
    chairLegTexture = textures['frame']; // Reuse frame texture
    
    rDiskBorderTexture = textures['rdisk_border'];
    hDiskBorderTexture = textures['hdisk_border'];
    diskBorderTexture = textures['disk_border'];
    whiteBorderTexture = textures['white_border'];
    blackBorderTexture = textures['black_border'];
    redBorderTexture = textures['red_border'];
  }

  /// Initialize the view (camera) settings
  /// Legacy method - never called (matching Java where it's commented out)
  /// Camera is initialized via GameController/GameEngine calling updateEye()
  void initView() {
    yangle = 0;
    xangle = -30;
    eyedisp = 0;
    scale = 1;
    rotateXFirst = true;
    upY = 0;
    upZ = -1;
  }

  /// Update eye/camera position and orientation
  void updateEye(double ydiff, double xdiff, double scalediff, double eyediff) {
    yangle += ydiff;
    xangle += xdiff;
    scale += scalediff;
    eyedisp += eyediff;

    // Debug updateEye (disabled - uncomment if needed)
    // if (_updateEyeCallCount < 3) {
    //   print("updateEye #$_updateEyeCallCount: up=($upX,$upY,$upZ), angles=($xangle,$yangle)");
    //   _updateEyeCallCount++;
    // }
    
    matrix.MatrixUtils.setLookAt(tmpViewMatrix, eyeX, eyeY, eyeZ, lookX, lookY, lookZ, upX, upY, upZ);
    matrix.MatrixUtils.translate(tmpViewMatrix, eyedisp, 0, 0);

    if (rotateXFirst) {
      matrix.MatrixUtils.rotate(tmpViewMatrix, xangle, 1, 0, 0);
      matrix.MatrixUtils.rotate(tmpViewMatrix, yangle, 0, 1, 0);
    } else {
      matrix.MatrixUtils.rotate(tmpViewMatrix, yangle, 0, 1, 0);
      matrix.MatrixUtils.rotate(tmpViewMatrix, xangle, 1, 0, 0);
    }

    matrix.MatrixUtils.scale(tmpViewMatrix, scale, scale, scale);

    // Swap matrices
    final temp = viewMatrix;
    viewMatrix = tmpViewMatrix;
    tmpViewMatrix = temp;
  }

  /// Called when surface size changes
  void onSurfaceChanged(double width, double height) {
    screenWidth = width;
    screenHeight = height;

    double scaleFactor = 0;
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
    final near = 1.0;
    final far = 18.0;

    matrix.MatrixUtils.frustum(projectionMatrix, left, right, bottom, top, near, far);
  }

  /// Main draw method - renders a frame
  void onDrawFrame(Canvas canvas, Size size) {
    // Clear background (black for better visibility)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    // Note: Java's onDrawFrame does NOT call updateEye here
    // updateEye is only called when camera changes (input, game logic)
    
    // Draw background (floor, walls, table legs)
    try {
      drawBackground(canvas, size);
    } catch (e) {
      print("ERROR in drawBackground: $e");
    }

    // Draw board cube and face
    try {
      matrix.MatrixUtils.setIdentity(modelMatrix);
      drawCube(canvas, size);
      drawBoardFace(canvas, size);
    } catch (e) {
      print("ERROR in drawCube/drawBoardFace: $e");
    }

    // Draw pieces
    for (int i = 0; i < 20; i++) {
      if (presents[i] == 0) {
        continue;
      }
      
      matrix.MatrixUtils.setIdentity(modelMatrix);

      double height = 0;
      if (presents[i] == MeshData.HOLE_ANI_LIMIT - 1) {
        height = -MeshData.HEIGHT *
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

      drawCylinder(canvas, size, i, false);
    }

    // Draw cancel cross if needed
    if (aboutToCancel) {
      drawCross(canvas, size);
    }

    // Draw shooting guide
    if (readyToShoot && !aboutToCancel && (shootingX != 0 || shootingY != 0)) {
      double shootingDist = math.sqrt(shootingX * shootingX + shootingY * shootingY);
      double adjustedShootingX = shootingX;
      double adjustedShootingY = shootingY;
      
      if (shootingDist > MeshData.DISK_SHOOTING_MAX_DIST) {
        adjustedShootingX = shootingX / shootingDist * MeshData.DISK_SHOOTING_MAX_DIST;
        adjustedShootingY = shootingY / shootingDist * MeshData.DISK_SHOOTING_MAX_DIST;
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

        drawCylinder(canvas, size, 0, true);
      }
    }

    // Draw arrows
    if (arrowReady && showArrows) {
      drawArrows(canvas, size);
    }

    // Draw arcs
    if (showArcs && !shootingMode) {
      drawArcs(canvas, size);
    }
  }

  /// Draw the board frame
  void drawCube(Canvas canvas, Size size) {
    _drawMesh(
      canvas,
      size,
      cubePositions,
      0,
      6 * 13,
      frameTexture,
    );
  }

  /// Draw the board playing surface
  void drawBoardFace(Canvas canvas, Size size) {
    _drawMesh(
      canvas,
      size,
      cubePositions,
      6 * 13,
      6,
      surfaceTexture,
    );
  }

  /// Draw a cylinder (game piece)
  void drawCylinder(Canvas canvas, Size size, int pieceIndex, bool transparent) {
    final positions = pieceIndex == 0 ? diskPositions : cylinderPositions;
    
    ui.Image? borderTexture;
    ui.Image? topTexture;

    // Select textures based on piece type
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

    // Draw border
    _drawMesh(canvas, size, positions, 0, 6 * MeshData.CIRC_SEGMENTS, borderTexture);

    // Draw top
    _drawMesh(canvas, size, positions, 6 * MeshData.CIRC_SEGMENTS,
        3 * MeshData.CIRC_SEGMENTS, topTexture);
  }

  /// Draw arrows
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
      
      matrix.MatrixUtils.rotate(modelMatrix, arrowAngle[arrowCount - 1], 0, 1, 0);
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
    _drawColoredMesh(canvas, size, arrowHeadPositions, 0,
        arrowHeadPositions.length ~/ 3);
  }

  void drawArrowTail(Canvas canvas, Size size) {
    _drawColoredMesh(canvas, size, arrowTailPositions, 0, 6 * 5);
  }

  /// Draw cross (cancel indicator)
  void drawCross(Canvas canvas, Size size) {
    const factor = 1.1;
    const crossLen = 0.15;

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
    _drawMesh(canvas, size, arrowTailPositions, 0, 6 * 5, rDiskTexture);
  }

  /// Draw arcs (shooting angle guides)
  void drawArcs(Canvas canvas, Size size) {
    drawArcHead(canvas, size, arcAngle, 1);
    drawArcHead(canvas, size, arcAngle + MeshData.ARG_ANGLE_LIMIT - 1.5, -1);
    drawArcHead(canvas, size, arcAngle + 180, 1);
    drawArcHead(canvas, size, arcAngle + MeshData.ARG_ANGLE_LIMIT - 1.5 + 180, -1);

    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, arcAngle, 0, 1, 0);
    drawArcModel(canvas, size);

    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, arcAngle + 180, 0, 1, 0);
    drawArcModel(canvas, size);
  }

  void drawArcHead(Canvas canvas, Size size, double baseDegree, int side) {
    matrix.MatrixUtils.setIdentity(modelMatrix);
    const xscale = 0.04;
    final yscale = MeshData.ARC_HEIGHT;
    const zscale = 0.04;
    final radius = (6.3 + 7.0) * MeshData.RADIUS / 2;
    
    matrix.MatrixUtils.rotate(modelMatrix, baseDegree - side * 90, 0, 1, 0);
    matrix.MatrixUtils.scale(modelMatrix, xscale, yscale, zscale);
    matrix.MatrixUtils.translate(
      modelMatrix,
      0,
      MeshData.BOARD_TOP / yscale,
      -side * radius / zscale,
    );

    drawArrowHead(canvas, size);
  }

  void drawArcModel(Canvas canvas, Size size) {
    final limit = MeshData.ARG_ANGLE_LIMIT * MeshData.CIRC_SEGMENTS ~/ 360;
    _drawColoredMesh(canvas, size, arcPositions, 0, 6 * limit * 3);
  }

  /// Draw background (floor, walls, table legs)
  void drawBackground(Canvas canvas, Size size) {
    // Floor
    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.translate(modelMatrix, -MeshData.FLOOR_WIDTH / 2, -1,
        -MeshData.FLOOR_WIDTH / 2);
    drawFloor(canvas, size);

    // Walls (4 walls)
    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, 90, 1, 0, 0);
    matrix.MatrixUtils.translate(modelMatrix, -MeshData.FLOOR_WIDTH / 2,
        -MeshData.FLOOR_WIDTH / 2, -MeshData.FLOOR_WIDTH + 2);
    drawWall(canvas, size);

    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, 90, -1, 0, 0);
    matrix.MatrixUtils.translate(
        modelMatrix, -MeshData.FLOOR_WIDTH / 2, -MeshData.FLOOR_WIDTH / 2, -2);
    drawWall(canvas, size);

    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, 90, 0, 0, 1);
    matrix.MatrixUtils.translate(
        modelMatrix, -2, -MeshData.FLOOR_WIDTH / 2, -MeshData.FLOOR_WIDTH / 2);
    drawWall(canvas, size);

    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, 90, 0, 0, -1);
    matrix.MatrixUtils.translate(modelMatrix, -MeshData.FLOOR_WIDTH + 2,
        -MeshData.FLOOR_WIDTH / 2, -MeshData.FLOOR_WIDTH / 2);
    drawWall(canvas, size);

    // Table legs (4 legs)
    _drawTableLeg(canvas, size, 0, -4, -8);
    _drawTableLeg(canvas, size, 0, -4, 8);
    _drawTableLeg(canvas, size, 0, 4, -8);
    _drawTableLeg(canvas, size, 0, 4, 8);
  }

  void _drawTableLeg(Canvas canvas, Size size, double x, double y, double z) {
    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, -90, 0, 0, 1);
    matrix.MatrixUtils.scale(modelMatrix, 1, 0.1, 0.05);
    matrix.MatrixUtils.translate(modelMatrix, x, y, z);
    drawTableLeg(canvas, size);
  }

  void drawFloor(Canvas canvas, Size size) {
    _drawMesh(canvas, size, floorPositions, 0,
        6 * MeshData.FLOOR_SECTIONS * MeshData.FLOOR_SECTIONS, floorTexture);
  }

  void drawWall(Canvas canvas, Size size) {
    _drawMesh(canvas, size, floorPositions, 0,
        6 * MeshData.FLOOR_SECTIONS * MeshData.FLOOR_SECTIONS, wallTexture);
  }

  void drawTableLeg(Canvas canvas, Size size) {
    _drawMesh(canvas, size, arrowTailPositions, 0, 6 * 6, chairLegTexture);
  }

  /// Helper method to draw a mesh with texture
  void _drawMesh(Canvas canvas, Size size, Float32List positions, int offset,
      int vertexCount, ui.Image? texture) {
    if (texture == null) {
      return;
    }

    // Calculate MVP matrix
    try {
      matrix.MatrixUtils.multiplyMM(mvMatrix, viewMatrix, modelMatrix);
      matrix.MatrixUtils.multiplyMM(mvpMatrix, projectionMatrix, mvMatrix);
    } catch (e) {
      print("ERROR in matrix multiply: $e");
      return;
    }

    // Transform vertices and draw
    _drawTransformedMesh(canvas, size, positions, offset, vertexCount, texture, mvpMatrix);
  }

  /// Helper method to draw colored mesh (for transparent objects)
  void _drawColoredMesh(Canvas canvas, Size size, Float32List positions,
      int offset, int vertexCount) {
    // Calculate MVP matrix
    matrix.MatrixUtils.multiplyMM(mvMatrix, viewMatrix, modelMatrix);
    matrix.MatrixUtils.multiplyMM(mvpMatrix, projectionMatrix, mvMatrix);

    // Transform vertices and draw with color
    _drawTransformedColoredMesh(canvas, size, positions, offset, vertexCount, mvpMatrix);
  }

  /// Transform vertices and draw to canvas
  void _drawTransformedMesh(Canvas canvas, Size size, Float32List positions,
      int offset, int vertexCount, ui.Image texture, Float32List mvp) {
    final paint = Paint();
    
    // Draw triangles
    for (int i = 0; i < vertexCount; i += 3) {
      final idx = (offset + i) * 3;
      if (idx + 8 >= positions.length) break;

      // Transform 3 vertices
      final v1 = matrix.MatrixUtils.transformPoint(
          mvp, positions[idx], positions[idx + 1], positions[idx + 2]);
      final v2 = matrix.MatrixUtils.transformPoint(
          mvp, positions[idx + 3], positions[idx + 4], positions[idx + 5]);
      final v3 = matrix.MatrixUtils.transformPoint(
          mvp, positions[idx + 6], positions[idx + 7], positions[idx + 8]);

      // Convert to screen coordinates
      final p1 = _toScreen(v1, size);
      final p2 = _toScreen(v2, size);
      final p3 = _toScreen(v3, size);

      // Simple z-clipping - be more lenient
      if (v1[2] < -2 || v1[2] > 2 || v2[2] < -2 || v2[2] > 2 || v3[2] < -2 || v3[2] > 2) {
        continue;
      }

      // Skip triangles that are behind the camera
      if (v1[2] > 0.9 && v2[2] > 0.9 && v3[2] > 0.9) {
        continue;
      }

      // Draw triangle with texture
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();

      // Apply texture shader
      paint.shader = ImageShader(
        texture,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
      );
      canvas.drawPath(path, paint);
    }
  }

  /// Draw colored mesh for transparent objects
  void _drawTransformedColoredMesh(Canvas canvas, Size size, Float32List positions,
      int offset, int vertexCount, Float32List mvp) {
    final paint = Paint()
      ..color = const Color(0x4D4D9FFF) // Semi-transparent light blue
      ..style = PaintingStyle.fill;

    for (int i = 0; i < vertexCount; i += 3) {
      final idx = (offset + i) * 3;
      if (idx + 8 >= positions.length) break;

      final v1 = matrix.MatrixUtils.transformPoint(
          mvp, positions[idx], positions[idx + 1], positions[idx + 2]);
      final v2 = matrix.MatrixUtils.transformPoint(
          mvp, positions[idx + 3], positions[idx + 4], positions[idx + 5]);
      final v3 = matrix.MatrixUtils.transformPoint(
          mvp, positions[idx + 6], positions[idx + 7], positions[idx + 8]);

      final p1 = _toScreen(v1, size);
      final p2 = _toScreen(v2, size);
      final p3 = _toScreen(v3, size);

      // More lenient z-clipping
      if (v1[2] < -2 || v1[2] > 2 || v2[2] < -2 || v2[2] > 2 || v3[2] < -2 || v3[2] > 2) {
        continue;
      }

      // Skip triangles behind camera
      if (v1[2] > 0.9 && v2[2] > 0.9 && v3[2] > 0.9) {
        continue;
      }

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  /// Convert normalized device coordinates to screen coordinates
  Offset _toScreen(List<double> ndc, Size size) {
    final x = (ndc[0] + 1) * size.width / 2;
    final y = (1 - ndc[1]) * size.height / 2;
    return Offset(x, y);
  }
}

