import 'dart:typed_data';
import 'game_renderer.dart';
import 'matrix_utils.dart' as matrix;
import 'mesh_data.dart';
import 'game_controller.dart';
import 'game_config.dart';

/// GameEngine - Full port of GameEngine.java
/// Handles game state management, player management, input handling, and more
class GameEngine {
  // Constants
  static const int MOUSE_MOVE_LIMIT = 3;
  static const double SIN30 = 0.5;
  static const double COS30 = 0.86602540378;
  static const int NETWORK_PLAYER_TYPE = 4;
  static const String DB_PIECES_KEY = "carromPieces";

  // Core references
  GameFragment? gameFragment;
  late GameRenderer renderer;
  GameController? controller;
  double density = 1.0;
  CarromDbAdapter? dbAdapter;
  GameConfig? gameConfig;
  SoundThread? soundThread;

  // Player management
  int currentPlayer = 0;
  late int playerCount;
  List<int> playerTypes = List.filled(4, 0);
  List<CarromPlayer?> autoPlayers = List.filled(4, null);
  NetworkPlayer? networkPlayer;

  // Game state flags
  bool shootingProgress = false;
  bool changeTurn = true;
  bool notPlayed = true;
  bool automatic = false;
  bool piecesMoving = false;
  bool strokeHitSomewhere = false;
  int gameFinished = 0;
  int breakAttempts = 3;

  // Scoring state
  int redPotState = 0; // 0=on board, 1=potted, 2=waiting covered, 3=covered white, 13=covered black
  int currentTurnWhites = 0;
  int currentTurnBlacks = 0;
  int dueWhites = 0;
  int dueBlacks = 0;
  int pocketedWhites = 0;
  int pocketedBlacks = 0;

  // Last played state per player
  List<double> lastPlayedDiskPosx = List.filled(4, 0.0);
  List<double> lastPlayedDiskPosy = List.filled(4, 0.0);
  List<double> lastPlayedCameraAnglex = List.filled(4, -30.0);
  List<double> lastPlayedCameraAngley = List.filled(4, 0.0);
  List<double> lastPlayedCameraScale = List.filled(4, 1.0);
  List<double> lastPlayedCameraDisp = List.filled(4, 0.0);
  double lastLandedDiskX = 0;
  double lastLandedDiskY = 0;

  // Speed arrays for physics
  List<double> speedx = List.filled(20, 0.0);
  List<double> speedy = List.filled(20, 0.0);

  // Camera control
  bool fixCamera = true;
  int fixCameraSide = 0;

  // Touch/input state
  double startX = 0;
  double startY = 0;
  double diskStartX = 0;
  double diskStartY = 0;
  double diskAbsX = 0;
  double diskAbsY = 0;
  bool moving = false;
  bool startMoving = false;
  double diffX = 0;
  double diffY = 0;
  double currentX = 0;
  double currentY = 0;
  double diskCurrentX = 0;
  double diskCurrentY = 0;

  // Disk touch state
  bool diskTouched = false;
  bool diskMoving = false;
  int doubleTapState = 0;
  int timeStamp = 0;
  bool middleTouched = false;
  bool rotateTouched = false;
  bool rightFromMiddle = false;

  // Board tap state
  int boardDoubleTapState = 0;
  int boardTimestamp = 0;
  double boardTapx = 0;
  double boardTapy = 0;

  // Placing disk
  bool placingDisk = false;
  double placingDiskx = 0;
  double placingDisky = 0;

  // Scaling
  double scaleFactor = 0;
  bool scaling = false;
  double lastScaleFactor = 1;

  // World coordinate conversion matrices
  Float32List modelMatrix = Float32List(16);
  Float32List invertedMatrix = Float32List(16);
  Float32List transformMatrix = Float32List(16);
  Float32List normalizedInPoint = Float32List(4);
  Float32List outPoint = Float32List(4);
  double rayX = 0;
  double rayY = 0;
  double rayZ = 0;

  // UI display helpers
  late GameFinishDisplay finishDisplay;
  late ScoreUpdater scoreUpdater;
  late ToastDisplay toastDisplay;

  // Constructor
  GameEngine(
    this.gameFragment,
    this.renderer,
    this.density,
    this.dbAdapter,
    this.gameConfig,
    this.soundThread,
  ) {
    finishDisplay = GameFinishDisplay(this);
    scoreUpdater = ScoreUpdater(this);
    toastDisplay = ToastDisplay(this);
    
    // Initialize from config
    if (gameConfig != null) {
      playerCount = gameConfig!.playerCount;
    } else {
      playerCount = 2;
    }
    
    // Initialize identity matrix
    matrix.MatrixUtils.setIdentity(modelMatrix);
  }

  /// Start the game
  void start() {
    if (controller != null) {
      controller!.stop();
      // Wait for controller to finish (Dart doesn't have join, but we can use Future)
    }
    moving = false;
    scaling = false;

    initBeforeLoad(true);
    loadPieces();
    controller = GameController(this);

    initAfterLoad(true);
    renderer.updateEye(0, 0, 0, 0);

    controller!.start();
  }

  /// Initialize values before loading pieces
  void initBeforeLoad(bool withView) {
    if (withView) {
      renderer.initView();
    }
    initValues();
    currentPlayer = 0;
    shootingProgress = false;
    renderer.shootingMode = false;
    notPlayed = true;
    renderer.showArcs = false;
    changeTurn = true;
    redPotState = 0;
    currentTurnBlacks = 0;
    currentTurnWhites = 0;
    dueBlacks = 0;
    dueWhites = 0;
    placingDisk = false;
    strokeHitSomewhere = false;
    breakAttempts = 3;
    gameFinished = 0;
    renderer.shootingX = 0;
    renderer.shootingY = 0;
    fixCamera = true;
    piecesMoving = false;

    for (int i = 0; i < 20; i++) {
      speedx[i] = 0;
      speedy[i] = 0;
      renderer.presents[i] = MeshData.HOLE_ANI_LIMIT;
    }

    if (playerCount == 4) {
      lastPlayedDiskPosx[0] = 0;
      lastPlayedDiskPosy[0] = -MeshData.DISK_START_DIST;
      lastPlayedDiskPosx[1] = MeshData.DISK_START_DIST;
      lastPlayedDiskPosy[1] = 0;
      lastPlayedDiskPosx[2] = 0;
      lastPlayedDiskPosy[2] = MeshData.DISK_START_DIST;
      lastPlayedDiskPosx[3] = -MeshData.DISK_START_DIST;
      lastPlayedDiskPosy[3] = 0;
    } else {
      // 2 player setup
      lastPlayedDiskPosx[0] = 0;
      lastPlayedDiskPosy[0] = -MeshData.DISK_START_DIST;
      lastPlayedDiskPosx[1] = 0;
      lastPlayedDiskPosy[1] = MeshData.DISK_START_DIST;

      // Setting the camera
      lastPlayedCameraAnglex[0] = -30;
      lastPlayedCameraAngley[0] = 0;
      lastPlayedCameraScale[0] = 1;
      lastPlayedCameraDisp[0] = 0;

      lastPlayedCameraAnglex[1] = 30;
      lastPlayedCameraAngley[1] = 0;
      lastPlayedCameraScale[1] = 1;
      lastPlayedCameraDisp[1] = 0;
    }
  }

  /// Initialize after loading pieces
  void initAfterLoad(bool withConfigUpdates) {
    if (gameConfig != null) {
      renderer.arrowWidth = gameConfig!.guidingWidth / 1000.0;
    }

    pocketedWhites = 0;
    for (int i = 2; i < 11; i++) {
      if (renderer.presents[i] == 0) {
        pocketedWhites++;
      }
    }

    pocketedBlacks = 0;
    for (int i = 11; i < 20; i++) {
      if (renderer.presents[i] == 0) {
        pocketedBlacks++;
      }
    }

    for (int i = 0; i < 20; i++) {
      if (renderer.presents[i] == MeshData.HOLE_ANI_LIMIT) {
        double speedsq = speedx[i] * speedx[i] + speedy[i] * speedy[i];
        if (speedsq > 1e-3) {
          piecesMoving = true;
          break;
        }
      }
    }

    updateScorePanel();

    if (gameFinished != 0) {
      showGameFinished(false);
    }

    if (!withConfigUpdates || gameConfig == null) {
      return;
    }

    for (int i = 0; i < playerCount; i++) {
      playerTypes[i] = gameConfig!.getPlayerType(i);

      if (playerTypes[i] == NETWORK_PLAYER_TYPE) {
        networkPlayer = NetworkPlayer(this, i, playerTypes[i]);
        autoPlayers[i] = networkPlayer;
      } else if (playerTypes[i] > 0 && playerTypes[i] < NETWORK_PLAYER_TYPE) {
        autoPlayers[i] = AutoPlayer(this, i, playerTypes[i]);
      } else {
        autoPlayers[i] = null;
      }
    }
    gameConfig!.gameInProgress = true;

    updateAutoPlayerChange();

    fixCamera = gameConfig!.cameraFixability;
    // In fix camera, we assume only two players exist
    if (playerTypes[0] == 0 && playerTypes[1] == 0) {
      fixCamera = false;
    } else if (playerTypes[1] == 0) {
      fixCameraSide = 1;
    } else {
      fixCameraSide = 0;
    }

    if (gameConfig!.tableTop) {
      fixCamera = true;
      fixCameraSide = gameConfig!.frontPlayer;
      lastPlayedCameraAnglex[0] = 0;
      lastPlayedCameraAnglex[1] = 0;
    }

    // If the network is on, fix camera is always the current side
    if (gameConfig!.isPlayingNetwork) {
      if (playerTypes[0] == NETWORK_PLAYER_TYPE) {
        fixCameraSide = 1;
      } else if (playerTypes[1] == NETWORK_PLAYER_TYPE) {
        fixCameraSide = 0;
      }
    }
    renderer.showArrows = !gameConfig!.hideArrow;
  }

  /// Update automatic player flag based on current player
  void updateAutoPlayerChange() {
    if (playerTypes[currentPlayer] > 0) {
      automatic = true;
    } else {
      automatic = false;
    }
  }

  /// Stop the game
  void stop() {
    if (controller != null) {
      controller!.stop();
    }
    savePieces();
    finishDisplay.hide();
    controller = null;
  }

  /// Stop without saving
  void unsaveStop() {
    if (controller != null) {
      controller!.stop();
    }
    unsavePieces();
    finishDisplay.hide();
    controller = null;
  }

  /// Initialize all input/state values
  void initValues() {
    diskTouched = false;
    diskMoving = false;
    doubleTapState = 0;
    timeStamp = 0;
    middleTouched = false;
    rotateTouched = false;
    rightFromMiddle = false;

    boardDoubleTapState = 0;
    boardTimestamp = 0;
    boardTapx = 0;
    boardTapy = 0;

    placingDisk = false;
    scaleFactor = 0;
    scaling = false;
    lastScaleFactor = 1;

    breakAttempts = 3;
    strokeHitSomewhere = false;
    gameFinished = 0;
    automatic = false;
    piecesMoving = false;

    currentPlayer = 0;
    playerCount = 2;

    renderer.readyToShoot = false;
    renderer.showArrows = true;
  }

  /// Handle touch down event
  void onDown(double x, double y) {
    getWorldCoords(x, y);
    
    // Check if touching the disk/striker
    if ((!renderer.readyToShoot || automatic) &&
        (rayX - renderer.xposPieces[0]) * (rayX - renderer.xposPieces[0]) +
                (rayY - renderer.yposPieces[0]) * (rayY - renderer.yposPieces[0]) <=
            8 * MeshData.RADIUS * MeshData.RADIUS * 
            MeshData.DISK_RADIUS_FACTOR * MeshData.DISK_RADIUS_FACTOR) {
      diskStartX = rayX;
      diskStartY = rayY;
      diskAbsX = x;
      diskAbsY = y;

      if (!automatic) {
        diskTouched = true;
      }

      // Double tap on the disk
      if (doubleTapState == 2) {
        int currentTime = DateTime.now().millisecondsSinceEpoch;
        if (currentTime - timeStamp < 500) {
          doubleTapState = 3;
        } else {
          doubleTapState = 0;
        }
      }
      if (doubleTapState == 0) {
        timeStamp = DateTime.now().millisecondsSinceEpoch;
        doubleTapState = 1;
      }
    } else {
      // Double tap on the board
      if (boardDoubleTapState == 2) {
        int currentTime = DateTime.now().millisecondsSinceEpoch;
        if (currentTime - boardTimestamp < 500 &&
            (rayX - boardTapx) * (rayX - boardTapx) +
                    (rayY - boardTapy) * (rayY - boardTapy) <
                0.1) {
          boardDoubleTapState = 3;
        } else {
          boardDoubleTapState = 0;
        }
      }
      if (boardDoubleTapState == 0) {
        boardTapx = rayX;
        boardTapy = rayY;
        boardTimestamp = DateTime.now().millisecondsSinceEpoch;
        boardDoubleTapState = 1;
      }

      if (boardDoubleTapState != 3) {
        double distFromMiddle = rayX * rayX + rayY * rayY;
        if (distFromMiddle <= 4.5 * 4.5 * MeshData.RADIUS * MeshData.RADIUS) {
          middleTouched = true;
        } else if (notPlayed &&
            distFromMiddle <= 8.5 * 8.5 * MeshData.RADIUS * MeshData.RADIUS) {
          if (rayX > 0) {
            rightFromMiddle = true;
          } else {
            rightFromMiddle = false;
          }
          rotateTouched = true;
        }
        startX = x;
        startY = y;
        startMoving = true;
      }
    }
  }

  /// Handle touch move event
  void onMove(double x, double y, int i) {
    if (((i == 0 && !renderer.readyToShoot) ||
            (i == 1 && renderer.readyToShoot) ||
            automatic) &&
        startMoving &&
        ((x - startX).abs() > MOUSE_MOVE_LIMIT * density ||
            (y - startY).abs() > MOUSE_MOVE_LIMIT * density)) {
      diffX = x - startX;
      diffY = y - startY;
      currentX = x;
      currentY = y;
      if (!moving) {
        moving = true;
      }
      if (rotateTouched) {
        getWorldCoords(x, y);
        if (rayX > 0) {
          rightFromMiddle = true;
        } else {
          rightFromMiddle = false;
        }
      }
    }
    if (i == 0 && diskTouched) {
      getWorldCoords(x, y);
      diskCurrentX = rayX;
      diskCurrentY = rayY;
      if (!automatic) {
        diskMoving = true;
      }
    }
  }

  /// Handle touch up event
  void onUp(double x, double y, int i, bool realUp) {
    if (startMoving) {
      if (i == 0 && !moving && !diskTouched && !renderer.shootingMode && realUp) {
        getWorldCoords(x, y);
        placingDiskx = rayX;
        placingDisky = rayY;
        placingDisk = true;
      }

      startMoving = false;
      moving = false;
      middleTouched = false;
      rotateTouched = false;
    }
    if (i == 0 && diskTouched) {
      diskTouched = false;
      diskMoving = false;

      if (doubleTapState == 1) {
        int currentTime = DateTime.now().millisecondsSinceEpoch;
        if (currentTime - timeStamp < 500) {
          doubleTapState = 2;
        } else {
          doubleTapState = 0;
        }
      }
    }

    if (boardDoubleTapState == 1) {
      int currentTime = DateTime.now().millisecondsSinceEpoch;
      if (currentTime - boardTimestamp < 500) {
        boardDoubleTapState = 2;
      } else {
        boardDoubleTapState = 0;
      }
    }
  }

  /// Start scaling gesture
  void startScale() {
    scaleFactor = 1;
    lastScaleFactor = 1;
    scaling = true;
  }

  /// Handle scale gesture
  void onScale(double factor) {
    if ((lastScaleFactor < 1 && factor > 1) || (lastScaleFactor > 1 && factor < 1)) {
      // To avoid noise
      lastScaleFactor = 1;
    }
    scaleFactor = factor;
    lastScaleFactor = factor;
  }

  /// Stop scaling gesture
  void stopScale() {
    scaling = false;
  }

  /// Reset pieces to initial positions
  void resetPieces() {
    List<double> xpos = renderer.xposPieces;
    List<double> ypos = renderer.yposPieces;

    int i = 0;
    // Disk/striker
    xpos[i] = 0;
    ypos[i++] = -MeshData.DISK_START_DIST;

    // Red queen
    xpos[i] = ypos[i++] = 0;

    double aradius = MeshData.RADIUS;

    // White pieces (9 pieces)
    xpos[i] = 2 * aradius;
    ypos[i++] = 0;
    xpos[i] = 4 * aradius;
    ypos[i++] = 0;
    xpos[i] = -2 * aradius * SIN30;
    ypos[i++] = 2 * aradius * COS30;
    xpos[i] = -4 * aradius * SIN30;
    ypos[i++] = 4 * aradius * COS30;
    xpos[i] = -2 * aradius * SIN30;
    ypos[i++] = -2 * aradius * COS30;
    xpos[i] = -4 * aradius * SIN30;
    ypos[i++] = -4 * aradius * COS30;
    xpos[i] = -4 * aradius;
    ypos[i++] = 0;
    xpos[i] = 4 * aradius * SIN30;
    ypos[i++] = -4 * aradius * COS30;
    xpos[i] = 4 * aradius * SIN30;
    ypos[i++] = 4 * aradius * COS30;

    // Black pieces (9 pieces)
    xpos[i] = 0;
    ypos[i++] = 4 * aradius * COS30;
    xpos[i] = 2 * aradius * SIN30;
    ypos[i++] = 2 * aradius * COS30;
    xpos[i] = 3 * aradius;
    ypos[i++] = 2 * aradius * COS30;

    xpos[i] = 0;
    ypos[i++] = -4 * aradius * COS30;
    xpos[i] = 2 * aradius * SIN30;
    ypos[i++] = -2 * aradius * COS30;
    xpos[i] = 3 * aradius;
    ypos[i++] = -2 * aradius * COS30;

    xpos[i] = -3 * aradius;
    ypos[i++] = 2 * aradius * COS30;
    xpos[i] = -2 * aradius;
    ypos[i++] = 0;
    xpos[i] = -3 * aradius;
    ypos[i++] = -2 * aradius * COS30;
  }

  /// Convert screen coordinates to world coordinates
  void getWorldCoords(double x, double y) {
    rayX = x;
    rayY = y;
    rayZ = 0;
    unproject();

    double x1 = rayX;
    double y1 = rayY;
    double z1 = rayZ;

    rayX = x;
    rayY = y;
    rayZ = 1;
    unproject();

    double x2 = rayX;
    double y2 = rayY;
    double z2 = rayZ;

    rayY = MeshData.BOARD_TOP;
    rayX = (rayY - y1) / (y2 - y1) * (x2 - x1) + x1;
    rayZ = (rayY - y1) / (y2 - y1) * (z2 - z1) + z1;

    rayY = -rayZ;
  }

  /// Unproject screen coordinates to world space
  void unproject() {
    // Screen dimensions
    double screenW = renderer.screenWidth;
    double screenH = renderer.screenHeight;
    
    // Invert y coordinate (Android uses top-left, OpenGL uses bottom-left)
    double oglTouchY = screenH - rayY;

    // Transform screen point to clip space in OpenGL (-1, 1)
    normalizedInPoint[0] = rayX * 2.0 / screenW - 1.0;
    normalizedInPoint[1] = oglTouchY * 2.0 / screenH - 1.0;
    normalizedInPoint[2] = rayZ * 2.0 - 1.0;
    normalizedInPoint[3] = 1.0;

    // Obtain the transform matrix and then the inverse
    matrix.MatrixUtils.multiplyMM(transformMatrix, renderer.viewMatrix, modelMatrix);
    matrix.MatrixUtils.multiplyMM(transformMatrix, renderer.projectionMatrix, renderer.viewMatrix);
    
    // Invert the transform matrix
    if (!matrix.MatrixUtils.invertM(invertedMatrix, transformMatrix)) {
      print("ERROR: Matrix inversion failed in unproject");
      return;
    }

    // Apply the inverse to the point in clip space
    matrix.MatrixUtils.multiplyMV(outPoint, invertedMatrix, normalizedInPoint);

    if (outPoint[3] == 0.0) {
      print("ERROR: World coords division by zero!");
      return;
    }

    // Divide by w component to get actual position
    rayX = outPoint[0] / outPoint[3];
    rayY = outPoint[1] / outPoint[3];
    rayZ = outPoint[2] / outPoint[3];
  }

  /// Load pieces from database
  void loadPieces() {
    String pieces = "";
    try {
      if (dbAdapter != null) {
        pieces = dbAdapter!.getValue(DB_PIECES_KEY);
      }
    } catch (e) {
      // Ignore errors
    }

    if (pieces.isEmpty || pieces == "0") {
      resetPieces();
      return;
    }

    List<String> items = pieces.split(',');

    if (items.length != 139) {
      resetPieces();
      return;
    }

    int j = 1;
    for (int i = 0; i < 20; i++) {
      renderer.xposPieces[i] = double.parse(items[j++]);
      renderer.yposPieces[i] = double.parse(items[j++]);
    }

    for (int i = 0; i < 20; i++) {
      speedx[i] = double.parse(items[j++]);
      speedy[i] = double.parse(items[j++]);
    }

    shootingProgress = items[j++] == "1";
    currentPlayer = int.parse(items[j++]);
    playerCount = int.parse(items[j++]);

    renderer.shootingMode = items[j++] == "1";

    for (int i = 0; i < 4; i++) {
      lastPlayedCameraAnglex[i] = double.parse(items[j++]);
      lastPlayedCameraAngley[i] = double.parse(items[j++]);
      lastPlayedCameraScale[i] = double.parse(items[j++]);
      lastPlayedCameraDisp[i] = double.parse(items[j++]);
    }
    notPlayed = items[j++] == "1";

    for (int i = 0; i < 4; i++) {
      lastPlayedDiskPosx[i] = double.parse(items[j++]);
      lastPlayedDiskPosy[i] = double.parse(items[j++]);
    }

    for (int i = 0; i < 20; i++) {
      renderer.presents[i] = int.parse(items[j++]);
    }

    changeTurn = items[j++] == "1";
    redPotState = int.parse(items[j++]);

    currentTurnWhites = int.parse(items[j++]);
    currentTurnBlacks = int.parse(items[j++]);
    dueWhites = int.parse(items[j++]);
    dueBlacks = int.parse(items[j++]);

    breakAttempts = int.parse(items[j++]);
    strokeHitSomewhere = items[j++] == "1";

    gameFinished = int.parse(items[j++]);
  }

  /// Save preprocessing before saving pieces
  void savePreprocessing() {
    lastPlayedCameraAnglex[currentPlayer] = renderer.xangle;
    lastPlayedCameraAngley[currentPlayer] = renderer.yangle;
    lastPlayedCameraScale[currentPlayer] = renderer.scale;
    lastPlayedCameraDisp[currentPlayer] = renderer.eyedisp;

    if (!renderer.shootingMode && diskMoving) {
      renderer.xposPieces[0] = lastLandedDiskX;
      renderer.yposPieces[0] = lastLandedDiskY;
    }
  }

  /// Save pieces to database
  void savePieces() {
    savePreprocessing();
    String pieces = "1";
    
    for (int i = 0; i < 20; i++) {
      pieces += ",${renderer.xposPieces[i]},${renderer.yposPieces[i]}";
    }

    for (int i = 0; i < 20; i++) {
      pieces += ",${speedx[i]},${speedy[i]}";
    }

    pieces += ",${shootingProgress ? "1" : "0"}";
    pieces += ",$currentPlayer,$playerCount";

    pieces += ",${renderer.shootingMode ? "1" : "0"}";

    for (int i = 0; i < 4; i++) {
      pieces += ",${lastPlayedCameraAnglex[i]}";
      pieces += ",${lastPlayedCameraAngley[i]}";
      pieces += ",${lastPlayedCameraScale[i]}";
      pieces += ",${lastPlayedCameraDisp[i]}";
    }
    pieces += ",${notPlayed ? "1" : "0"}";

    for (int i = 0; i < 4; i++) {
      pieces += ",${lastPlayedDiskPosx[i]}";
      pieces += ",${lastPlayedDiskPosy[i]}";
    }

    for (int i = 0; i < 20; i++) {
      pieces += ",${renderer.presents[i]}";
    }

    pieces += ",${changeTurn ? "1" : "0"}";
    pieces += ",$redPotState";

    pieces += ",$currentTurnWhites";
    pieces += ",$currentTurnBlacks";
    pieces += ",$dueWhites";
    pieces += ",$dueBlacks";

    pieces += ",$breakAttempts";
    pieces += ",${strokeHitSomewhere ? "1" : "0"}";
    pieces += ",$gameFinished";

    if (dbAdapter != null) {
      dbAdapter!.addValue(DB_PIECES_KEY, pieces);
    }
  }

  /// Clear saved pieces from database
  void unsavePieces() {
    if (dbAdapter != null) {
      dbAdapter!.addValue(DB_PIECES_KEY, "0");
    }
    if (gameConfig != null) {
      gameConfig!.gameInProgress = false;
    }
  }

  /// Update score panel (calls UI thread)
  void updateScorePanel() {
    if (gameFragment != null) {
      // In Flutter, we don't need runOnUiThread, but we can use callbacks
      scoreUpdater.run();
    }
  }

  /// Show a toast message
  void showToast(String toast) {
    toastDisplay.setText(toast);
    if (gameFragment != null) {
      toastDisplay.run();
    }
  }

  /// Show game finished dialog
  void showGameFinished(bool uiThread) {
    if (gameConfig == null) return;

    String winner = "";
    int playerType = 0;
    if (gameFinished == 1) {
      winner = gameConfig!.getPlayerName(0);
      playerType = playerTypes[0];
    } else {
      winner = gameConfig!.getPlayerName(1);
      playerType = playerTypes[1];
    }

    finishDisplay.setWinner(winner, playerType);
    finishDisplay.run();

    gameConfig!.gameInProgress = false;
  }

  /// Swap player positions
  void swapPlayers() {
    if (gameConfig == null) return;

    int player1 = gameConfig!.player[0];
    gameConfig!.player[0] = gameConfig!.player[1];
    gameConfig!.player[1] = player1;

    int score1 = gameConfig!.score1;
    gameConfig!.score1 = gameConfig!.score2;
    gameConfig!.score2 = score1;

    // Swap the front player as well
    if (gameConfig!.frontPlayer == 0) {
      gameConfig!.frontPlayer = 1;
    } else {
      gameConfig!.frontPlayer = 0;
    }
  }

  /// Record game finished to database
  void recordGameFinished() {
    if (gameConfig == null || gameFragment == null) return;

    // Handle the board win/loss
    if (gameConfig!.gameId == -1) {
      gameConfig!.score1 = 0;
      gameConfig!.score2 = 0;
    }

    if (gameFinished == 1) {
      gameConfig!.score1++;
    } else {
      gameConfig!.score2++;
    }

    // Save the current entry to the database
    String name1 = gameConfig!.getPlayerName(0);
    String name2 = gameConfig!.getPlayerName(1);
    int score1 = gameConfig!.score1;
    int score2 = gameConfig!.score2;

    if (score2 > score1) {
      // Swap the names
      score1 = gameConfig!.score2;
      score2 = gameConfig!.score1;
      name1 = gameConfig!.getPlayerName(1);
      name2 = gameConfig!.getPlayerName(0);
    }

    try {
      DateTime date = DateTime.now();
      if (gameConfig!.gameId == -1) {
        gameFragment!.scoreDbAdapter?.createEntry(date, date, name1, name2, score1, score2);
        // Get the value from the database
        gameConfig!.gameId = gameFragment!.scoreDbAdapter?.getMaxId() ?? -1;
      } else {
        gameFragment!.scoreDbAdapter?.updateKey(
            gameConfig!.gameId, date, name1, name2, score1, score2);
      }
    } catch (e) {
      showToast("Failed to save the game board record...");
    }

    int team1 = gameConfig!.player[0];
    int team2 = gameConfig!.player[1];
    if (team1 == team2) {
      return;
    }
    
    bool team1won = false;
    int red = 2;
    if (gameFinished == 1) {
      team1won = true;
    } else if (gameFinished == 2) {
      team1won = false;
    }
    if (redPotState == 3) {
      red = 0;
    } else if (redPotState == 13) {
      red = 1;
    }
    gameConfig!.addGame(team1, team2, team1won, red);
  }

  /// Create a remote dump string for network play
  String remoteDump() {
    String pieces = "0";
    pieces += "#$currentPlayer";
    pieces += ",${notPlayed ? "1" : "0"}";
    pieces += ",$redPotState";

    pieces += ",$dueWhites";
    pieces += ",$dueBlacks";

    pieces += ",$breakAttempts";
    pieces += ",$gameFinished";

    for (int i = 0; i < 20; i++) {
      pieces += ",${renderer.xposPieces[i]},${renderer.yposPieces[i]},${renderer.presents[i]}";
    }

    return pieces;
  }

  /// Restore from remote dump (network play)
  void remoteRestore(String pieces) {
    List<String> items = pieces.split(',');
    int j = 0;

    currentPlayer = int.parse(items[j++]);
    notPlayed = items[j++] == "1";
    redPotState = int.parse(items[j++]);

    dueWhites = int.parse(items[j++]);
    dueBlacks = int.parse(items[j++]);

    breakAttempts = int.parse(items[j++]);
    gameFinished = int.parse(items[j++]);

    for (int i = 0; i < 20; i++) {
      renderer.xposPieces[i] = double.parse(items[j++]);
      renderer.yposPieces[i] = double.parse(items[j++]);
      renderer.presents[i] = int.parse(items[j++]);
    }
  }
}

/// Score updater helper
class ScoreUpdater {
  final GameEngine engine;

  ScoreUpdater(this.engine);

  void run() {
    try {
      engine.pocketedWhites = 0;
      for (int i = 2; i < 11; i++) {
        if (engine.renderer.presents[i] == 0) {
          engine.pocketedWhites++;
        }
      }

      engine.pocketedBlacks = 0;
      for (int i = 11; i < 20; i++) {
        if (engine.renderer.presents[i] == 0) {
          engine.pocketedBlacks++;
        }
      }
      
      if (engine.gameFragment != null) {
        engine.gameFragment!.updateScorePanel();
      }
    } catch (e) {
      // Ignore errors
    }
  }
}

/// Toast display helper
class ToastDisplay {
  final GameEngine engine;
  String text = "";

  ToastDisplay(this.engine);

  void setText(String text) {
    this.text = text;
  }

  void run() {
    try {
      if (text.isNotEmpty) {
        print('Toast: $text');
        // In Flutter, we'd use a SnackBar or similar
      }
    } catch (e) {
      // Ignore errors
    }
  }
}

/// Game finish display helper
class GameFinishDisplay {
  final GameEngine engine;
  String winner = "";
  int type = 0;

  GameFinishDisplay(this.engine);

  void setWinner(String winner, int type) {
    this.winner = winner;
    this.type = type;
  }

  void hide() {
    try {
      if (engine.gameFragment != null) {
        engine.gameFragment!.hideResultsBox();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  void run() {
    try {
      if (engine.gameFragment == null || engine.gameConfig == null) return;

      engine.gameFragment!.showResultsBox();

      String msg = "$winner won the game.";
      if (type == 0) {
        msg += " Congratulations!!!";
      }

      print("Game Finished: $msg");

      GameConfig gameConfig = engine.gameConfig!;
      int matches = gameConfig.score1 + gameConfig.score2;
      String resultsText;
      if (matches == 1) {
        resultsText = "Results of the board: (1 game)";
      } else {
        resultsText = "Results of the board: ($matches games)";
      }
      print(resultsText);

      if (gameConfig.score1 > gameConfig.score2) {
        print("${gameConfig.getPlayerName(0)} (leads): ${gameConfig.score1}");
        print("${gameConfig.getPlayerName(1)}: ${gameConfig.score2}");
      } else if (gameConfig.score2 > gameConfig.score1) {
        print("${gameConfig.getPlayerName(1)} (leads): ${gameConfig.score2}");
        print("${gameConfig.getPlayerName(0)}: ${gameConfig.score1}");
      } else {
        print("${gameConfig.getPlayerName(0)} (ties): ${gameConfig.score1}");
        print("${gameConfig.getPlayerName(1)} (ties): ${gameConfig.score2}");
      }
    } catch (e) {
      // Ignore errors
    }
  }
}

/// Base class for player (human or AI)
abstract class CarromPlayer {
  final GameEngine engine;
  final int playerIndex;
  final int playerType;

  CarromPlayer(this.engine, this.playerIndex, this.playerType);

  void strategize();
  void reset();
}

/// Auto player (AI)
class AutoPlayer extends CarromPlayer {
  AutoPlayer(GameEngine engine, int playerIndex, int playerType)
      : super(engine, playerIndex, playerType);

  @override
  void strategize() {
    // AI logic to be implemented
    print("AutoPlayer $playerIndex strategizing...");
  }

  @override
  void reset() {
    // Reset AI state
  }
}

/// Network player
class NetworkPlayer extends CarromPlayer {
  NetworkPlayer(GameEngine engine, int playerIndex, int playerType)
      : super(engine, playerIndex, playerType);

  @override
  void strategize() {
    // Network player logic
    print("NetworkPlayer $playerIndex waiting for remote input...");
  }

  @override
  void reset() {
    // Reset network state
  }
}

// GameConfig now imported from game_config.dart

/// Game fragment (UI integration point)
class GameFragment {
  bool controllerReadyToGo = true;
  ScoreDbAdapter? scoreDbAdapter;

  void updateScorePanel() {
    // Update UI score panel
    print("Score panel updated");
  }

  void sendOutMessage(String message) {
    // Send network message
  }

  void closeSockets() {
    // Close network connections
  }

  void pingServer() {
    // Send ping
  }

  void showResultsBox() {
    // Show results dialog
  }

  void hideResultsBox() {
    // Hide results dialog
  }
}

/// Sound thread for playing sound effects
class SoundThread {
  bool done = false;

  void playD(double speed) {
    // Play striker shoot sound
  }

  void playDhole(double speed) {
    // Play striker in hole sound
  }

  void playPhole(double speed) {
    // Play piece in hole sound
  }

  void playDwall(double speed) {
    // Play striker hit wall sound
  }

  void playPwall(double speed) {
    // Play piece hit wall sound
  }

  void playDpiece(double speed, double factor) {
    // Play piece collision sound
  }
}

/// Database adapter for saving/loading game state
class CarromDbAdapter {
  void open() {
    // Open database connection
  }

  void close() {
    // Close database connection
  }

  String getValue(String key) {
    // Load from database
    return "";
  }

  void addValue(String key, String value) {
    // Save to database
  }
}

/// Score database adapter
class ScoreDbAdapter {
  void open() {
    // Open database connection
  }

  void close() {
    // Close database connection
  }

  void createEntry(DateTime date1, DateTime date2, String name1, String name2,
      int score1, int score2) {
    // Create database entry
  }

  void updateKey(
      int id, DateTime date, String name1, String name2, int score1, int score2) {
    // Update database entry
  }

  int getMaxId() {
    // Get max ID from database
    return 0;
  }
}
