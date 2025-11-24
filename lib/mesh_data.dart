import 'dart:math' as math;
import 'dart:typed_data';

import 'game_renderer.dart';

/// MeshData - 1:1 port of MeshData.java
/// Contains all 3D geometry data for the game
class MeshData {
  // Constants from MeshData.java
  static const int CIRC_SEGMENTS = 64;
  static const double RADIUS = 0.045;
  static const double HEIGHT = 0.03;
  static const double BOARD_TOP = 0.11;
  static const double BOARD_BORDER = 0.9;
  static const double DISK_START_DIST = 0.619;
  static const double DISK_START_DOWN_DIFF = 0.021;
  static const double DISK_START_UP_DIFF = 0.020;

  static const double DISK_YBORDER = 0.543;
  static const double DISK_SHOOTING_DIST = 0.375;
  static const double DISK_SHOOTING_MAX_DIST = 0.2;
  static const double DISK_SHOOTING_THRESHOLD = 0.045;
  static const double DISK_RADIUS_FACTOR = 1.4;
  static const double DISK_HEIGHT_FACTOR = 0.7;
  static const int ARG_ANGLE_LIMIT = 130;
  static const double ARC_HEIGHT = HEIGHT / 3;
  static const double DEG_TO_RAD = math.pi / 180.0;
  static const double RAD_TO_DEG = 180.0 / math.pi;
  static const double HOLE_RADIUS = RADIUS * DISK_RADIUS_FACTOR;
  static const int HOLE_ANI_LIMIT = 4;
  static const double PIECES_GAP = RADIUS / 5.0;

  static const double DISK_DOWN_TOUCH_LIMIT =
      DISK_START_DIST +
      DISK_START_DOWN_DIFF +
      RADIUS * DISK_RADIUS_FACTOR * 1.5;
  static const double DISK_UP_TOUCH_LIMIT =
      DISK_START_DIST - DISK_START_UP_DIFF - RADIUS * DISK_RADIUS_FACTOR * 1.5;

  static const double RED_CIRCLE_RADIUS = RADIUS * 0.8;

  static const double FLOOR_WIDTH = 12.0;
  static const int FLOOR_SECTIONS = 6;
  static const double FLOOR_COORD = FLOOR_WIDTH / FLOOR_SECTIONS;

  static void initData(GameRenderer renderer) {
    // -----------------------------
    // Board edge geometry (positions)
    // -----------------------------
    final boardEdgePositionData = <double>[
      // Front face
      -1.0, 0.15, 1.0, //
      -1.0, -0.15, 1.0, //
      1.0, 0.15, 1.0, //
      -1.0, -0.15, 1.0, //
      1.0, -0.15, 1.0, //
      1.0, 0.15, 1.0, //
      // Right face
      1.0, 0.15, 1.0, //
      1.0, -0.15, 1.0, //
      1.0, 0.15, -1.0, //
      1.0, -0.15, 1.0, //
      1.0, -0.15, -1.0, //
      1.0, 0.15, -1.0, //
      // Back face
      1.0, 0.15, -1.0, //
      1.0, -0.15, -1.0, //
      -1.0, 0.15, -1.0, //
      1.0, -0.15, -1.0, //
      -1.0, -0.15, -1.0, //
      -1.0, 0.15, -1.0, //
      // Left face
      -1.0, 0.15, -1.0, //
      -1.0, -0.15, -1.0, //
      -1.0, 0.15, 1.0, //
      -1.0, -0.15, -1.0, //
      -1.0, -0.15, 1.0, //
      -1.0, 0.15, 1.0, //
      // Bottom face
      1.0, -0.15, -1.0, //
      1.0, -0.15, 1.0, //
      -1.0, -0.15, -1.0, //
      1.0, -0.15, 1.0, //
      -1.0, -0.15, 1.0, //
      -1.0, -0.15, -1.0, //
      // Top face - front
      -0.9, 0.15, 0.9, //
      -1.0, 0.15, 1.0, //
      0.9, 0.15, 0.9, //
      -1.0, 0.15, 1.0, //
      1.0, 0.15, 1.0, //
      0.9, 0.15, 0.9, //
      // Top face - back
      -1.0, 0.15, -1.0, //
      -0.9, 0.15, -0.9, //
      1.0, 0.15, -1.0, //
      -0.9, 0.15, -0.9, //
      0.9, 0.15, -0.9, //
      1.0, 0.15, -1.0, //
      // Top face - right
      0.9, 0.15, -0.9, //
      0.9, 0.15, 0.9, //
      1.0, 0.15, -1.0, //
      0.9, 0.15, 0.9, //
      1.0, 0.15, 1.0, //
      1.0, 0.15, -1.0, //
      // Top face - left
      -1.0, 0.15, -1.0, //
      -1.0, 0.15, 1.0, //
      -0.9, 0.15, -0.9, //
      -1.0, 0.15, 1.0, //
      -0.9, 0.15, 0.9, //
      -0.9, 0.15, -0.9, //
      // Inner Front face
      -1.0, 0.15, -0.9, //
      -1.0, 0.11, -0.9, //
      1.0, 0.15, -0.9, //
      -1.0, 0.11, -0.9, //
      1.0, 0.11, -0.9, //
      1.0, 0.15, -0.9, //
      // Inner Right face
      -0.9, 0.15, 1.0, //
      -0.9, 0.11, 1.0, //
      -0.9, 0.15, -1.0, //
      -0.9, 0.11, 1.0, //
      -0.9, 0.11, -1.0, //
      -0.9, 0.15, -1.0, //
      // Inner Back face
      1.0, 0.15, 0.9, //
      1.0, 0.11, 0.9, //
      -1.0, 0.15, 0.9, //
      1.0, 0.11, 0.9, //
      -1.0, 0.11, 0.9, //
      -1.0, 0.15, 0.9, //
      // Inner Left face
      0.9, 0.15, -1.0, //
      0.9, 0.11, -1.0, //
      0.9, 0.15, 1.0, //
      0.9, 0.11, -1.0, //
      0.9, 0.11, 1.0, //
      0.9, 0.15, 1.0, //
      // Inner Bottom face
      -0.9, 0.11, -0.9, //
      -0.9, 0.11, 0.9, //
      0.9, 0.11, 0.9, //
      -0.9, 0.11, -0.9, //
      0.9, 0.11, 0.9, //
      0.9, 0.11, -0.9, //
    ];

    // -----------------------------
    // Texture coordinates for cube/board
    // -----------------------------
    final cubeTextureCoordinateData = <double>[
      // Front face
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      1.0, 0.0, //
      // Right face
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      1.0, 0.0, //
      // Back face
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      1.0, 0.0, //
      // Left face
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      1.0, 0.0, //
      // Bottom face
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      1.0, 0.0, //
      // Top face 1
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      1.0, 0.0, //
      // Top face 2
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      1.0, 0.0, //
      // Top face 3
      1.0, 0.0, //
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      // Top face 4
      1.0, 0.0, //
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      // Internal face 1
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      1.0, 0.0, //
      // Internal face 2
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      1.0, 0.0, //
      // Internal face 3
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      1.0, 0.0, //
      // Internal face 4
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
      1.0, 0.0, //
      // Internal face top
      1.0, 0.0, //
      0.0, 0.0, //
      0.0, 1.0, //
      1.0, 0.0, //
      0.0, 1.0, //
      1.0, 1.0, //
    ];

    // Initialize cube buffers
    renderer.cubePositions = Float32List.fromList(boardEdgePositionData);
    renderer.cubeTextureCoordinates = Float32List.fromList(
      cubeTextureCoordinateData,
    );

    // -----------------------------
    // Cylinder (piece body) - exact layout as Java
    // -----------------------------
    final cylinderData = List<double>.filled(
      CIRC_SEGMENTS * 6 * 3 + CIRC_SEGMENTS * 3 * 3,
      0.0,
    );
    final cylinderTextureData = List<double>.filled(
      CIRC_SEGMENTS * 6 * 2 + CIRC_SEGMENTS * 3 * 2,
      0.0,
    );

    var angle = 0.0;
    const radius = RADIUS;
    const top = -HEIGHT / 2.0;
    const height = HEIGHT;

    var idx = 0; // sides positions
    var texIdx = 0; // sides texcoords
    var topIdx = CIRC_SEGMENTS * 6 * 3; // top positions
    var topTexIdx = CIRC_SEGMENTS * 6 * 2; // top texcoords

    for (int i = 0; i < CIRC_SEGMENTS; i++) {
      final x1 = radius * math.cos(angle);
      final y1 = radius * math.sin(angle);

      angle += 2.0 * math.pi / CIRC_SEGMENTS;

      final x2 = radius * math.cos(angle);
      final y2 = radius * math.sin(angle);

      // Side triangles (b, d, a)
      cylinderData[idx++] = x1;
      cylinderData[idx++] = top;
      cylinderData[idx++] = -y1;

      cylinderData[idx++] = x2;
      cylinderData[idx++] = top + height;
      cylinderData[idx++] = -y2;

      cylinderData[idx++] = x1;
      cylinderData[idx++] = top + height;
      cylinderData[idx++] = -y1;

      // (b, c, d)
      cylinderData[idx++] = x1;
      cylinderData[idx++] = top;
      cylinderData[idx++] = -y1;

      cylinderData[idx++] = x2;
      cylinderData[idx++] = top;
      cylinderData[idx++] = -y2;

      cylinderData[idx++] = x2;
      cylinderData[idx++] = top + height;
      cylinderData[idx++] = -y2;

      // Side texture coords
      cylinderTextureData[texIdx++] = 0.0;
      cylinderTextureData[texIdx++] = 1.0;

      cylinderTextureData[texIdx++] = 1.0;
      cylinderTextureData[texIdx++] = 0.0;

      cylinderTextureData[texIdx++] = 0.0;
      cylinderTextureData[texIdx++] = 0.0;

      cylinderTextureData[texIdx++] = 0.0;
      cylinderTextureData[texIdx++] = 1.0;

      cylinderTextureData[texIdx++] = 1.0;
      cylinderTextureData[texIdx++] = 1.0;

      cylinderTextureData[texIdx++] = 1.0;
      cylinderTextureData[texIdx++] = 0.0;

      // Top (center, x1, x2)
      cylinderData[topIdx++] = 0.0;
      cylinderData[topIdx++] = top + height;
      cylinderData[topIdx++] = 0.0;

      cylinderData[topIdx++] = x1;
      cylinderData[topIdx++] = top + height;
      cylinderData[topIdx++] = -y1;

      cylinderData[topIdx++] = x2;
      cylinderData[topIdx++] = top + height;
      cylinderData[topIdx++] = -y2;

      // Top texcoords
      cylinderTextureData[topTexIdx++] = 0.0;
      cylinderTextureData[topTexIdx++] = 1.0;

      cylinderTextureData[topTexIdx++] = 1.0;
      cylinderTextureData[topTexIdx++] = 0.0;

      cylinderTextureData[topTexIdx++] = 0.0;
      cylinderTextureData[topTexIdx++] = 0.0;
    }

    // Copy the unscaled cylinder (as in Java: put before scaling)
    renderer.cylinderPositions = Float32List.fromList(cylinderData);
    renderer.cylinderTextureCoordinates = Float32List.fromList(
      cylinderTextureData,
    );

    // -----------------------------
    // Disk positions - scaled cylinder (after the copy, same as Java mutating)
    // -----------------------------
    for (int i = 0; i < CIRC_SEGMENTS * 6 * 3 + CIRC_SEGMENTS * 3 * 3; i += 3) {
      cylinderData[i] *= DISK_RADIUS_FACTOR;
      cylinderData[i + 1] *= DISK_HEIGHT_FACTOR;
      cylinderData[i + 2] *= DISK_RADIUS_FACTOR;
    }

    renderer.diskPositions = Float32List.fromList(cylinderData);

    // -----------------------------
    // Arrow tail (geometry + texcoords)
    // -----------------------------
    final arrowTailData = <double>[
      // top face
      0, 1, 1, //
      1, 1, 1, //
      1, 1, -1, //
      1, 1, -1, //
      0, 1, -1, //
      0, 1, 1, //
      // behind face
      1, 0, 1, //
      1, 0, -1, //
      1, 1, -1, //
      1, 1, -1, //
      1, 1, 1, //
      1, 0, 1, //
      // side1 face
      0, 0, 1, //
      1, 0, 1, //
      1, 1, 1, //
      1, 1, 1, //
      0, 1, 1, //
      0, 0, 1, //
      // side2 face
      1, 0, -1, //
      0, 0, -1, //
      0, 1, -1, //
      0, 1, -1, //
      1, 1, -1, //
      1, 0, -1, //
      // front face
      0, 0, -1, //
      0, 0, 1, //
      0, 1, 1, //
      0, 1, 1, //
      0, 1, -1, //
      0, 0, -1, //
      // bottom face
      0, 0, 1, //
      0, 0, -1, //
      1, 0, -1, //
      1, 0, -1, //
      1, 0, 1, //
      0, 0, 1, //
    ];

    final arrowTailTextureCoordinates = <double>[
      // top face
      0, 0, //
      1, 0, //
      1, 1, //
      1, 1, //
      0, 1, //
      0, 0, //
      // behind face
      0, 0, //
      1, 0, //
      1, 1, //
      1, 1, //
      0, 1, //
      0, 0, //
      // side1 face
      0, 0, //
      1, 0, //
      1, 1, //
      1, 1, //
      0, 1, //
      0, 0, //
      // side2 face
      0, 0, //
      1, 0, //
      1, 1, //
      1, 1, //
      0, 1, //
      0, 0, //
      // front face
      0, 0, //
      1, 0, //
      1, 1, //
      1, 1, //
      0, 1, //
      0, 0, //
      // bottom face
      0, 0, //
      1, 0, //
      1, 1, //
      1, 1, //
      0, 1, //
      0, 0, //
    ];

    renderer.arrowTailPositions = Float32List.fromList(arrowTailData);
    renderer.arrowTailTextureCoordinates = Float32List.fromList(
      arrowTailTextureCoordinates,
    );

    // -----------------------------
    // Arrow head (geometry)
    // -----------------------------
    final arrowHeadData = <double>[
      // top face
      0, 1, 1, //
      1.732, 1, 0, //
      0, 1, -1, //
      // side1 face
      0, 0, 1, //
      1.723, 0, 0, //
      1.732, 1, 0, //
      1.732, 1, 0, //
      0, 1, 1, //
      0, 0, 1, //
      // side2 face
      1.732, 0, 0, //
      0, 0, -1, //
      0, 1, -1, //
      0, 1, -1, //
      1.732, 1, 0, //
      1.732, 0, 0, //
      // back face
      0, 0, -1, //
      0, 0, 1, //
      0, 1, 1, //
      0, 1, 1, //
      0, 1, -1, //
      0, 0, -1, //
    ];

    renderer.arrowHeadPositions = Float32List.fromList(arrowHeadData);

    // -----------------------------
    // Arc model (guide ring) - exact layout as Java
    // -----------------------------
    final limit = ARG_ANGLE_LIMIT * CIRC_SEGMENTS ~/ 360;
    final arcData = List<double>.filled(
      limit * 6 * 3 * 3 /* 3 blocks of 6*3 */,
      0.0,
    );

    angle = 0.0;
    final radius1 = 6.3 * RADIUS;
    final radius2 = 7.0 * RADIUS;
    const arcTop = BOARD_TOP;
    const arcHeight = HEIGHT * 1 / 3;

    var idxInner = 0; // inner
    var idxOuter = limit * 6 * 3; // outer
    var idxTop = limit * 6 * 3 * 2; // top

    for (int i = 0; i < limit; i++) {
      final x1 = radius2 * math.cos(angle);
      final y1 = radius2 * math.sin(angle);

      final angle2 = angle + 2.0 * math.pi / CIRC_SEGMENTS;

      final x2 = radius2 * math.cos(angle2);
      final y2 = radius2 * math.sin(angle2);

      // inner strip (outer radius: radius2)
      // (b, d, a)
      arcData[idxInner++] = x1;
      arcData[idxInner++] = arcTop;
      arcData[idxInner++] = -y1;

      arcData[idxInner++] = x2;
      arcData[idxInner++] = arcTop + arcHeight;
      arcData[idxInner++] = -y2;

      arcData[idxInner++] = x1;
      arcData[idxInner++] = arcTop + arcHeight;
      arcData[idxInner++] = -y1;

      // (b, c, d)
      arcData[idxInner++] = x1;
      arcData[idxInner++] = arcTop;
      arcData[idxInner++] = -y1;

      arcData[idxInner++] = x2;
      arcData[idxInner++] = arcTop;
      arcData[idxInner++] = -y2;

      arcData[idxInner++] = x2;
      arcData[idxInner++] = arcTop + arcHeight;
      arcData[idxInner++] = -y2;

      final x3 = radius1 * math.cos(angle);
      final y3 = radius1 * math.sin(angle);

      angle += 2.0 * math.pi / CIRC_SEGMENTS;

      final x4 = radius1 * math.cos(angle);
      final y4 = radius1 * math.sin(angle);

      // outer strip (inner radius: radius1)
      // (d, b, a)
      arcData[idxOuter++] = x4;
      arcData[idxOuter++] = arcTop + arcHeight;
      arcData[idxOuter++] = -y4;

      arcData[idxOuter++] = x3;
      arcData[idxOuter++] = arcTop;
      arcData[idxOuter++] = -y3;

      arcData[idxOuter++] = x3;
      arcData[idxOuter++] = arcTop + arcHeight;
      arcData[idxOuter++] = -y3;

      // (c, b, d)
      arcData[idxOuter++] = x4;
      arcData[idxOuter++] = arcTop;
      arcData[idxOuter++] = -y4;

      arcData[idxOuter++] = x3;
      arcData[idxOuter++] = arcTop;
      arcData[idxOuter++] = -y3;

      arcData[idxOuter++] = x4;
      arcData[idxOuter++] = arcTop + arcHeight;
      arcData[idxOuter++] = -y4;

      // top cap
      // tri 1: x3, x1, x4
      arcData[idxTop++] = x3;
      arcData[idxTop++] = arcTop + arcHeight;
      arcData[idxTop++] = -y3;

      arcData[idxTop++] = x1;
      arcData[idxTop++] = arcTop + arcHeight;
      arcData[idxTop++] = -y1;

      arcData[idxTop++] = x4;
      arcData[idxTop++] = arcTop + arcHeight;
      arcData[idxTop++] = -y4;

      // tri 2: x2, x4, x1
      arcData[idxTop++] = x2;
      arcData[idxTop++] = arcTop + arcHeight;
      arcData[idxTop++] = -y2;

      arcData[idxTop++] = x4;
      arcData[idxTop++] = arcTop + arcHeight;
      arcData[idxTop++] = -y4;

      arcData[idxTop++] = x1;
      arcData[idxTop++] = arcTop + arcHeight;
      arcData[idxTop++] = -y1;
    }

    renderer.arcPositions = Float32List.fromList(arcData);

    // -----------------------------
    // Object colors (single array, same pattern as Java)
    // -----------------------------
    final objectColorData = <double>[];
    final totalColorFloats = CIRC_SEGMENTS * 6 * 4 * 3; // same as Java size

    for (int i = 0; i < totalColorFloats; i += 4) {
      objectColorData.addAll([0.2, 0.2, 0.2, 0.9]);
    }

    renderer.objectColors = Float32List.fromList(objectColorData);

    // -----------------------------
    // Floor (positions + texcoords)
    // -----------------------------
    final floorData = <double>[];
    final floorTextureCoordinates = <double>[];

    for (int i = 0; i < FLOOR_SECTIONS; i++) {
      for (int j = 0; j < FLOOR_SECTIONS; j++) {
        final x = i * FLOOR_COORD;
        final y = j * FLOOR_COORD;

        // vertices
        floorData.addAll([
          x + FLOOR_COORD, 0.0, y, //
          x, 0.0, y, //
          x, 0.0, y + FLOOR_COORD, //
          x, 0.0, y + FLOOR_COORD, //
          x + FLOOR_COORD, 0.0, y + FLOOR_COORD, //
          x + FLOOR_COORD, 0.0, y, //
        ]);

        // texture coords
        floorTextureCoordinates.addAll([
          1.0, 0.0, //
          0.0, 0.0, //
          0.0, -1.0, //
          0.0, -1.0, //
          1.0, -1.0, //
          1.0, 0.0, //
        ]);
      }
    }

    renderer.floorPositions = Float32List.fromList(floorData);
    renderer.floorTextureCoordinates = Float32List.fromList(
      floorTextureCoordinates,
    );
  }
}
