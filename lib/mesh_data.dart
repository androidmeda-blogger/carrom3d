import 'dart:typed_data';
import 'dart:math' as math;
import 'game_renderer.dart';

/// MeshData - 1:1 port of MeshData.java
/// Contains all 3D geometry data for the game
class MeshData {
  // Constants from MeshData.java (matching exactly)
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
  static const double DEG_TO_RAD = math.pi / 180;
  static const double RAD_TO_DEG = 180 / math.pi;
  static const double HOLE_RADIUS = RADIUS * DISK_RADIUS_FACTOR;
  static const int HOLE_ANI_LIMIT = 4;
  static const double PIECES_GAP = RADIUS / 5;
  
  static const double DISK_DOWN_TOUCH_LIMIT = DISK_START_DIST + DISK_START_DOWN_DIFF + RADIUS * DISK_RADIUS_FACTOR * 1.5;
  static const double DISK_UP_TOUCH_LIMIT = DISK_START_DIST - DISK_START_UP_DIFF - RADIUS * DISK_RADIUS_FACTOR * 1.5;
  
  static const double RED_CIRCLE_RADIUS = RADIUS * 0.8;
  
  static const double FLOOR_WIDTH = 12.0;
  static const int FLOOR_SECTIONS = 6;
  static const double FLOOR_COORD = FLOOR_WIDTH / FLOOR_SECTIONS;

  // Static method matching Java: public static void initData(GameRenderer renderer)
  static void initData(GameRenderer renderer) {
    // Defining the edge of the board (matching Java exactly)
    final boardEdgePositionData = <double>[
      // Front face
      -1.0, 0.15, 1.0, -1.0, -0.15, 1.0,
      1.0, 0.15, 1.0,
      -1.0, -0.15, 1.0,
      1.0, -0.15, 1.0,
      1.0, 0.15, 1.0,

      // Right face
      1.0, 0.15, 1.0, 1.0, -0.15, 1.0,
      1.0, 0.15, -1.0,
      1.0, -0.15, 1.0,
      1.0, -0.15, -1.0,
      1.0, 0.15, -1.0,

      // Back face
      1.0, 0.15, -1.0, 1.0, -0.15, -1.0, -1.0, 0.15, -1.0,
      1.0, -0.15, -1.0,
      -1.0, -0.15, -1.0,
      -1.0, 0.15, -1.0,

      // Left face
      -1.0, 0.15, -1.0, -1.0, -0.15, -1.0, -1.0, 0.15, 1.0,
      -1.0, -0.15, -1.0,
      -1.0, -0.15, 1.0,
      -1.0, 0.15, 1.0,

      // Bottom face
      1.0, -0.15, -1.0, 1.0, -0.15, 1.0, -1.0, -0.15, -1.0,
      1.0, -0.15, 1.0,
      -1.0, -0.15, 1.0,
      -1.0, -0.15, -1.0,

      // Top face - front
      -0.9, 0.15, 0.9, -1.0, 0.15, 1.0, 0.9, 0.15, 0.9,
      -1.0, 0.15, 1.0,
      1.0, 0.15, 1.0,
      0.9, 0.15, 0.9,

      // Top face - back
      -1.0, 0.15, -1.0, -0.9, 0.15, -0.9, 1.0, 0.15, -1.0,
      -0.9, 0.15, -0.9,
      0.9, 0.15, -0.9,
      1.0, 0.15, -1.0,

      // Top face - right
      0.9, 0.15, -0.9, 0.9, 0.15, 0.9, 1.0, 0.15, -1.0,
      0.9, 0.15, 0.9, 1.0, 0.15, 1.0,
      1.0, 0.15, -1.0,

      // Top face - left
      -1.0, 0.15, -1.0, -1.0, 0.15, 1.0, -0.9, 0.15, -0.9,
      -1.0, 0.15, 1.0,
      -0.9, 0.15, 0.9,
      -0.9, 0.15, -0.9,

      // The inner faces
      // Inner Front face
      -1.0, 0.15, -0.9, -1.0, 0.11, -0.9, 1.0, 0.15, -0.9,
      -1.0, 0.11, -0.9, 1.0, 0.11, -0.9,
      1.0, 0.15, -0.9,

      // Inner Right face
      -0.9, 0.15, 1.0, -0.9, 0.11, 1.0, -0.9, 0.15, -1.0,
      -0.9, 0.11, 1.0, -0.9, 0.11, -1.0, -0.9, 0.15, -1.0,

      // Inner Back face
      1.0, 0.15, 0.9, 1.0, 0.11, 0.9, -1.0, 0.15, 0.9, 1.0,
      0.11, 0.9, -1.0, 0.11, 0.9, -1.0, 0.15, 0.9,

      // Inner Left face
      0.9, 0.15, -1.0, 0.9, 0.11, -1.0, 0.9, 0.15, 1.0,
      0.9, 0.11, -1.0, 0.9, 0.11, 1.0, 0.9, 0.15, 1.0,

      // Inner Bottom face
      -0.9, 0.11, -0.9, -0.9, 0.11, 0.9, 0.9, 0.11, 0.9,
      -0.9, 0.11, -0.9, 0.9, 0.11, 0.9, 0.9, 0.11, -0.9,
    ];

    // Texture coordinate data (matching Java)
    final cubeTextureCoordinateData = <double>[
      // Front face
      0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0,

      // Right face
      0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0,

      // Back face
      0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0,

      // Left face
      0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0,

      // Bottom face
      0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0,

      // Top face 1
      0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0,

      // Top face 2
      0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0,

      // Top face 3
      1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0,

      // Top face 4
      1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0,

      // Internal face 1
      0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0,

      // Internal face 2
      0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0,

      // Internal face 3
      0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0,

      // Internal face 4
      0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0,

      // Internal face top
      1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0,
    ];

    // Initialize the buffers in the renderer (matching Java)
    renderer.cubePositions = Float32List.fromList(boardEdgePositionData);
    renderer.cubeTextureCoordinates = Float32List.fromList(cubeTextureCoordinateData);

    // Create the cylinder template (matching Java logic)
    final cylinderData = <double>[];
    final cylinderTextureData = <double>[];
    
    var angle = 0.0;
    const radius = RADIUS;
    const top = -HEIGHT / 2;
    const height = HEIGHT;

    for (int i = 0; i < CIRC_SEGMENTS; i++) {
      final x1 = radius * math.cos(angle);
      final y1 = radius * math.sin(angle);

      angle += 2 * math.pi / CIRC_SEGMENTS;

      final x2 = radius * math.cos(angle);
      final y2 = radius * math.sin(angle);

      // Side triangles
      cylinderData.addAll([x1, top, -y1, x2, top + height, -y2, x1, top + height, -y1]);
      cylinderData.addAll([x1, top, -y1, x2, top, -y2, x2, top + height, -y2]);

      cylinderTextureData.addAll([0.0, 1.0, 1.0, 0.0, 0.0, 0.0]);
      cylinderTextureData.addAll([0.0, 1.0, 1.0, 1.0, 1.0, 0.0]);

      // Top face triangle
      cylinderData.addAll([0.0, top + height, 0.0, x1, top + height, -y1, x2, top + height, -y2]);
      cylinderTextureData.addAll([0.0, 1.0, 1.0, 0.0, 0.0, 0.0]);
    }

    renderer.cylinderPositions = Float32List.fromList(cylinderData);
    renderer.cylinderTextureCoordinates = Float32List.fromList(cylinderTextureData);

    // Create disk (scaled cylinder for striker)
    final diskData = <double>[];
    for (int i = 0; i < cylinderData.length; i += 3) {
      diskData.add(cylinderData[i] * DISK_RADIUS_FACTOR);
      diskData.add(cylinderData[i + 1] * DISK_HEIGHT_FACTOR);
      diskData.add(cylinderData[i + 2] * DISK_RADIUS_FACTOR);
    }

    renderer.diskPositions = Float32List.fromList(diskData);

    // Create arrow tail (matching Java)
    final arrowTailData = <double>[
      // Top face
      0, 1, 1, 1, 1, 1, 1, 1, -1,
      1, 1, -1, 0, 1, -1, 0, 1, 1,

      // Behind face
      1, 0, 1, 1, 0, -1, 1, 1, -1,
      1, 1, -1, 1, 1, 1, 1, 0, 1,

      // Side1 face
      0, 0, 1, 1, 0, 1, 1, 1, 1,
      1, 1, 1, 0, 1, 1, 0, 0, 1,

      // Side2 face
      1, 0, -1, 0, 0, -1, 0, 1, -1,
      0, 1, -1, 1, 1, -1, 1, 0, -1,

      // Front face
      0, 0, -1, 0, 0, 1, 0, 1, 1,
      0, 1, 1, 0, 1, -1, 0, 0, -1,

      // Bottom face
      0, 0, 1, 0, 0, -1, 1, 0, -1,
      1, 0, -1, 1, 0, 1, 0, 0, 1,
    ];

    final arrowTailTexCoords = <double>[
      // Top face
      0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0,

      // Behind face
      0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0,

      // Side1 face
      0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0,

      // Side2 face
      0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0,

      // Front face
      0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0,

      // Bottom face
      0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0,
    ];

    renderer.arrowTailPositions = Float32List.fromList(arrowTailData);
    renderer.arrowTailTextureCoordinates = Float32List.fromList(arrowTailTexCoords);

    // Create arrow head (matching Java)
    final arrowHeadData = <double>[
      // Top face
      0, 1, 1, 1.732, 1, 0, 0, 1, -1,

      // Side1 face
      0, 0, 1, 1.723, 0, 0, 1.732, 1, 0,
      1.732, 1, 0, 0, 1, 1, 0, 0, 1,

      // Side2 face
      1.732, 0, 0, 0, 0, -1, 0, 1, -1,
      0, 1, -1, 1.732, 1, 0, 1.732, 0, 0,

      // Back face
      0, 0, -1, 0, 0, 1, 0, 1, 1, 0, 1, 1,
      0, 1, -1, 0, 0, -1,
    ];

    renderer.arrowHeadPositions = Float32List.fromList(arrowHeadData);

    // Create arc model (matching Java)
    final limit = ARG_ANGLE_LIMIT * CIRC_SEGMENTS ~/ 360;
    final arcData = <double>[];

    angle = 0.0;
    final radius1 = 6.3 * RADIUS;
    final radius2 = 7.0 * RADIUS;
    const arcTop = BOARD_TOP;
    const arcHeight = HEIGHT * 1 / 3;

    for (int i = 0; i < limit; i++) {
      final x1 = radius2 * math.cos(angle);
      final y1 = radius2 * math.sin(angle);

      final angle2 = angle + 2 * math.pi / CIRC_SEGMENTS;

      final x2 = radius2 * math.cos(angle2);
      final y2 = radius2 * math.sin(angle2);

      // The inner loop
      arcData.addAll([x1, arcTop, -y1, x2, arcTop + arcHeight, -y2, x1, arcTop + arcHeight, -y1]);
      arcData.addAll([x1, arcTop, -y1, x2, arcTop, -y2, x2, arcTop + arcHeight, -y2]);

      final x3 = radius1 * math.cos(angle);
      final y3 = radius1 * math.sin(angle);

      angle += 2 * math.pi / CIRC_SEGMENTS;

      final x4 = radius1 * math.cos(angle);
      final y4 = radius1 * math.sin(angle);

      // The outer loop
      arcData.addAll([x4, arcTop + arcHeight, -y4, x3, arcTop, -y3, x3, arcTop + arcHeight, -y3]);
      arcData.addAll([x4, arcTop, -y4, x3, arcTop, -y3, x4, arcTop + arcHeight, -y4]);

      // For the top
      arcData.addAll([x3, arcTop + arcHeight, -y3, x1, arcTop + arcHeight, -y1, x4, arcTop + arcHeight, -y4]);
      arcData.addAll([x2, arcTop + arcHeight, -y2, x4, arcTop + arcHeight, -y4, x1, arcTop + arcHeight, -y1]);
    }

    renderer.arcPositions = Float32List.fromList(arcData);

    // Create object colors (matching Java)
    final objectColorData = <double>[];
    for (int i = 0; i < CIRC_SEGMENTS * 6 * 4 * 3; i += 4) {
      objectColorData.addAll([0.2, 0.2, 0.2, 0.9]);
    }

    renderer.objectColors = Float32List.fromList(objectColorData);

    // Create floor and wall (matching Java)
    final floorData = <double>[];
    final floorTexCoords = <double>[];

    for (int i = 0; i < FLOOR_SECTIONS; i++) {
      for (int j = 0; j < FLOOR_SECTIONS; j++) {
        final x = i * FLOOR_COORD;
        final y = j * FLOOR_COORD;

        floorData.addAll([
          x + FLOOR_COORD, 0, y,
          x, 0, y,
          x, 0, y + FLOOR_COORD,
          x, 0, y + FLOOR_COORD,
          x + FLOOR_COORD, 0, y + FLOOR_COORD,
          x + FLOOR_COORD, 0, y,
        ]);

        floorTexCoords.addAll([
          1.0, 0.0,
          0.0, 0.0,
          0.0, -1.0,
          0.0, -1.0,
          1.0, -1.0,
          1.0, 0.0,
        ]);
      }
    }

    renderer.floorPositions = Float32List.fromList(floorData);
    renderer.floorTextureCoordinates = Float32List.fromList(floorTexCoords);
  }
}
