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

    // Pieces
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

      // opaque cylinder
      drawCylinder(canvas, size, i, false);
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
    );
  }

  void drawBoardFace(Canvas canvas, Size size) {
    _drawMesh(
      canvas,
      size,
      cubePositions,
      6 * 13,
      6,
      surfaceTexture,
      texCoords: cubeTextureCoordinates,
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

    // Border
    _drawMesh(
      canvas,
      size,
      positions,
      0,
      6 * MeshData.CIRC_SEGMENTS,
      borderTexture,
      texCoords: cylinderTextureCoordinates,
    );

    // Top
    _drawMesh(
      canvas,
      size,
      positions,
      6 * MeshData.CIRC_SEGMENTS,
      3 * MeshData.CIRC_SEGMENTS,
      topTexture,
      texCoords: cylinderTextureCoordinates,
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

  void drawBackground(Canvas canvas, Size size) {
    // Floor
    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.translate(
      modelMatrix,
      -MeshData.FLOOR_WIDTH / 2,
      -1,
      -MeshData.FLOOR_WIDTH / 2,
    );
    drawFloor(canvas, size);

    // Walls (same transforms as Java)
    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, 90, 1, 0, 0);
    matrix.MatrixUtils.translate(
      modelMatrix,
      -MeshData.FLOOR_WIDTH / 2,
      -MeshData.FLOOR_WIDTH / 2,
      -MeshData.FLOOR_WIDTH + 2,
    );
    drawWall(canvas, size);

    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, 90, -1, 0, 0);
    matrix.MatrixUtils.translate(
      modelMatrix,
      -MeshData.FLOOR_WIDTH / 2,
      -MeshData.FLOOR_WIDTH / 2,
      -2,
    );
    drawWall(canvas, size);

    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, 90, 0, 0, 1);
    matrix.MatrixUtils.translate(
      modelMatrix,
      -2,
      -MeshData.FLOOR_WIDTH / 2,
      -MeshData.FLOOR_WIDTH / 2,
    );
    drawWall(canvas, size);

    matrix.MatrixUtils.setIdentity(modelMatrix);
    matrix.MatrixUtils.rotate(modelMatrix, 90, 0, 0, -1);
    matrix.MatrixUtils.translate(
      modelMatrix,
      -MeshData.FLOOR_WIDTH + 2,
      -MeshData.FLOOR_WIDTH / 2,
      -MeshData.FLOOR_WIDTH / 2,
    );
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

  void _drawTransformedMesh(
    Canvas canvas,
    Size size,
    Float32List positions,
    int offset,
    int vertexCount,
    ui.Image texture,
    Float32List mvp, {
    Float32List? texCoords,
  }) {
    final List<Offset> vertices = [];
    final List<Offset> textureCoordinates = [];
    final List<int> indices = [];

    int vertexIndex = 0;

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

      // basic z clipping similar spirit to depth test
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

      final p1 = _toScreen(v1, size);
      final p2 = _toScreen(v2, size);
      final p3 = _toScreen(v3, size);

      vertices.addAll([p1, p2, p3]);

      if (texCoords != null && texCoords.length > (offset + i) * 2 + 5) {
        final uvIdx = (offset + i) * 2;
        final tw = texture.width.toDouble();
        final th = texture.height.toDouble();

        textureCoordinates.addAll([
          Offset(texCoords[uvIdx] * tw, texCoords[uvIdx + 1] * th),
          Offset(texCoords[uvIdx + 2] * tw, texCoords[uvIdx + 3] * th),
          Offset(texCoords[uvIdx + 4] * tw, texCoords[uvIdx + 5] * th),
        ]);
      } else {
        textureCoordinates.addAll([
          const Offset(0, 0),
          Offset(texture.width.toDouble(), 0),
          Offset(0, texture.height.toDouble()),
        ]);
      }

      indices.addAll([vertexIndex, vertexIndex + 1, vertexIndex + 2]);
      vertexIndex += 3;
    }

    if (vertices.isEmpty) return;

    final paint =
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high
          ..shader = ImageShader(
            texture,
            TileMode.clamp,
            TileMode.clamp,
            Matrix4.identity().storage,
          );

    canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        vertices,
        textureCoordinates: textureCoordinates,
        indices: indices,
      ),
      BlendMode.srcOver,
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
    final paint =
        Paint()
          // Match Java objectColors: (0.2,0.2,0.2,0.9) ≈ #E6333333
          ..color = const Color(0xE6333333)
          ..style = PaintingStyle.fill
          // Approximate glBlendFunc(GL_ONE, GL_ONE)
          ..blendMode = BlendMode.plus;

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

      final p1 = _toScreen(v1, size);
      final p2 = _toScreen(v2, size);
      final p3 = _toScreen(v3, size);

      final path =
          Path()
            ..moveTo(p1.dx, p1.dy)
            ..lineTo(p2.dx, p2.dy)
            ..lineTo(p3.dx, p3.dy)
            ..close();

      canvas.drawPath(path, paint);
    }
  }

  Offset _toScreen(List<double> ndc, Size size) {
    final x = (ndc[0] + 1) * size.width / 2;
    final y = (1 - ndc[1]) * size.height / 2;
    return Offset(x, y);
  }
}
