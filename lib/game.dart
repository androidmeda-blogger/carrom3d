import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'game_renderer.dart';
import 'game_engine.dart';
import 'game_config.dart';

/// GameScreen - Direct port of GameActivity.PlaceholderFragment
/// Main game screen with touch controls, score display, and game management
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  // Core game components
  late GameRenderer gameRenderer;
  GameEngine? engine;
  late AnimationController animationController;
  
  // Database adapters
  CarromDbAdapter? dbAdapter;
  ScoreDbAdapter? scoreDbAdapter;
  GameConfig? gameConfig;
  SoundThread? soundThread;
  
  // UI state
  bool thingsLoaded = false;
  bool hideShowStatus = false;
  bool showResults = false;
  
  // Touch/gesture state
  int _pointerCount = 0;
  
  // Scale gesture detection
  double _initialSpan = 0;
  bool _isScaling = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize renderer
    gameRenderer = GameRenderer();
    
    // Animation controller for continuous rendering
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    
    animationController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    animationController.dispose();
    _cleanupGame();
    super.dispose();
  }

  void _cleanupGame() {
    if (engine != null) {
      engine!.stop();
    }
    dbAdapter?.close();
    scoreDbAdapter?.close();
  }

  /// Port of onResume() - Initialize game when screen becomes active
  Future<void> _onResume() async {
    try {
      print("=== Starting game initialization ===");
      
      showResults = false;
      hideResultsBox();

      // Load textures first
      print("Loading textures...");
      await gameRenderer.loadTextures();
      print("Textures loaded successfully");

      // Initialize database
      print("Initializing database...");
      dbAdapter = CarromDbAdapter();
      dbAdapter!.open();
      
      // Initialize game config with Human vs AI setup
      print("Loading game config...");
      gameConfig = GameConfig(dbAdapter);
      gameConfig!.loadConfigs();
      
      // Set up for Human vs AI (beginner)
      gameConfig!.gamePlayerCount = 2;
      // Player types are managed through player list in GameConfig
      // player[0] = -1 means basicPlayers[0] = "Human"
      // player[1] = -2 means basicPlayers[1] = "Machine: Beginner"

      // Check if very first time (tutorial)
      if (gameConfig!.veryFirstTime) {
        print("First time launch - skipping tutorial for now");
        gameConfig!.veryFirstTime = false;
        gameConfig!.saveConfigs();
        // Don't return - continue with game initialization
      }

      // Initialize score database
      print("Initializing score database...");
      scoreDbAdapter = ScoreDbAdapter();
      scoreDbAdapter!.open();

      hideShowStatus = false;

      // Keep screen on
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      // Initialize sound thread
      soundThread = SoundThread();

      // Initialize game engine with callback fragment
      print("Creating game engine...");
      final fragment = GameFragmentCallbacks(
        updateScorePanelCallback: _updateScorePanel,
        showResultsBoxCallback: showResultsBox,
        hideResultsBoxCallback: hideResultsBox,
      );
      
      engine = GameEngine(
        fragment,
        gameRenderer,
        MediaQuery.of(context).devicePixelRatio,
        dbAdapter,
        gameConfig,
        soundThread,
      );

      // Start the game
      print("Starting game engine...");
      if (engine != null) {
        engine!.start();
      }
      
      thingsLoaded = true;
      print("=== Game initialization complete ===");

      if (mounted) {
        setState(() {});
      }
    } catch (e, stackTrace) {
      print("ERROR during game initialization: $e");
      print("Stack trace: $stackTrace");
      
      // Set thingsLoaded to true anyway to avoid infinite loading
      thingsLoaded = true;
      if (mounted) {
        setState(() {});
      }
    }
  }


  /// Update score panel
  void _updateScorePanel() {
    if (!mounted) return;
    setState(() {});
  }

  /// Show results box
  void showResultsBox() {
    if (!mounted) return;
    setState(() {
      showResults = true;
    });
  }

  /// Hide results box
  void hideResultsBox() {
    if (!mounted) return;
    setState(() {
      showResults = false;
    });
  }

  /// Handle touch down event
  void _onTouchDown(Offset position) {
    if (!thingsLoaded || engine == null) return;
    engine!.onDown(position.dx, position.dy);
  }

  /// Handle touch move event
  void _onTouchMove(Offset position, int pointerIndex) {
    if (!thingsLoaded || engine == null) return;
    engine!.onMove(position.dx, position.dy, pointerIndex);
  }

  /// Handle touch up event
  void _onTouchUp(Offset position, int pointerIndex, bool realUp) {
    if (!thingsLoaded || engine == null) return;
    engine!.onUp(position.dx, position.dy, pointerIndex, realUp);
  }

  /// Handle scale gesture start
  void _onScaleStart(double span) {
    if (!thingsLoaded || engine == null) return;
    
    _initialSpan = span;
    _isScaling = true;
    engine!.startScale();
  }

  /// Handle scale gesture update
  void _onScaleUpdate(double span) {
    if (!thingsLoaded || !_isScaling || engine == null) return;
    
    double scaleFactor = span / _initialSpan;
    engine!.onScale(scaleFactor);
  }

  /// Handle scale gesture end
  void _onScaleEnd() {
    if (!thingsLoaded || engine == null) return;
    
    _isScaling = false;
    engine!.stopScale();
  }

  /// Handle back button press
  Future<bool> _onBackPressed() async {
    if (engine == null) return false;
    
    if (hideShowStatus) {
      _hideButtons();
      return true;
    } else if (engine!.renderer.shootingMode && 
               !engine!.automatic &&
               !engine!.renderer.aboutToCancel &&
               !engine!.piecesMoving) {
      engine!.renderer.shootingMode = false;
      return true;
    } else if (showResults) {
      return true;
    } else {
      return false;
    }
  }

  /// Hide control buttons
  void _hideButtons() {
    setState(() {
      hideShowStatus = false;
    });
  }

  /// Show control buttons
  void _showButtons() {
    setState(() {
      hideShowStatus = true;
    });
  }

  /// Handle restart button click
  void _onClickRestart() {
    if (engine == null) return;
    if (gameConfig != null && gameConfig!.isPlayingNetwork) {
      _showToast("You can not restart a network game.");
      return;
    }
    _hideButtons();
    engine!.unsaveStop();
    engine!.start();
  }

  /// Handle new game button click
  void _onClickNew(bool showAd) {
    if (engine == null) return;
    engine!.unsavePieces();
    if (gameConfig != null) {
      gameConfig!.gameId = -1;
    }

    // Send network quit message if needed
    if (gameConfig != null && gameConfig!.isPlayingNetwork) {
      // Network cleanup would go here
    }

    if (showAd) {
      // Show ad then finish
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Handle next game button (in results)
  void _onClickNextGame() {
    if (engine == null) return;
    engine!.unsavePieces();

    // Swap players
    engine!.swapPlayers();

    // Restart game
    engine!.start();

    // Network communication if needed
    if (gameConfig != null && gameConfig!.isPlayingNetwork) {
      // Network restart would go here
    }

    hideResultsBox();
  }

  /// Handle new board button (in results)
  void _onClickNewBoard() {
    _onClickNew(true);
  }

  /// Show toast message
  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Build score panel widget
  Widget _buildScorePanel() {
    if (gameConfig == null || gameConfig!.hideScoreboard == 1) {
      return const SizedBox.shrink();
    }

    bool compact = gameConfig!.hideScoreboard == 2;
    
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Row(
          children: [
            // Player 1 score
            Expanded(
              child: _buildPlayerScore(0, compact),
            ),
            // Player 2 score
            Expanded(
              child: _buildPlayerScore(1, compact),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerScore(int playerIndex, bool compact) {
    if (engine == null) return const SizedBox.shrink();
    bool isCurrentPlayer = engine!.currentPlayer == playerIndex;
    String playerName = gameConfig!.getPlayerName(playerIndex);
    if (playerName.length > 7) {
      playerName = playerName.substring(0, 7);
    }

    Color backgroundColor = isCurrentPlayer
        ? (playerIndex == 0 ? Colors.white : Colors.black)
        : (playerIndex == 0 ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7));

    Color textColor = playerIndex == 0 ? Colors.black : Colors.white;

    return Container(
      height: compact ? 38 : 70,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: Colors.grey),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!compact)
            Text(
              playerName,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Whites/Blacks count
              Text(
                playerIndex == 0
                    ? '${engine!.pocketedWhites}'
                    : '${engine!.pocketedBlacks}',
                style: TextStyle(
                  color: textColor,
                  fontSize: compact ? 14 : 18,
                  fontWeight: FontWeight.bold,
                  decoration: (playerIndex == 0 && engine!.dueWhites > 0) ||
                          (playerIndex == 1 && engine!.dueBlacks > 0)
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              // Red queen indicator
              if (engine!.redPotState == 3 && playerIndex == 0)
                const Icon(Icons.circle, color: Colors.red, size: 16),
              if (engine!.redPotState == 13 && playerIndex == 1)
                const Icon(Icons.circle, color: Colors.red, size: 16),
              // Current player arrow
              if (isCurrentPlayer)
                Icon(
                  playerIndex == 0 ? Icons.arrow_left : Icons.arrow_right,
                  color: textColor,
                  size: 16,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build control buttons overlay
  Widget _buildControlButtons() {
    if (!hideShowStatus) {
      return Positioned(
        top: 80,
        right: 8,
        child: FloatingActionButton(
          mini: true,
          onPressed: _showButtons,
          child: const Icon(Icons.menu),
        ),
      );
    }

    return Positioned(
      top: 80,
      right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hide button
          FloatingActionButton(
            mini: true,
            heroTag: 'hide',
            onPressed: _hideButtons,
            child: const Icon(Icons.close),
          ),
          const SizedBox(height: 8),
          // Restart button
          FloatingActionButton(
            mini: true,
            heroTag: 'restart',
            onPressed: _onClickRestart,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 8),
          // New game button
          FloatingActionButton(
            mini: true,
            heroTag: 'new',
            onPressed: () => _onClickNew(false),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          // Settings button
          FloatingActionButton(
            mini: true,
            heroTag: 'settings',
            onPressed: () {
              // Settings dialog would go here
              _hideButtons();
            },
            child: const Icon(Icons.settings),
          ),
        ],
      ),
    );
  }

  /// Build results overlay
  Widget _buildResultsOverlay() {
    if (!showResults || engine == null) {
      return const SizedBox.shrink();
    }

    String winner = engine!.gameFinished == 1
        ? gameConfig!.getPlayerName(0)
        : gameConfig!.getPlayerName(1);

    int matches = gameConfig!.score1 + gameConfig!.score2;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Game Finished!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  '$winner won the game.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                Text(
                  'Results of the board: ($matches ${matches == 1 ? "game" : "games"})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                _buildScoreRow(0),
                const SizedBox(height: 8),
                _buildScoreRow(1),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _onClickNextGame,
                      child: const Text('Next Game'),
                    ),
                    ElevatedButton(
                      onPressed: _onClickNewBoard,
                      child: const Text('New Board'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreRow(int playerIndex) {
    String name = gameConfig!.getPlayerName(playerIndex);
    int score = playerIndex == 0 ? gameConfig!.score1 : gameConfig!.score2;
    int otherScore = playerIndex == 0 ? gameConfig!.score2 : gameConfig!.score1;

    bool leads = score > otherScore;
    bool ties = score == otherScore;

    String suffix = leads ? ' (leads)' : (ties ? ' (ties)' : '');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$name$suffix',
          style: TextStyle(
            fontWeight: leads ? FontWeight.bold : FontWeight.normal,
            fontStyle: !leads && !ties ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        Text(
          '$score',
          style: TextStyle(
            fontWeight: leads ? FontWeight.bold : FontWeight.normal,
            fontStyle: !leads && !ties ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize game on first build
    if (!thingsLoaded) {
      Future.microtask(() => _onResume());
    }

    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Carrom 3D'),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              bool shouldPop = !await _onBackPressed();
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: !thingsLoaded
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  // Game canvas
                  Listener(
                    onPointerDown: (event) {
                      _pointerCount++;
                      if (_pointerCount == 1) {
                        _onTouchDown(event.localPosition);
                      }
                    },
                    onPointerMove: (event) {
                      if (_pointerCount == 1 || gameRenderer.readyToShoot) {
                        _onTouchMove(event.localPosition, 0);
                      } else if (_pointerCount == 2 && 
                                 gameRenderer.readyToShoot) {
                        // Second pointer in shooting mode
                        _onTouchMove(event.localPosition, 1);
                      } else if (_pointerCount >= 2 && 
                                 (!gameRenderer.readyToShoot || (engine?.automatic ?? false))) {
                        // Scale gesture
                        double span = _calculatePointerSpan(event);
                        if (_isScaling) {
                          _onScaleUpdate(span);
                        } else {
                          _onScaleStart(span);
                        }
                      }
                    },
                    onPointerUp: (event) {
                      if (_pointerCount == 1) {
                        _onTouchUp(event.localPosition, 0, true);
                      } else if (_pointerCount == 2 && gameRenderer.readyToShoot) {
                        _onTouchUp(event.localPosition, 1, true);
                      }
                      
                      _pointerCount--;
                      
                      if (_pointerCount == 0 && _isScaling) {
                        _onScaleEnd();
                      }
                    },
                    child: SizedBox.expand(
                      child: CustomPaint(
                        painter: GamePainter(gameRenderer),
                      ),
                    ),
                  ),

                  // Score panel
                  if (thingsLoaded) _buildScorePanel(),

                  // Control buttons
                  if (thingsLoaded) _buildControlButtons(),

                  // Results overlay
                  if (thingsLoaded) _buildResultsOverlay(),
                ],
              ),
      ),
    );
  }

  /// Calculate span between two pointers for scale gesture
  double _calculatePointerSpan(PointerEvent event) {
    // Simplified - would need to track multiple pointers properly
    // For now, use a placeholder
    return 100.0;
  }
}

/// Custom painter that uses GameRenderer to draw the game
class GamePainter extends CustomPainter {
  final GameRenderer renderer;

  GamePainter(this.renderer);

  @override
  void paint(Canvas canvas, Size size) {
    // Update surface size
    if (renderer.screenWidth != size.width || renderer.screenHeight != size.height) {
      renderer.onSurfaceChanged(size.width, size.height);
    }

    // Render the frame
    renderer.onDrawFrame(canvas, size);
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;
}

/// Callbacks wrapper for GameFragment integration
class GameFragmentCallbacks extends GameFragment {
  final VoidCallback updateScorePanelCallback;
  final VoidCallback showResultsBoxCallback;
  final VoidCallback hideResultsBoxCallback;

  GameFragmentCallbacks({
    required this.updateScorePanelCallback,
    required this.showResultsBoxCallback,
    required this.hideResultsBoxCallback,
  });

  @override
  void updateScorePanel() {
    updateScorePanelCallback();
  }

  @override
  void showResultsBox() {
    showResultsBoxCallback();
  }

  @override
  void hideResultsBox() {
    hideResultsBoxCallback();
  }
  
  void updateScorePanelIndirect() {
    updateScorePanelCallback();
  }
}
