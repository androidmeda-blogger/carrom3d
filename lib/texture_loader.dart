import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Helper class for loading image textures from assets
class TextureLoader {
  /// Load a single image from assets
  static Future<ui.Image> loadImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui. instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      print('Error loading texture $assetPath: $e');
      // Return a placeholder 1x1 white image on error
      return _createPlaceholderImage();
    }
  }

  /// Load all textures needed for the game
  static Future<Map<String, ui.Image>> loadAllTextures() async {
    final textures = <String, ui.Image>{};
    
    // Board and environment
    textures['frame'] = await loadImage('assets/images/bumpy_bricks_public_domain.jpg');
    textures['surface'] = await loadImage('assets/images/board_custom.png');
    textures['floor'] = await loadImage('assets/images/tiles_large.png');
    textures['wall'] = await loadImage('assets/images/fiber_wall.png');
    
    // Piece top textures
    textures['red'] = await loadImage('assets/images/red_pieces.png');
    textures['white'] = await loadImage('assets/images/white_pieces.png');
    textures['black'] = await loadImage('assets/images/black_pieces.png');
    textures['disk'] = await loadImage('assets/images/disk_piece.png');
    textures['hdisk'] = await loadImage('assets/images/hdisk_piece.png');
    textures['rdisk'] = await loadImage('assets/images/rdisk_piece.png');
    
    // Piece border textures
    textures['red_border'] = await loadImage('assets/images/red_border.png');
    textures['white_border'] = await loadImage('assets/images/white_border.png');
    textures['black_border'] = await loadImage('assets/images/black_border.png');
    textures['disk_border'] = await loadImage('assets/images/disk_border.png');
    textures['hdisk_border'] = await loadImage('assets/images/hdisk_border.png');
    textures['rdisk_border'] = await loadImage('assets/images/rdisk_border.png');
    
    return textures;
  }

  /// Create a 1x1 white placeholder image
  static Future<ui.Image> _createPlaceholderImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), paint);
    final picture = recorder.endRecording();
    return picture.toImage(1, 1);
  }
}

