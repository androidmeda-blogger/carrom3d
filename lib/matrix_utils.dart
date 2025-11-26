import 'dart:typed_data';
import 'dart:math' as math;

/// Matrix utilities for 3D transformations
/// Replicates Android Matrix operations
class MatrixUtils {
  /// Creates an identity matrix
  static Float32List identity() {
    return Float32List.fromList([
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
    ]);
  }

  /// Sets the matrix to identity
  static void setIdentity(Float32List matrix) {
    matrix[0] = 1;
    matrix[1] = 0;
    matrix[2] = 0;
    matrix[3] = 0;
    matrix[4] = 0;
    matrix[5] = 1;
    matrix[6] = 0;
    matrix[7] = 0;
    matrix[8] = 0;
    matrix[9] = 0;
    matrix[10] = 1;
    matrix[11] = 0;
    matrix[12] = 0;
    matrix[13] = 0;
    matrix[14] = 0;
    matrix[15] = 1;
  }

  /// Sets up a perspective projection matrix (frustum)
  static void frustum(
    Float32List matrix,
    double left,
    double right,
    double bottom,
    double top,
    double near,
    double far,
  ) {
    final width = right - left;
    final height = top - bottom;
    final depth = far - near;

    matrix[0] = 2 * near / width;
    matrix[1] = 0;
    matrix[2] = 0;
    matrix[3] = 0;

    matrix[4] = 0;
    matrix[5] = 2 * near / height;
    matrix[6] = 0;
    matrix[7] = 0;

    matrix[8] = (right + left) / width;
    matrix[9] = (top + bottom) / height;
    matrix[10] = -(far + near) / depth;
    matrix[11] = -1;

    matrix[12] = 0;
    matrix[13] = 0;
    matrix[14] = -2 * far * near / depth;
    matrix[15] = 0;
  }

  /// Sets up a look-at view matrix
  static void setLookAt(
    Float32List matrix,
    double eyeX,
    double eyeY,
    double eyeZ,
    double centerX,
    double centerY,
    double centerZ,
    double upX,
    double upY,
    double upZ,
  ) {
    // Calculate forward vector
    var fx = centerX - eyeX;
    var fy = centerY - eyeY;
    var fz = centerZ - eyeZ;

    // Normalize forward
    var fLen = math.sqrt(fx * fx + fy * fy + fz * fz);
    if (fLen == 0) {
      return;
    }
    fx /= fLen;
    fy /= fLen;
    fz /= fLen;

    // Calculate side vector (cross product of forward and up)
    var sx = fy * upZ - fz * upY;
    var sy = fz * upX - fx * upZ;
    var sz = fx * upY - fy * upX;

    // Normalize side
    var sLen = math.sqrt(sx * sx + sy * sy + sz * sz);
    if (sLen == 0) {
      return;
    }
    sx /= sLen;
    sy /= sLen;
    sz /= sLen;

    // Calculate up vector (cross product of side and forward)
    var ux = sy * fz - sz * fy;
    var uy = sz * fx - sx * fz;
    var uz = sx * fy - sy * fx;

    matrix[0] = sx;
    matrix[1] = ux;
    matrix[2] = -fx;
    matrix[3] = 0;

    matrix[4] = sy;
    matrix[5] = uy;
    matrix[6] = -fy;
    matrix[7] = 0;

    matrix[8] = sz;
    matrix[9] = uz;
    matrix[10] = -fz;
    matrix[11] = 0;

    matrix[12] = 0;
    matrix[13] = 0;
    matrix[14] = 0;
    matrix[15] = 1;

    translate(matrix, -eyeX, -eyeY, -eyeZ);
  }

  /// Multiplies two 4x4 matrices (column-major):
  /// result = lhs * rhs
  ///
  /// IMPORTANT:
  ///   result must NOT be the same Float32List as lhs or rhs.
  ///   (Same rule as android.opengl.Matrix.multiplyMM)
  static void multiplyMM(Float32List result, Float32List lhs, Float32List rhs) {
    for (int i = 0; i < 4; i++) {
      // Column i of RHS (column-major)
      final double rhs0 = rhs[i * 4 + 0];
      final double rhs1 = rhs[i * 4 + 1];
      final double rhs2 = rhs[i * 4 + 2];
      final double rhs3 = rhs[i * 4 + 3];

      // Compute column i of the result = lhs * rhs(column i)
      result[i * 4 + 0] =
          lhs[0] * rhs0 + lhs[4] * rhs1 + lhs[8] * rhs2 + lhs[12] * rhs3;
      result[i * 4 + 1] =
          lhs[1] * rhs0 + lhs[5] * rhs1 + lhs[9] * rhs2 + lhs[13] * rhs3;
      result[i * 4 + 2] =
          lhs[2] * rhs0 + lhs[6] * rhs1 + lhs[10] * rhs2 + lhs[14] * rhs3;
      result[i * 4 + 3] =
          lhs[3] * rhs0 + lhs[7] * rhs1 + lhs[11] * rhs2 + lhs[15] * rhs3;
    }
  }

  /// Translates the matrix
  static void translate(Float32List matrix, double x, double y, double z) {
    for (int i = 0; i < 4; i++) {
      matrix[12 + i] += matrix[i] * x + matrix[4 + i] * y + matrix[8 + i] * z;
    }
  }

  /// Rotates the matrix around an axis
  static void rotate(
    Float32List matrix,
    double angleDegrees,
    double x,
    double y,
    double z,
  ) {
    if (angleDegrees == 0) return;

    final angleRadians = angleDegrees * math.pi / 180.0;
    final c = math.cos(angleRadians);
    final s = math.sin(angleRadians);

    // Normalize axis
    final len = math.sqrt(x * x + y * y + z * z);
    if (len == 0) return;

    final nx = x / len;
    final ny = y / len;
    final nz = z / len;

    final nc = 1 - c;
    final xy = nx * ny;
    final yz = ny * nz;
    final zx = nz * nx;
    final xs = nx * s;
    final ys = ny * s;
    final zs = nz * s;

    final rotMatrix = Float32List(16);
    rotMatrix[0] = nx * nx * nc + c;
    rotMatrix[1] = xy * nc + zs;
    rotMatrix[2] = zx * nc - ys;
    rotMatrix[3] = 0;

    rotMatrix[4] = xy * nc - zs;
    rotMatrix[5] = ny * ny * nc + c;
    rotMatrix[6] = yz * nc + xs;
    rotMatrix[7] = 0;

    rotMatrix[8] = zx * nc + ys;
    rotMatrix[9] = yz * nc - xs;
    rotMatrix[10] = nz * nz * nc + c;
    rotMatrix[11] = 0;

    rotMatrix[12] = 0;
    rotMatrix[13] = 0;
    rotMatrix[14] = 0;
    rotMatrix[15] = 1;

    final temp = Float32List(16);
    multiplyMM(temp, matrix, rotMatrix);
    for (int i = 0; i < 16; i++) {
      matrix[i] = temp[i];
    }
  }

  /// Scales the matrix
  static void scale(Float32List matrix, double x, double y, double z) {
    for (int i = 0; i < 4; i++) {
      matrix[i] *= x;
      matrix[4 + i] *= y;
      matrix[8 + i] *= z;
    }
  }

  /// Transforms a 3D point by a matrix
  static List<double> transformPoint(
    Float32List matrix,
    double x,
    double y,
    double z,
  ) {
    final w = matrix[3] * x + matrix[7] * y + matrix[11] * z + matrix[15];

    return [
      (matrix[0] * x + matrix[4] * y + matrix[8] * z + matrix[12]) / w,
      (matrix[1] * x + matrix[5] * y + matrix[9] * z + matrix[13]) / w,
      (matrix[2] * x + matrix[6] * y + matrix[10] * z + matrix[14]) / w,
    ];
  }

  /// Copies a matrix
  static Float32List copy(Float32List matrix) {
    return Float32List.fromList(matrix);
  }

  /// Inverts a 4x4 matrix
  /// Returns true if successful, false if matrix is singular
  static bool invertM(Float32List result, Float32List m) {
    // Using Gauss-Jordan elimination with partial pivoting
    final temp = Float32List.fromList(m);
    final inv = Float32List(16);

    // Initialize result as identity
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        inv[i * 4 + j] = (i == j) ? 1.0 : 0.0;
      }
    }

    // Forward elimination
    for (int i = 0; i < 4; i++) {
      // Find pivot
      double maxVal = temp[i * 4 + i].abs();
      int maxRow = i;
      for (int k = i + 1; k < 4; k++) {
        if (temp[k * 4 + i].abs() > maxVal) {
          maxVal = temp[k * 4 + i].abs();
          maxRow = k;
        }
      }

      // Check for singular matrix
      if (maxVal < 1e-10) {
        return false;
      }

      // Swap rows if needed
      if (maxRow != i) {
        for (int k = 0; k < 4; k++) {
          double tmpT = temp[i * 4 + k];
          temp[i * 4 + k] = temp[maxRow * 4 + k];
          temp[maxRow * 4 + k] = tmpT;

          double tmpI = inv[i * 4 + k];
          inv[i * 4 + k] = inv[maxRow * 4 + k];
          inv[maxRow * 4 + k] = tmpI;
        }
      }

      // Scale pivot row
      double pivot = temp[i * 4 + i];
      for (int k = 0; k < 4; k++) {
        temp[i * 4 + k] /= pivot;
        inv[i * 4 + k] /= pivot;
      }

      // Eliminate column
      for (int j = 0; j < 4; j++) {
        if (j != i) {
          double factor = temp[j * 4 + i];
          for (int k = 0; k < 4; k++) {
            temp[j * 4 + k] -= factor * temp[i * 4 + k];
            inv[j * 4 + k] -= factor * inv[i * 4 + k];
          }
        }
      }
    }

    // Copy result
    for (int i = 0; i < 16; i++) {
      result[i] = inv[i];
    }

    return true;
  }

  /// Multiplies a 4x4 matrix by a 4D vector
  static void multiplyMV(
    Float32List result,
    Float32List matrix,
    Float32List vector,
  ) {
    final x = vector[0];
    final y = vector[1];
    final z = vector[2];
    final w = vector[3];

    result[0] = matrix[0] * x + matrix[4] * y + matrix[8] * z + matrix[12] * w;
    result[1] = matrix[1] * x + matrix[5] * y + matrix[9] * z + matrix[13] * w;
    result[2] = matrix[2] * x + matrix[6] * y + matrix[10] * z + matrix[14] * w;
    result[3] = matrix[3] * x + matrix[7] * y + matrix[11] * z + matrix[15] * w;
  }
}
