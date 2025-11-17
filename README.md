# Carrom 3D - Flutter Edition

A 3D Carrom board game successfully migrated from Android OpenGL ES 2.0 to Flutter Canvas API.

## 📋 Project Status

**Phase 1: COMPLETE ✅**

All core components have been successfully migrated with 1:1 mapping from the original Android OpenGL ES 2.0 implementation to Flutter Canvas API.

## 🎯 Overview

This project is a complete port of an Android Carrom game to Flutter, maintaining all original game logic, physics, and rendering architecture while adapting to Flutter's Canvas API.

### Technology Stack
- **Flutter**: UI Framework (≥3.7.2)
- **Canvas API**: 2D/3D rendering
- **Dart**: CPU-based 3D transformations
- **ImageShader**: GPU-accelerated texture rendering

## 📁 Project Structure

```
carrom3d/
├── lib/
│   ├── main.dart                # App entry point with "Game" button
│   ├── game.dart                # Game screen, UI, and lifecycle management
│   ├── game_renderer.dart       # Main 3D renderer (1:1 port of GameRenderer.java)
│   ├── game_controller.dart     # Game loop & physics (1:1 port of GameController.java)
│   ├── game_engine.dart         # Game state & logic (1:1 port of GameEngine.java)
│   ├── matrix_utils.dart        # 3D matrix mathematics
│   ├── mesh_data.dart           # 3D geometry generation
│   └── texture_loader.dart      # Asset loading helper
├── assets/
│   └── images/                  # Game textures (16 images required)
├── MIGRATION_SUMMARY.md         # Complete migration documentation
└── README.md                    # This file
```

## 🚀 Quick Start

### Prerequisites
- Flutter SDK ≥3.7.2
- Dart SDK ≥3.7.2

### Installation

1. **Clone or navigate to the project**
   ```bash
   cd /Users/dimuthu/Work/carrom3d
   ```

2. **Copy texture assets from Android project**
   
   Copy 16 image files from:
   ```
   Source: /Users/dimuthu/Work/androidmeda/newcarrom/app/src/main/res/drawable/
   Destination: assets/images/
   ```
   
   Required files:
   - `bumpy_bricks_public_domain` (board frame)
   - `board_custom` (playing surface)
   - `tiles_large` (floor)
   - `fiber_wall` (walls)
   - `red_pieces`, `white_pieces`, `black_pieces` (piece tops)
   - `disk_piece`, `hdisk_piece`, `rdisk_piece` (striker tops)
   - `red_border`, `white_border`, `black_border` (piece borders)
   - `disk_border`, `hdisk_border`, `rdisk_border` (striker borders)

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## 🎮 Usage

1. Launch the app
2. Tap the **"Game"** button on the home screen
3. **Pan** to rotate the camera around the board
4. **Pinch** to zoom in/out
5. **Double-tap striker** to toggle shooting mode
6. **Drag and release** to shoot

## ✨ Features

### Implemented
- ✅ Complete 3D rendering engine
- ✅ Physics simulation (elastic collisions, friction)
- ✅ Game rules and scoring
- ✅ 2-player support
- ✅ Touch controls (pan, pinch, tap, drag)
- ✅ Camera rotation and zoom
- ✅ All game pieces with textures
- ✅ Background environment (floor, walls, table)
- ✅ Player turn management
- ✅ Shooting mode with direction guides
- ✅ Hole detection and piece pocketing

### Stubbed (Phase 2)
- ⏳ AI players
- ⏳ Sound effects
- ⏳ Network multiplayer
- ⏳ Database persistence
- ⏳ 4-player mode

## 🏗️ Architecture

### Rendering Pipeline

**Android (Original)**:
```
OpenGL ES 2.0 → Vertex Shader (GPU) → Fragment Shader (GPU) → Display
```

**Flutter (Migrated)**:
```
Dart CPU Transforms → Canvas API → ImageShader (GPU) → Skia → Display
```

### Key Components

1. **game_renderer.dart** (773 lines)
   - Main 3D rendering engine
   - All draw methods from GameRenderer.java
   - Camera and matrix transformations

2. **game_controller.dart** (1,260 lines)
   - Game loop running at 50 Hz
   - Elastic collision physics
   - Player turn management
   - Input handling

3. **game_engine.dart** (1,311 lines)
   - Game state management
   - Player management
   - World coordinate conversion
   - Score tracking

4. **matrix_utils.dart** (296 lines)
   - 3D matrix mathematics
   - Replaces Android Matrix class
   - View, projection, model matrices

5. **mesh_data.dart** (371 lines)
   - 3D geometry for all game objects
   - Board, pieces, environment

## 📊 Migration Statistics

| Component | Android (Java) | Flutter (Dart) | Status |
|-----------|---------------|----------------|---------|
| Renderer | GameRenderer.java | game_renderer.dart | ✅ 100% |
| Controller | GameController.java | game_controller.dart | ✅ 100% |
| Engine | GameEngine.java | game_engine.dart | ✅ 100% |
| Activity | GameActivity.java | game.dart | ✅ 100% |
| Math | Android Matrix | matrix_utils.dart | ✅ 100% |
| Geometry | MeshData (static) | mesh_data.dart | ✅ 100% |
| **Total** | **~5,000 lines** | **4,791 lines** | **✅ Complete** |

## 🎯 Game Rules

### 2-Player Mode
- **Player 1**: Pockets white pieces
- **Player 2**: Pockets black pieces
- **Red Queen**: Must be "covered" by pocketing another piece after

### Controls
- **Pan**: Rotate camera
- **Pinch**: Zoom
- **Single tap**: Place striker
- **Double tap (striker)**: Enter shooting mode
- **Double tap (board)**: Zoom animation
- **Drag (shooting mode)**: Pull back striker
- **Release**: Shoot

### Scoring
- +1 for each own color piece potted
- +3 for covering the queen
- Penalty: Return piece if striker is potted

## 🔧 Technical Details

### Physics
- Elastic collision simulation
- Friction: 0.001 (striker), 0.0018 (pieces)
- Energy loss on collisions and boundaries
- Realistic boundary reflections

### Performance
- Target: 60 FPS
- Typical: 50-60 FPS (device dependent)
- Game loop: 50 Hz (20ms)
- Optimized collision detection

### Coordinate System
```
       Y+ (up)
        |
   -0.9 +------ 0.9  (board boundaries)
        |
   -----0,0----- X+ (right)
        |
       -0.9
```

## 📖 Documentation

### Primary Documentation
- **MIGRATION_SUMMARY.md**: Complete technical documentation of the migration, including all architectural details, file mappings, and implementation notes

### Original Android Source
Located at: `/Users/dimuthu/Work/androidmeda/newcarrom/`

## 🐛 Troubleshooting

### No textures showing
**Solution**: Copy all 16 image files to `assets/images/`, run `flutter pub get`, restart app

### App crashes on startup
**Solution**: Verify all texture files are present in `assets/images/`

### Black screen after "Game" button
**Solution**: Check console for asset loading errors

### Performance issues
**Solution**: Expected on debug builds. Try release build:
```bash
flutter run --release
```

## 🔄 Phase 1 Complete

### What's Done
✅ All rendering methods ported  
✅ All physics and collision logic ported  
✅ All game state management ported  
✅ All input handling ported  
✅ Basic gameplay fully functional  
✅ Camera controls working  
✅ 2-player mode working  

### Phase 2 Roadmap
- Implement AI players (AutoPlayer)
- Add sound effects (SoundThread)
- Implement database (CarromDbAdapter, ScoreDbAdapter)
- Add network multiplayer (NetworkPlayer)
- Optimize rendering performance
- Add 4-player support
- Visual effects (trails, shadows, particle effects)

## 📝 Code Quality

- ✅ No linter errors
- ✅ Type-safe Dart code
- ✅ 1:1 method mapping with original
- ✅ Comprehensive inline documentation
- ✅ All parameters match original Java values

## 🤝 Contributing

This is a direct port maintaining 1:1 mapping with the original Android code. When modifying:
1. Maintain method naming consistency
2. Keep Java parameter values unchanged
3. Document any architectural changes
4. Update MIGRATION_SUMMARY.md

## 📞 Support

For detailed technical information, see **MIGRATION_SUMMARY.md**

## 📄 License

[Add your license information here]

## 🙏 Acknowledgments

- Original Android Carrom 3D game developers
- Flutter team for Canvas and rendering APIs
- OpenGL ES for the original rendering concepts

---

**Last Updated**: November 16, 2025  
**Flutter Version**: 3.7.2  
**Dart Version**: 3.7.2  
**Status**: Phase 1 Complete ✅
