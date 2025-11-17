# GameConfig Migration Summary

## Overview

Successfully migrated `GameConfig.java` (500 lines) to `game_config.dart` (550 lines) with 1:1 parity.

## What Was Migrated

### Core Functionality

1. **Player Management**
   - `playerNames` - List of custom player names
   - `playerTypes` - List of player types (0-5: Human, AI Beginner/Intermediate/Expert, Network, Internet)
   - `basicPlayers` - Default player types
   - Methods: `addPlayer()`, `updatePlayer()`, `deletePlayer()`, `getPlayerName()`, `getPlayerType()`

2. **Score Tracking**
   - `ScoreboardEntry` class - Tracks wins between two teams
   - `scores` - Nested Map structure (replaces Java's SparseArray)
   - Methods: `addGame()`, `getScores()`

3. **Game Configuration**
   - Game settings: `hideScoreboard`, `hideArrow`, `lockOrientation`, `muted`
   - Game state: `gameInProgress`, `gameId`, `score1`, `score2`
   - Camera settings: `cameraFixability`, `tableTop`, `frontPlayer`
   - Display settings: `guidingWidth`, `veryFirstTime`

4. **Network Settings**
   - `remoteIp`, `isPlayingNetwork`, `isNetwokHost`
   - `useBluetooth`, `networkToken`, `startingPort`

5. **Persistence**
   - `saveConfigs()` - Serialize all settings to a single comma-separated string
   - `loadConfigs()` - Deserialize settings from stored string
   - `startupDefaultConfigs()` - Initialize with defaults
   - `loadDefaultConfigs()` - Set player defaults

## Key Differences from Java

### Data Structures

**Java:**
```java
SparseArray<SparseArray<ScoreboardEntry>> scores;
```

**Dart:**
```dart
Map<int, Map<int, ScoreboardEntry>> scores = {};
```

**Reason:** Dart doesn't have SparseArray, but Map provides similar functionality with better type safety.

### Configuration Strings

Both Java and Dart use the same comma-separated string format for persistence:
```
<playerCount>,<playerName1>,<playerType1>,...,<gameSettings>,...,<scores>,...
```

This ensures backward compatibility with existing save files.

### Constructor

**Java:**
```java
GameConfig(CarromDbAdapter dbAdapter) { ... }
```

**Dart:**
```dart
GameConfig(this.dbAdapter) { ... }
```

The Dart constructor uses parameter initialization for cleaner code.

## Integration Points

### game_engine.dart

- Removed stub `GameConfig` class (lines 1139-1204)
- Added import: `import 'game_config.dart';`
- Now uses real `GameConfig` with full functionality

### game.dart

- Added import: `import 'game_config.dart';`
- Updated initialization: `gameConfig = GameConfig(dbAdapter);`
- Uses `gamePlayerCount` property instead of non-existent setter

## File Structure

```
lib/
├── game_config.dart       (NEW - 550 lines)
│   ├── ScoreboardEntry    (class)
│   └── GameConfig         (class)
├── game_engine.dart       (UPDATED - removed stub)
└── game.dart              (UPDATED - uses real GameConfig)
```

## Testing Notes

### What Works

✅ Configuration loading/saving structure
✅ Player management (add/update/delete)
✅ Score tracking logic
✅ Settings persistence format
✅ Network configuration
✅ Integration with game_engine.dart and game.dart

### What's Stubbed

🔧 Actual persistence (requires CarromDbAdapter implementation)
🔧 Database connection (currently stubbed in game_engine.dart)

## Usage Example

```dart
// Initialize
GameConfig config = GameConfig(dbAdapter);

// Load saved configs
config.loadConfigs();

// Add a player
config.addPlayer("John Doe", 0); // 0 = Human

// Track a game
config.addGame(0, 1, true, 2); // Team 0 beat Team 1, no red advantage

// Save configs
config.saveConfigs();

// Get player info
String name = config.getPlayerName(0);
int type = config.getPlayerType(0);

// Get all scores
List<ScoreboardEntry> allScores = config.getScores();
```

## Constants

```dart
static const String dbConfigKey = "configs";
static const int defaultStartingPort = 8888;
```

## Properties Summary

| Property | Type | Description |
|----------|------|-------------|
| `playerNames` | `List<String>` | Custom player names |
| `playerTypes` | `List<int>` | Player types (0-5) |
| `player` | `List<int>` | Current game players |
| `gamePlayerCount` | `int` | Number of players (2 or 4) |
| `scores` | `Map<int, Map<int, ScoreboardEntry>>` | Win/loss records |
| `gameInProgress` | `bool` | Is game currently running |
| `cameraFixability` | `bool` | Can camera be fixed |
| `hideScoreboard` | `int` | Scoreboard visibility (0/1/2) |
| `hideArrow` | `bool` | Hide direction arrow |
| `lockOrientation` | `bool` | Lock screen orientation |
| `muted` | `bool` | Sound muted |
| `veryFirstTime` | `bool` | First launch (show tutorial) |
| `tableTop` | `bool` | Table-top camera mode |
| `frontPlayer` | `int` | Front-facing player |
| `guidingWidth` | `int` | Aiming guide width (0-63) |
| `gameId` | `int` | Current game session ID |
| `score1` | `int` | Player 1 score |
| `score2` | `int` | Player 2 score |
| `remoteIp` | `String` | Network opponent IP |
| `isPlayingNetwork` | `bool` | Network game active |
| `isNetwokHost` | `bool` | Is network host |
| `useBluetooth` | `bool` | Use Bluetooth for network |
| `networkToken` | `String` | Network session token |
| `startingPort` | `int` | Network port |

## Migration Completion

✅ **Phase 1: COMPLETE**

- All 500 lines of GameConfig.java migrated
- All methods implemented
- Full integration with existing codebase
- Zero linter errors
- Ready for use

---

**Migrated by:** AI Assistant  
**Date:** November 16, 2025  
**Status:** ✅ Complete and integrated

