import 'dart:async';
import 'dart:math' as math;
import 'game_renderer.dart';
import 'game_engine.dart';
import 'mesh_data.dart';

/// GameController - Direct port of GameController.java
/// Manages game physics, collisions, and game state
class GameController {
  late GameEngine engine;
  bool done = false;
  late GameRenderer renderer;
  late List<double> speedx;
  late List<double> speedy;
  late List<double> newspeedx;
  late List<double> newspeedy;
  late List<double> newposx;
  late List<double> newposy;
  late List<double> lastPlayedDiskPosx;
  late List<double> lastPlayedDiskPosy;
  late List<bool> lastPlayedCameraRotateXFirst;
  late List<double> lastPlayedCameraAnglex;
  late List<double> lastPlayedCameraAngley;
  late List<double> lastPlayedCameraScale;
  late List<double> lastPlayedCameraDisp;
  late List<double> lastPlayedCameraUpZ;
  late List<double> lastPlayedCameraUpY;
  late List<int> sortedItems;
  late List<double> sortedDists;
  bool trackFixedCamera = false;
  bool diskEscapedThreshold = false;

  double lastHighShootingX = 0;
  double lastHighShootingY = 0;

  static const int SLEEP_TIME = 20;
  static const double DISK_FRICTION = 0.001;
  static const double PIECES_FRICTION = 0.0018;
  static const double WEIGHT_FACTOR = 0.4;
  static const double HIT_ENERGY_LOSS = 0.00001;
  static const double BORDER_ENERGY_LOSS_SQR = 0.01;
  static const double SHOOT_DIST_SPEED_FACTOR = 0.33;
  final double PIECES_ROTATE_ANGLE = 2 * math.pi / 180;

  final double MIN_SPEED_AT_HOLE = PIECES_FRICTION * 2;

  // Network related
  final int NETWORK_SEND_LIMIT = 1000 ~/ SLEEP_TIME;
  final int NETWORK_PING_SEND_LIMIT = 1000 ~/ SLEEP_TIME;
  int networkCounter = 0;
  int networkPingCounter = 0;
  bool nt_rotatedPieces = false;
  bool nt_diskMoved = false;
  bool nt_shootingMoved = false;
  bool trackTableTop = false;
  int network_ping_send_limit = 0;

  GameController(this.engine) {
    renderer = engine.renderer;
    speedx = engine.speedx;
    speedy = engine.speedy;
    newspeedx = List.filled(20, 0.0);
    newspeedy = List.filled(20, 0.0);
    newposx = List.filled(20, 0.0);
    newposy = List.filled(20, 0.0);

    lastPlayedDiskPosx = engine.lastPlayedDiskPosx;
    lastPlayedDiskPosy = engine.lastPlayedDiskPosy;

    lastPlayedCameraAnglex = engine.lastPlayedCameraAnglex;
    lastPlayedCameraAngley = engine.lastPlayedCameraAngley;
    lastPlayedCameraScale = engine.lastPlayedCameraScale;
    lastPlayedCameraDisp = engine.lastPlayedCameraDisp;

    lastPlayedCameraRotateXFirst = List.filled(4, false);
    lastPlayedCameraUpZ = List.filled(4, 0.0);
    lastPlayedCameraUpY = List.filled(4, 0.0);

    sortedItems = List.filled(20, 0);
    sortedItems[0] = 0;
    sortedDists = List.filled(20, 0.0);
    sortedDists[0] = 0;

    network_ping_send_limit = NETWORK_PING_SEND_LIMIT;
  }

  void stop() {
    done = true;
  }

  /// Start the controller (launches the run loop)
  void start() {
    run();
  }

  Future<void> run() async {
    int diskMoveMultiplier = 1;
    int lastDiskChanged = 0;
    bool changingPlayer = false;
    int changingPlayerIndex = 0;
    const int changingPlayerLimit = 22;

    for (int i = 0; i < 20; i++) {
      newposx[i] = renderer.xposPieces[i];
      newposy[i] = renderer.yposPieces[i];
      renderer.zRaised[i] = false;
    }

    // Initialize last played poses
    if (engine.playerCount == 4) {
      // 4 player mode (not implemented)
    } else {
      // 2 player mode
      lastPlayedCameraRotateXFirst[0] = true;
      lastPlayedCameraUpZ[0] = -1.0;
      lastPlayedCameraUpY[0] = 0;

      lastPlayedCameraRotateXFirst[1] = true;
      lastPlayedCameraUpZ[1] = 1.0;
      lastPlayedCameraUpY[1] = 0;
    }

    renderer.aboutToCancel = false;
    engine.lastLandedDiskX = lastPlayedDiskPosx[engine.currentPlayer];
    engine.lastLandedDiskY = lastPlayedDiskPosy[engine.currentPlayer];

    lastCameraChangedDir = -1;
    trackFixedCamera = engine.fixCamera;
    adjustPlayerChange(false, true);
    bool diskJustMoved = false;
    diskEscapedThreshold = false;
    renderer.arrowReady = false;

    lastHighShootingX = 0;
    lastHighShootingY = 0;

    // Reset network parameters
    networkCounter = 0;
    networkPingCounter = 0;
    network_ping_send_limit = NETWORK_PING_SEND_LIMIT;
    nt_rotatedPieces = false;
    nt_diskMoved = false;
    nt_shootingMoved = false;

    trackTableTop = engine.gameConfig != null && engine.gameConfig!.tableTop;
    if (trackTableTop) {
      setTableTop(false);
    }

    // Main game loop
    while (!done) {
      if (engine.gameFinished != 0) {
        break;
      }

      if (engine.notPlayed && !renderer.showArcs && engine.playerTypes[0] == 0) {
        renderer.showArcs = true;
      }
      if (!engine.notPlayed && renderer.showArcs) {
        renderer.showArcs = false;
      }

      if (engine.gameConfig != null && 
          engine.gameConfig!.isPlayingNetwork &&
          !engine.gameFragment!.controllerReadyToGo) {
        await sleepMe(SLEEP_TIME);
      }

      bool tableTop = engine.gameConfig != null && engine.gameConfig!.tableTop;
      int tableTopCameraView = -1;
      bool adjustViewChange = false;

      if (tableTop && !trackTableTop && engine.gameConfig != null) {
        engine.gameConfig!.frontPlayer = engine.currentPlayer;
        engine.fixCameraSide = engine.currentPlayer;
        engine.fixCamera = true;
        trackTableTop = tableTop;
        adjustViewChange = true;
        setTableTop(true);
        lastPlayedCameraAnglex[0] = 0;
        lastPlayedCameraAnglex[1] = 0;
      } else if (!tableTop && trackTableTop && engine.gameConfig != null) {
        engine.fixCamera = engine.gameConfig!.cameraFixability;
        tableTopCameraView = engine.fixCameraSide;

        if (engine.playerTypes[0] == 0 && engine.playerTypes[1] == 0) {
          engine.fixCamera = false;
        } else if (engine.playerTypes[1] == 0) {
          engine.fixCameraSide = 1;
        } else {
          engine.fixCameraSide = 0;
        }
        trackTableTop = tableTop;

        lastPlayedCameraAnglex[0] = -30;
        lastPlayedCameraAnglex[1] = 30;

        int currentLocalView = engine.currentPlayer;
        if (engine.fixCamera) {
          currentLocalView = engine.fixCameraSide;
        }

        if (tableTopCameraView == currentLocalView) {
          if (tableTopCameraView == 0) {
            unsetTableTop(true, -30);
          } else {
            unsetTableTop(true, 30);
          }
        } else {
          adjustViewChange = true;
        }
      }

      if (trackFixedCamera != engine.fixCamera || adjustViewChange) {
        int currentView = engine.currentPlayer;
        if (trackFixedCamera) {
          currentView = engine.fixCameraSide;
        }
        if (tableTopCameraView != -1) {
          currentView = tableTopCameraView;
        }
        lastCameraChangedDir = currentView;

        lastPlayedCameraAnglex[currentView] = renderer.xangle;
        lastPlayedCameraAngley[currentView] = renderer.yangle;
        lastPlayedCameraScale[currentView] = renderer.scale;
        lastPlayedCameraDisp[currentView] = renderer.eyedisp;

        trackFixedCamera = engine.fixCamera;
        adjustPlayerChange(true, true);
      }

      if (tableTopCameraView != -1) {
        lastPlayedCameraAnglex[0] = -30;
        lastPlayedCameraAnglex[1] = 30;
      }

      if (!engine.shootingProgress || engine.automatic || engine.gameFragment == null) {
        if (engine.boardDoubleTapState == 3) {
          await animateScale();
        }

        if (engine.moving && (engine.diffX != 0 || engine.diffY != 0)) {
          if (engine.rotateTouched && !engine.automatic) {
            // Rotate pieces
            double angle = 0;

            if ((engine.diffY).abs() >= (engine.diffX).abs()) {
              if (engine.rightFromMiddle) {
                engine.diffY = -engine.diffY;
              }
              if (engine.diffY > 0) {
                angle = PIECES_ROTATE_ANGLE;
              } else if (engine.diffY < 0) {
                angle = -PIECES_ROTATE_ANGLE;
              }
            } else {
              if (engine.currentY < renderer.screenHeight / 2) {
                engine.diffX = -engine.diffX;
              }
              if (engine.diffX > 0) {
                angle = PIECES_ROTATE_ANGLE;
              } else if (engine.diffX < 0) {
                angle = -PIECES_ROTATE_ANGLE;
              }
            }

            // Update all pieces except disk
            for (int i = 2; i < 20; i++) {
              double ox = renderer.xposPieces[i];
              double oy = renderer.yposPieces[i];

              double len = math.sqrt(ox * ox + oy * oy);
              double cosa = ox / len;
              double sina = oy / len;

              double cosb = math.cos(angle);
              double sinb = math.sin(angle);

              double cosab = cosb * cosa - sinb * sina;
              double sinab = sinb * cosa + cosb * sina;

              renderer.xposPieces[i] = len * cosab;
              renderer.yposPieces[i] = len * sinab;
            }
            renderer.arcAngle += angle * MeshData.RAD_TO_DEG;

            engine.diffX = engine.diffY = 0;
            engine.startX = engine.currentX;
            engine.startY = engine.currentY;
            nt_rotatedPieces = true;
          } else {
            // Camera rotation
            int xdiff = 0;
            int ydiff = 0;
            double eyediff = 0;

            if ((!trackFixedCamera && engine.currentPlayer == 0) ||
                (trackFixedCamera && engine.fixCameraSide == 0)) {
              if ((engine.diffY).abs() >= (engine.diffX).abs()) {
                if (!tableTop) {
                  if (engine.diffY < 0 && renderer.xangle > -80) {
                    xdiff -= 3;
                  } else if (engine.diffY > 0 && renderer.xangle < 0) {
                    xdiff += 3;
                  }
                }
              } else if (engine.middleTouched) {
                if (engine.diffX > 0 && renderer.eyedisp < 0.7) {
                  eyediff += 0.05;
                } else if (engine.diffX < 0 && renderer.eyedisp > -0.7) {
                  eyediff -= 0.05;
                }
              } else {
                if (engine.currentY < renderer.screenHeight / 2) {
                  engine.diffX = -engine.diffX;
                }
                if (engine.diffX > 0 && renderer.yangle < 35) {
                  ydiff += 2;
                } else if (engine.diffX < 0 && renderer.yangle > -35) {
                  ydiff -= 2;
                }
              }
            } else if ((!trackFixedCamera && engine.currentPlayer == 1) ||
                (trackFixedCamera && engine.fixCameraSide == 1) &&
                    engine.playerCount == 2) {
              if ((engine.diffY).abs() >= (engine.diffX).abs()) {
                if (!tableTop) {
                  if (engine.diffY < 0 && renderer.xangle < 80) {
                    xdiff += 3;
                  } else if (engine.diffY > 0 && renderer.xangle > 0) {
                    xdiff -= 3;
                  }
                }
              } else if (engine.middleTouched) {
                if (engine.diffX < 0 && renderer.eyedisp < 0.7) {
                  eyediff += 0.05;
                } else if (engine.diffX > 0 && renderer.eyedisp > -0.7) {
                  eyediff -= 0.05;
                }
              } else {
                if (engine.currentY < renderer.screenHeight / 2) {
                  engine.diffX = -engine.diffX;
                }
                if (engine.diffX > 0 && renderer.yangle < 35) {
                  ydiff += 2;
                } else if (engine.diffX < 0 && renderer.yangle > -35) {
                  ydiff -= 2;
                }
              }
            }

            renderer.updateEye(ydiff.toDouble(), xdiff.toDouble(), 0, eyediff);
            engine.diffX = engine.diffY = 0;
            engine.startX = engine.currentX;
            engine.startY = engine.currentY;
          }
        }

        if (engine.scaling) {
          double scalediff = 0;
          if (engine.scaleFactor > 1) {
            if (renderer.scale < 1.6) {
              scalediff = 0.05;
            }
          } else if (engine.scaleFactor < 1) {
            if (renderer.scale > 0.8) {
              scalediff = -0.05;
            }
          }
          engine.scaleFactor = 1;
          renderer.updateEye(0, 0, scalediff, 0);
        }

        double diskCurrentX = engine.diskCurrentX;
        double diskCurrentY = engine.diskCurrentY;
        double diskStartX = engine.diskStartX;
        double diskStartY = engine.diskStartY;

        if (!engine.shootingProgress) {
          if (engine.autoPlayers[engine.currentPlayer] != null) {
            engine.autoPlayers[engine.currentPlayer]!.strategize();
          }
        }

        if (renderer.shootingMode) {
          // Shooting mode logic
          await _handleShootingMode(
            diskMoveMultiplier,
            diskCurrentX,
            diskCurrentY,
            diskStartX,
            diskStartY,
          );
          diskMoveMultiplier = 1; // Reset after handling
        } else {
          // Disk positioning mode
          var result = await _handleDiskPositioning(
            diskMoveMultiplier,
            diskCurrentX,
            diskCurrentY,
            diskStartX,
            diskStartY,
            lastDiskChanged,
            diskJustMoved,
          );
          diskMoveMultiplier = result['multiplier'];
          lastDiskChanged = result['lastChanged'];
          diskJustMoved = result['justMoved'];
        }
      }

      // Place disk on touch
      if (!engine.automatic && engine.placingDisk && !renderer.shootingMode) {
        bool placeIt = false;
        double diskyBorder = MeshData.DISK_YBORDER + 
            MeshData.RADIUS * MeshData.DISK_RADIUS_FACTOR;
        double upBorder = MeshData.DISK_UP_TOUCH_LIMIT - 
            MeshData.RADIUS * MeshData.DISK_RADIUS_FACTOR;
        double downBorder = MeshData.DISK_DOWN_TOUCH_LIMIT + 
            MeshData.RADIUS * MeshData.DISK_RADIUS_FACTOR;

        if (engine.playerCount == 4) {
          // 4 player mode
        } else {
          if (engine.currentPlayer == 1 &&
              engine.placingDiskx > -diskyBorder &&
              engine.placingDiskx < diskyBorder &&
              engine.placingDisky > upBorder &&
              engine.placingDisky < downBorder) {
            placeIt = true;
          } else if (engine.currentPlayer == 0 &&
              engine.placingDiskx > -diskyBorder &&
              engine.placingDiskx < diskyBorder &&
              engine.placingDisky < -upBorder &&
              engine.placingDisky > -downBorder) {
            placeIt = true;
          }
        }

        if (placeIt) {
          currentDiskxpos = engine.placingDiskx;
          currentDiskypos = renderer.yposPieces[0];
          await placeDisk();
          nt_diskMoved = true;
        }
      }
      engine.placingDisk = false;

      // Check if pieces are in holes
      bool stillFalling = await _checkPiecesInHoles();

      // Speed up and collision detection
      bool mayCollide = _speedUpPieces();

      // Collision handling
      if (mayCollide) {
        collisionHandling();
        for (int i = 0; i < 20; i++) {
          if (newspeedx[i] != 0 || newspeedy[i] != 0) {
            finishSpeedup(i);
          }
        }
      }

      // Check if anything is moving
      bool movingAnything = false;
      if (stillFalling || mayCollide) {
        for (int i = 0; i < 20; i++) {
          double newspeedi = math.sqrt(
              newspeedx[i] * newspeedx[i] + newspeedy[i] * newspeedy[i]);
          if (newspeedi > 1e-3 ||
              !(renderer.presents[i] == 0 ||
                  renderer.presents[i] == MeshData.HOLE_ANI_LIMIT)) {
            movingAnything = true;
          }
        }
      }

      if (!movingAnything) {
        if (engine.shootingProgress && !changingPlayer) {
          changingPlayer = true;
          changingPlayerIndex = 0;

          for (int i = 0; i < 20; i++) {
            speedx[i] = newspeedx[i] = 0;
            speedy[i] = newspeedy[i] = 0;
          }
        }

        if (!engine.shootingProgress && !changingPlayer && !engine.automatic) {
          _enforceDiskBoundaries();
        }
      }

      if (changingPlayer) {
        changingPlayerIndex++;
        if (changingPlayerIndex > changingPlayerLimit) {
          await _handlePlayerChange(changingPlayer);
          changingPlayer = false;
        }
      }

      if (engine.doubleTapState == 3) {
        renderer.shootingMode = !renderer.shootingMode;
        engine.doubleTapState = 0;
        diskMoveMultiplier = 1;
        renderer.shootingX = 0;
        renderer.shootingY = 0;
      }

      // Network communication
      if (engine.gameConfig != null && engine.gameConfig!.isPlayingNetwork) {
        sendToNetwork();
      }

      await sleepMe(SLEEP_TIME);
    }
  }

  Future<void> sleepMe(int time) async {
    if (!done) {
      await Future.delayed(Duration(milliseconds: time));
    }
  }

  // Disk placement
  double currentDiskxpos = 0;
  double currentDiskypos = 0;

  void findPlaceToDisk() {
    List<double> xs = renderer.xposPieces;
    List<double> ys = renderer.yposPieces;

    if (currentDiskxpos > MeshData.DISK_YBORDER) {
      currentDiskxpos = MeshData.DISK_YBORDER;
    }
    if (currentDiskxpos < -MeshData.DISK_YBORDER) {
      currentDiskxpos = -MeshData.DISK_YBORDER;
    }

    double radius = MeshData.RADIUS * (1 + MeshData.DISK_RADIUS_FACTOR);
    radius *= radius;

    double cutRadius = MeshData.RADIUS * MeshData.DISK_RADIUS_FACTOR +
        MeshData.RED_CIRCLE_RADIUS;

    bool failed = true;

    for (int j = 0; failed; j++) {
      double newxpos;
      double newypos;
      double offset = j * 0.01;

      if (engine.playerCount == 2) {
        if (currentDiskxpos + offset > MeshData.DISK_YBORDER &&
            currentDiskxpos - offset < -MeshData.DISK_YBORDER) {
          failed = true;
          break;
        }

        newxpos = currentDiskxpos + offset;
        newypos = currentDiskypos;

        bool cut = (newxpos > -MeshData.DISK_YBORDER + 0.02 &&
                newxpos < -MeshData.DISK_YBORDER + cutRadius) ||
            (newxpos < MeshData.DISK_YBORDER - 0.02 &&
                newxpos > MeshData.DISK_YBORDER - cutRadius);

        if (newxpos < MeshData.DISK_YBORDER && !cut) {
          bool conflict = false;
          for (int i = 1; i < 20; i++) {
            if (renderer.presents[i] != MeshData.HOLE_ANI_LIMIT) {
              continue;
            }
            if (distsq(newxpos, newypos, xs[i], ys[i]) < radius) {
              conflict = true;
              break;
            }
          }

          if (!conflict) {
            currentDiskxpos = newxpos;
            currentDiskypos = newypos;
            failed = false;
            break;
          }
        }

        newxpos = currentDiskxpos - offset;
        newypos = currentDiskypos;

        cut = (newxpos > -MeshData.DISK_YBORDER + 0.02 &&
                newxpos < -MeshData.DISK_YBORDER + cutRadius) ||
            (newxpos < MeshData.DISK_YBORDER - 0.02 &&
                newxpos > MeshData.DISK_YBORDER - cutRadius);

        if (newxpos > -MeshData.DISK_YBORDER && !cut) {
          bool conflict = false;
          for (int i = 1; i < 20; i++) {
            if (renderer.presents[i] != MeshData.HOLE_ANI_LIMIT) {
              continue;
            }
            if (distsq(newxpos, newypos, xs[i], ys[i]) < radius) {
              conflict = true;
              break;
            }
          }

          if (!conflict) {
            currentDiskxpos = newxpos;
            currentDiskypos = newypos;
            failed = false;
            break;
          }
        }
      }
    }
  }

  int lastCameraChangedDir = -1;

  void adjustPlayerChange(bool transition, bool firstTime) {
    int currentView = engine.currentPlayer;
    if (trackFixedCamera) {
      currentView = engine.fixCameraSide;
    }

    if (lastPlayedCameraAnglex[0] > 0) {
      lastPlayedCameraAnglex[0] = -lastPlayedCameraAnglex[0];
    }
    if (lastPlayedCameraAnglex[1] < 0) {
      lastPlayedCameraAnglex[1] = -lastPlayedCameraAnglex[1];
    }

    if (transition) {
      currentDiskxpos = lastPlayedDiskPosx[engine.currentPlayer];
      currentDiskypos = lastPlayedDiskPosy[engine.currentPlayer];

      findPlaceToDisk();

      const int steps = 20;

      if (engine.playerCount == 2) {
        double yangleDiff = (180 - renderer.yangle + 
            lastPlayedCameraAngley[currentView]) / steps;
        double xangleDiff = (-lastPlayedCameraAnglex[currentView] - 
            renderer.xangle) / steps;
        double scaleDiff = (lastPlayedCameraScale[currentView] - 
            renderer.scale) / steps;
        double eyeDiff = (-lastPlayedCameraDisp[currentView] - 
            renderer.eyedisp) / steps;
        double xposdiff = (currentDiskxpos - renderer.xposPieces[0]) / steps;
        double yposdiff = (currentDiskypos - renderer.yposPieces[0]) / steps;

        if (!firstTime) {
          renderer.zRaised[0] = true;
        }

        for (int i = 0; i < steps && !done; i++) {
          if (engine.changeTurn && lastCameraChangedDir != currentView) {
            renderer.updateEye(yangleDiff, xangleDiff, scaleDiff, eyeDiff);
          }
          if (!firstTime) {
            renderer.xposPieces[0] += xposdiff;
            renderer.yposPieces[0] += yposdiff;
          }

          sleepMe(SLEEP_TIME);
        }
      }

      if (!firstTime) {
        renderer.xposPieces[0] = currentDiskxpos;
        renderer.yposPieces[0] = currentDiskypos;
        renderer.zRaised[0] = false;
      }
      engine.lastLandedDiskX = currentDiskxpos;
      engine.lastLandedDiskY = currentDiskypos;
    }

    if (currentView == 0 && renderer.xangle > 0) {
      renderer.xangle = -renderer.xangle;
      renderer.updateEye(0, 0, 0, 0);
    } else if (currentView == 1 && renderer.xangle < 0) {
      renderer.xangle = -renderer.xangle;
      renderer.updateEye(0, 0, 0, 0);
    }

    if (lastCameraChangedDir != currentView) {
      renderer.xangle = lastPlayedCameraAnglex[currentView];
      renderer.yangle = lastPlayedCameraAngley[currentView];
      renderer.scale = lastPlayedCameraScale[currentView];
      renderer.eyedisp = lastPlayedCameraDisp[currentView];
      renderer.rotateXFirst = lastPlayedCameraRotateXFirst[currentView];
      renderer.upZ = lastPlayedCameraUpZ[currentView];
      renderer.upY = lastPlayedCameraUpY[currentView];

      renderer.updateEye(0, 0, 0, 0);
      lastCameraChangedDir = currentView;
    }
  }

  void setTableTop(bool transition) {
    if (transition) {
      const int steps = 20;
      double xangleDiff = (0 - renderer.xangle) / steps;

      for (int i = 0; i < steps && !done; i++) {
        renderer.updateEye(0, xangleDiff, 0, 0);
        sleepMe(SLEEP_TIME);
      }
    }
    renderer.xangle = 0;
    renderer.updateEye(0, 0, 0, 0);
  }

  void unsetTableTop(bool transition, double resetAngle) {
    if (transition) {
      const int steps = 20;
      double xangleDiff = resetAngle / steps;

      for (int i = 0; i < steps && !done; i++) {
        renderer.updateEye(0, xangleDiff, 0, 0);
        sleepMe(SLEEP_TIME);
      }
    }
    renderer.xangle = resetAngle;
    renderer.updateEye(0, 0, 0, 0);
  }

  void finishSpeedup(int i) {
    double radius = MeshData.RADIUS;
    if (i == 0) {
      radius = MeshData.RADIUS * MeshData.DISK_RADIUS_FACTOR;
    }

    double boundary = 0.9 - radius;

    bool hitBoundary = false;
    double wallSpeed = 0;

    // Reverse at boundary
    if (newposx[i] > boundary) {
      newposx[i] = boundary - (newposx[i] - boundary);
      newspeedx[i] = -newspeedx[i] + BORDER_ENERGY_LOSS_SQR;
      wallSpeed = -newspeedx[i];
      hitBoundary = true;
    } else if (newposx[i] < -boundary) {
      newposx[i] = -boundary + (-boundary - newposx[i]);
      newspeedx[i] = -newspeedx[i] - BORDER_ENERGY_LOSS_SQR;
      wallSpeed = newspeedx[i];
      hitBoundary = true;
    }

    if (newposy[i] > boundary) {
      newposy[i] = boundary - (newposy[i] - boundary);
      newspeedy[i] = -newspeedy[i] + BORDER_ENERGY_LOSS_SQR;
      wallSpeed = -newspeedy[i];
      hitBoundary = true;
    } else if (newposy[i] < -boundary) {
      newposy[i] = -boundary + (-boundary - newposy[i]);
      newspeedy[i] = -newspeedy[i] - BORDER_ENERGY_LOSS_SQR;
      wallSpeed = newspeedy[i];
      hitBoundary = true;
    }

    if (hitBoundary && renderer.presents[i] == MeshData.HOLE_ANI_LIMIT) {
      if (i == 0) {
        engine.soundThread?.playDwall(wallSpeed);
      } else {
        engine.soundThread?.playPwall(wallSpeed);
      }
    }

    applyFriction(i);

    speedx[i] = newspeedx[i];
    speedy[i] = newspeedy[i];
    renderer.xposPieces[i] = newposx[i];
    renderer.yposPieces[i] = newposy[i];
  }

  void applyFriction(int i) {
    double friction = PIECES_FRICTION;
    if (i == 0) {
      friction = DISK_FRICTION;
    }

    double newspeedi = math.sqrt(
        newspeedx[i] * newspeedx[i] + newspeedy[i] * newspeedy[i]);
    double fricspeedi = newspeedi - friction;
    double fricfactor = 0;

    if (fricspeedi <= 0) {
      fricfactor = 0;
    } else {
      fricfactor = fricspeedi / newspeedi;
    }

    newspeedx[i] *= fricfactor;
    newspeedy[i] *= fricfactor;

    newspeedi = math.sqrt(
        newspeedx[i] * newspeedx[i] + newspeedy[i] * newspeedy[i]);

    if (newspeedi < 1e-3) {
      newspeedx[i] = 0;
      newspeedy[i] = 0;
    }
  }

  double costheta = 1;
  double sintheta = 0;

  // Collision handling - This is the most complex physics part
  void collisionHandling() {
    bool foundSomething = true;
    int soundCount = 0;
    double soundSpeed = 0;

    // Sort items by distance to disk
    for (int i = 1; i < 20; i++) {
      if (renderer.presents[i] != MeshData.HOLE_ANI_LIMIT) {
        sortedDists[i] = 10; // large value
      } else {
        sortedDists[i] = distdsq(newposx[i], newposy[i], newposx[0], newposy[0]);
      }
      sortedItems[i] = i;
    }

    // Insertion sort
    for (int i = 2; i < 20; i++) {
      int tmpItem = sortedItems[i];
      double tmpDist = sortedDists[i];
      int j = i - 1;
      while (j > 0 && sortedDists[j] > tmpDist) {
        sortedDists[j + 1] = sortedDists[j];
        sortedItems[j + 1] = sortedItems[j];
        j--;
      }
      j++;
      if (j != i) {
        sortedDists[j] = tmpDist;
        sortedItems[j] = tmpItem;
      }
    }

    // Collision detection loop (continues in next comment for length)
    for (int k = 0; k < 20 && foundSomething; k++) {
      foundSomething = false;
      const double hitEnergyLoss = HIT_ENERGY_LOSS;

      for (int s = 0; s < 20; s++) {
        int i = sortedItems[s];
        if (renderer.presents[i] != MeshData.HOLE_ANI_LIMIT) {
          continue;
        }

        double innerRadius = MeshData.RADIUS;
        double alpha = 1.0;
        if (i == 0) {
          innerRadius *= MeshData.DISK_RADIUS_FACTOR;
          alpha = WEIGHT_FACTOR;
        }

        for (int t = s + 1; t < 20; t++) {
          int j = sortedItems[t];
          if (renderer.presents[j] != MeshData.HOLE_ANI_LIMIT) {
            continue;
          }

          double mustdist = innerRadius + MeshData.RADIUS;
          double distsqVal = distdsq(newposx[i], newposy[i], newposx[j], newposy[j]);

          if (distsqVal <= mustdist * mustdist) {
            // If i is stationary, swap i and j
            if (i != 0 && newspeedx[i] == 0 && newspeedy[i] == 0) {
              int tmp = i;
              i = j;
              j = tmp;
            }

            // Calculate relative velocity
            double v1x = newspeedx[i] - newspeedx[j];
            double v1y = newspeedy[i] - newspeedy[j];

            if ((v1x).abs() < 1e-9 && (v1y).abs() < 1e-9) {
              continue;
            }

            double v1 = math.sqrt(v1x * v1x + v1y * v1y);
            foundSomething = true;

            double px = newposx[j] - newposx[i];
            double py = newposy[j] - newposy[i];
            double p = math.sqrt(px * px + py * py);

            double cosalpha = 1;
            double sinalpha = 0;

            if (p > 0) {
              finddangles(px, py, -v1x, -v1y);
              cosalpha = cosdtheta;
              sinalpha = sindtheta;
            }

            double q = mustdist;
            double r = p * cosalpha + 
                math.sqrt(q * q - p * p * sinalpha * sinalpha);
            double rx = r * v1x / v1;
            double ry = r * v1y / v1;

            double cosbeta = math.sqrt(q * q - p * p * sinalpha * sinalpha) / q;

            double nposxi = newposx[i] - rx;
            double nposyi = newposy[i] - ry;

            double a = alpha * alpha + alpha;
            double b = -2 * alpha * v1 * cosbeta;
            double c = hitEnergyLoss;

            double bsq4ac = b * b - 4 * a * c;
            if (bsq4ac > 0) {
              bsq4ac = math.sqrt(bsq4ac);
            } else {
              bsq4ac = 0;
            }
            double u2 = (-b + bsq4ac) / (2 * a);

            double ijx = newposx[j] - nposxi;
            double ijy = newposy[j] - nposyi;
            double ij = math.sqrt(ijx * ijx + ijy * ijy);

            double u2x = u2 * ijx / ij;
            double u2y = u2 * ijy / ij;

            double v2x = -alpha * u2x + v1x;
            double v2y = -alpha * u2y + v1y;

            double bttime = r / v1;
            if (bttime > 1) {
              bttime = 1;
            }

            if (v1 > 1e-2) {
              double speedi = math.sqrt(
                  newspeedx[i] * newspeedx[i] + newspeedy[i] * newspeedy[i]);
              double speedj = math.sqrt(
                  newspeedx[j] * newspeedx[j] + newspeedy[j] * newspeedy[j]);

              if (speedi > 1e-2 || speedj > 1e-2) {
                soundCount++;
                double newSoundSpeed = v1 * cosbeta;
                if (soundSpeed < newSoundSpeed) {
                  soundSpeed = newSoundSpeed;
                }
              }
            }

            double btposxi = newposx[i] - newspeedx[i] * bttime;
            double btposyi = newposy[i] - newspeedy[i] * bttime;
            double btposxj = newposx[j] - newspeedx[j] * bttime;
            double btposyj = newposy[j] - newspeedy[j] * bttime;

            double oldspeedxj = newspeedx[j];
            double oldspeedyj = newspeedy[j];
            double oldspeedxi = newspeedx[i];
            double oldspeedyi = newspeedy[i];

            double newspeedxi = v2x + oldspeedxj;
            double newspeedyi = v2y + oldspeedyj;
            double newspeedxj = u2x + oldspeedxj;
            double newspeedyj = u2y + oldspeedyj;

            double expectedEnergy = oldspeedxi * oldspeedxi +
                oldspeedyi * oldspeedyi +
                alpha * (oldspeedxj * oldspeedxj + oldspeedyj * oldspeedyj) -
                hitEnergyLoss;
            double actualEnergy = newspeedxi * newspeedxi +
                newspeedyi * newspeedyi +
                alpha * (newspeedxj * newspeedxj + newspeedyj * newspeedyj);

            if (expectedEnergy <= 0) {
              newspeedx[i] = newspeedy[i] = newspeedx[j] = newspeedy[j] = 0;
            } else if (actualEnergy == 0) {
              // no change
            } else {
              double factor = expectedEnergy / actualEnergy;
              factor = math.sqrt(factor);
              newspeedx[i] = newspeedxi * factor;
              newspeedy[i] = newspeedyi * factor;
              newspeedx[j] = newspeedxj * factor;
              newspeedy[j] = newspeedyj * factor;
            }

            newposx[i] = btposxi + newspeedx[i] * bttime;
            newposy[i] = btposyi + newspeedy[i] * bttime;
            newposx[j] = btposxj + newspeedx[j] * bttime;
            newposy[j] = btposyj + newspeedy[j] * bttime;
          }
        }
      }
    }

    if (soundCount > 0) {
      if (soundCount > 4) {
        soundCount = 4;
      }
      double factor = 1 + (soundCount - 1) / 3;
      engine.soundThread?.playDpiece(soundSpeed, factor);
    }
  }

  double distsq(double x1, double y1, double x2, double y2) {
    return (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
  }

  double distdsq(double x1, double y1, double x2, double y2) {
    return (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
  }

  double dist(double x1, double y1, double x2, double y2) {
    return math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
  }

  void findangles(double a1x, double a1y, double a2x, double a2y) {
    double s1 = math.sqrt(a1x * a1x + a1y * a1y);
    double s2 = math.sqrt(a2x * a2x + a2y * a2y);

    costheta = (a1x * a2x + a1y * a2y) / (s1 * s2);
    sintheta = (a1x * a2y - a2x * a1y) / (s1 * s2);
  }

  double cosdtheta = 1;
  double sindtheta = 0;

  void finddangles(double a1x, double a1y, double a2x, double a2y) {
    double s1 = math.sqrt(a1x * a1x + a1y * a1y);
    double s2 = math.sqrt(a2x * a2x + a2y * a2y);

    cosdtheta = (a1x * a2x + a1y * a2y) / (s1 * s2);
    sindtheta = (a1x * a2y - a2x * a1y) / (s1 * s2);
  }

  // Arrow arrays
  List<double> arrowX = List.filled(16, 0.0);
  List<double> arrowY = List.filled(16, 0.0);
  List<double> arrowAngle = List.filled(16, 0.0);
  List<double> arrowLen = List.filled(16, 0.0);

  // This method is continued in part 2 due to length...
  // The file continues with readyArrows(), readyCross(), placeDisk(), 
  // replacePiece(), checkPenalties(), etc.

  // Helper methods for shooting/positioning mode
  Future<void> _handleShootingMode(
    int diskMoveMultiplier,
    double diskCurrentX,
    double diskCurrentY,
    double diskStartX,
    double diskStartY,
  ) async {
    // Implementation continues...
    // This is a placeholder for the shooting mode logic
  }

  Future<Map<String, dynamic>> _handleDiskPositioning(
    int diskMoveMultiplier,
    double diskCurrentX,
    double diskCurrentY,
    double diskStartX,
    double diskStartY,
    int lastDiskChanged,
    bool diskJustMoved,
  ) async {
    // When the disk is moving for positioning (not shooting mode)
    if (engine.diskMoving && !engine.automatic) {
      int currentTime = DateTime.now().millisecondsSinceEpoch;
      bool diskXChanged = false;
      double xpos = renderer.xposPieces[0];
      double ypos = renderer.yposPieces[0];
      
      if (engine.playerCount == 2) {
        // Move disk horizontally
        if (diskCurrentX - diskStartX > 0.01 / diskMoveMultiplier &&
            xpos < MeshData.DISK_YBORDER) {
          if (diskMoveMultiplier >= 8) {
            xpos += 1.8 * (diskCurrentX - diskStartX);
          } else {
            xpos += 0.001 * diskMoveMultiplier;
          }
          if (xpos > MeshData.DISK_YBORDER) {
            xpos = MeshData.DISK_YBORDER;
          }
          diskXChanged = true;
        } else if (diskCurrentX - diskStartX < -0.01 / diskMoveMultiplier &&
            xpos > -MeshData.DISK_YBORDER) {
          if (diskMoveMultiplier >= 8) {
            xpos += 1.8 * (diskCurrentX - diskStartX);
          } else {
            xpos -= 0.001 * diskMoveMultiplier;
          }
          if (xpos < -MeshData.DISK_YBORDER) {
            xpos = -MeshData.DISK_YBORDER;
          }
          diskXChanged = true;
        }
      }
      
      if (diskXChanged) {
        engine.diskStartX = diskCurrentX;
        if (diskMoveMultiplier < 8) {
          diskMoveMultiplier += 2;
        }
        lastDiskChanged = currentTime;
      }
      
      bool diskYChanged = false;
      if (engine.playerCount == 2) {
        if (engine.currentPlayer == 0) {
          // Player 0: disk on bottom side
          if (diskCurrentY - diskStartY > 0.01 &&
              ypos < -MeshData.DISK_START_DIST + MeshData.DISK_START_UP_DIFF) {
            ypos += 0.001;
            diskYChanged = true;
          } else if (diskCurrentY - diskStartY < -0.01 &&
              ypos > -MeshData.DISK_START_DIST - MeshData.DISK_START_DOWN_DIFF) {
            ypos -= 0.001;
            diskYChanged = true;
          }
        } else {
          // Player 1: disk on top side
          if (diskCurrentY - diskStartY < -0.01 &&
              ypos > MeshData.DISK_START_DIST - MeshData.DISK_START_UP_DIFF) {
            ypos -= 0.001;
            diskYChanged = true;
          } else if (diskCurrentY - diskStartY > 0.01 &&
              ypos < MeshData.DISK_START_DIST + MeshData.DISK_START_DOWN_DIFF) {
            ypos += 0.001;
            diskYChanged = true;
          }
        }
      }
      
      if (diskYChanged) {
        engine.diskStartY = diskCurrentY;
        if (diskMoveMultiplier > 1) {
          diskMoveMultiplier ~/= 2;
        }
        lastDiskChanged = currentTime;
      }
      
      // Actually move the disk position based on changes
      if (diskXChanged || diskYChanged) {
        double radius = MeshData.RADIUS * (1 + MeshData.DISK_RADIUS_FACTOR);
        radius *= radius;
        
        bool conflict = false;
        for (int i = 1; i < 20; i++) {
          if (renderer.presents[i] != MeshData.HOLE_ANI_LIMIT) {
            continue;
          }
          if (distsq(xpos, ypos, renderer.xposPieces[i], renderer.yposPieces[i]) < radius) {
            conflict = true;
            break;
          }
        }
        
        if (conflict) {
          renderer.zRaised[0] = true;
        } else {
          renderer.zRaised[0] = false;
          engine.lastLandedDiskX = xpos;
          engine.lastLandedDiskY = ypos;
        }
        
        renderer.xposPieces[0] = xpos;
        renderer.yposPieces[0] = ypos;
        
        nt_diskMoved = true;
      }
      
      if (lastDiskChanged - currentTime > 500) {
        diskMoveMultiplier = 1;
      }
      diskJustMoved = true;
    } else {
      diskMoveMultiplier = 1;
    }
    
    // When disk dragging just ended
    if (!engine.diskMoving && diskJustMoved) {
      diskJustMoved = false;
      renderer.zRaised[0] = false;
      
      currentDiskxpos = renderer.xposPieces[0];
      currentDiskypos = renderer.yposPieces[0];
      
      findPlaceToDisk();
      
      engine.lastLandedDiskX = currentDiskxpos;
      engine.lastLandedDiskY = currentDiskypos;
      renderer.xposPieces[0] = engine.lastLandedDiskX;
      renderer.yposPieces[0] = engine.lastLandedDiskY;
      nt_diskMoved = true;
    }
    
    return {
      'multiplier': diskMoveMultiplier,
      'lastChanged': lastDiskChanged,
      'justMoved': diskJustMoved,
    };
  }

  Future<bool> _checkPiecesInHoles() async {
    bool stillFalling = false;
    for (int i = 0; i < 20; i++) {
      if (renderer.presents[i] == 0) {
        continue;
      } else if (renderer.presents[i] < MeshData.HOLE_ANI_LIMIT) {
        stillFalling = true;
        renderer.presents[i]--;
        continue;
      }

      double maxDistSq = (MeshData.HOLE_RADIUS * MeshData.HOLE_RADIUS) / 4;

      double px = renderer.xposPieces[i];
      double py = renderer.yposPieces[i];

      double hx = 0;
      double hy = 0;

      if (px >= 0) {
        hx = 0.9 - MeshData.HOLE_RADIUS;
      } else {
        hx = -0.9 + MeshData.HOLE_RADIUS;
      }

      if (py >= 0) {
        hy = 0.9 - MeshData.HOLE_RADIUS;
      } else {
        hy = -0.9 + MeshData.HOLE_RADIUS;
      }

      if (hx == 0 || hy == 0) {
        continue;
      }

      double distVal = distsq(hx, hy, px, py);

      if (distVal < maxDistSq) {
        double speed = math.sqrt(
            engine.speedx[i] * engine.speedx[i] + 
            engine.speedy[i] * engine.speedy[i]);

        if (i == 0) {
          engine.soundThread?.playDhole(speed);
        } else {
          engine.soundThread?.playPhole(speed);
        }

        renderer.presents[i]--;
        renderer.xposPieces[i] = hx;
        renderer.yposPieces[i] = hy;
        engine.speedx[i] = 0;
        engine.speedy[i] = 0;

        if (engine.playerCount == 4) {
          // 4 player mode
        } else {
          if (i == 1 && engine.redPotState == 0) {
            engine.changeTurn = false;
            engine.redPotState = 1;
          } else if (i >= 2 && i <= 10) {
            if (engine.currentPlayer == 0) {
              engine.changeTurn = false;
            }
            engine.currentTurnWhites++;
            engine.pocketedWhites++;
            engine.updateScorePanel();
          } else if (i >= 11 && i < 20) {
            if (engine.currentPlayer == 1) {
              engine.changeTurn = false;
            }
            engine.currentTurnBlacks++;
            engine.pocketedBlacks++;
            engine.updateScorePanel();
          }
        }
        stillFalling = true;
      }
    }
    return stillFalling;
  }

  bool _speedUpPieces() {
    bool mayCollide = false;
    for (int i = 0; i < 20; i++) {
      if (renderer.presents[i] != MeshData.HOLE_ANI_LIMIT) {
        newposx[i] = renderer.xposPieces[i];
        newposy[i] = renderer.yposPieces[i];
        newspeedx[i] = speedx[i];
        newspeedy[i] = speedy[i];
        continue;
      }

      if (speedx[i] != 0 || speedy[i] != 0) {
        newposx[i] = renderer.xposPieces[i] + speedx[i];
        newposy[i] = renderer.yposPieces[i] + speedy[i];
        newspeedx[i] = speedx[i];
        newspeedy[i] = speedy[i];

        if (i > 1) {
          engine.strokeHitSomewhere = true;
        }
        mayCollide = true;
      } else {
        newposx[i] = renderer.xposPieces[i];
        newposy[i] = renderer.yposPieces[i];
        newspeedx[i] = speedx[i];
        newspeedy[i] = speedy[i];
      }
    }
    return mayCollide;
  }

  void _enforceDiskBoundaries() {
    if (engine.playerCount == 4) {
      // 4 player mode
    } else {
      if (engine.currentPlayer == 0) {
        if (renderer.yposPieces[0] < 
            -MeshData.DISK_START_DIST - MeshData.DISK_START_DOWN_DIFF) {
          renderer.yposPieces[0] = 
              -MeshData.DISK_START_DIST - MeshData.DISK_START_DOWN_DIFF;
        } else if (renderer.yposPieces[0] > 
            -MeshData.DISK_START_DIST + MeshData.DISK_START_UP_DIFF) {
          renderer.yposPieces[0] = 
              -MeshData.DISK_START_DIST + MeshData.DISK_START_UP_DIFF;
        }
      } else {
        if (renderer.yposPieces[0] > 
            MeshData.DISK_START_DIST + MeshData.DISK_START_DOWN_DIFF) {
          renderer.yposPieces[0] = 
              MeshData.DISK_START_DIST + MeshData.DISK_START_DOWN_DIFF;
        } else if (renderer.yposPieces[0] < 
            MeshData.DISK_START_DIST - MeshData.DISK_START_UP_DIFF) {
          renderer.yposPieces[0] = 
              MeshData.DISK_START_DIST - MeshData.DISK_START_UP_DIFF;
        }
      }

      if (renderer.xposPieces[0] > MeshData.DISK_YBORDER) {
        renderer.xposPieces[0] = MeshData.DISK_YBORDER;
      } else if (renderer.xposPieces[0] < -MeshData.DISK_YBORDER) {
        renderer.xposPieces[0] = -MeshData.DISK_YBORDER;
      }
    }
  }

  Future<void> _handlePlayerChange(bool changingPlayer) async {
    // Player change logic - implementation continues
  }

  Future<void> placeDisk() async {
    // Find a valid position for the disk
    findPlaceToDisk();
    
    const int steps = 10;
    
    double xposdiff = (currentDiskxpos - renderer.xposPieces[0]) / steps;
    double yposdiff = (currentDiskypos - renderer.yposPieces[0]) / steps;
    
    // Raise the disk during animation
    renderer.zRaised[0] = true;
    
    // Animate the disk movement
    for (int i = 0; i < steps && !done; i++) {
      renderer.xposPieces[0] += xposdiff;
      renderer.yposPieces[0] += yposdiff;
      
      await sleepMe(SLEEP_TIME);
    }
    
    // Lower the disk and set final position
    renderer.zRaised[0] = false;
    engine.lastLandedDiskX = currentDiskxpos;
    engine.lastLandedDiskY = currentDiskypos;
    renderer.xposPieces[0] = engine.lastLandedDiskX;
    renderer.yposPieces[0] = engine.lastLandedDiskY;
  }

  Future<void> animateScale() async {
    // Reset state immediately to prevent re-triggering during async animation
    // This is different from Java because Dart's async allows touch events
    // to be processed while we're awaiting inside the animation loop
    engine.boardDoubleTapState = 0;
    
    const int steps = 20;
    double targetScale = 0.8;
    bool scaleIn = false;
    
    if (renderer.scale > 1.2) {
      targetScale = 1.0;
    } else {
      targetScale = 1.4;
      scaleIn = true;
    }
    
    double eyeDisp = 0;
    if (scaleIn) {
      eyeDisp = -engine.boardTapx;
      if (eyeDisp > 0.7) {
        eyeDisp = 0.7;
      }
      if (eyeDisp < -0.7) {
        eyeDisp = -0.7;
      }
    } else {
      eyeDisp = 0;
    }
    
    double scalediff = (targetScale - renderer.scale) / steps;
    double eyediff = (eyeDisp - renderer.eyedisp) / steps;
    
    for (int i = 0; i < steps && !done; i++) {
      renderer.updateEye(0, 0, scalediff, eyediff);
      await sleepMe(SLEEP_TIME);
    }
    
    renderer.scale = targetScale;
    renderer.eyedisp = eyeDisp;
    renderer.updateEye(0, 0, 0, 0);
  }

  void sendToNetwork() {
    // Network communication - implementation continues
  }

  // Additional methods to be implemented:
  // - readyArrows()
  // - readyCross()
  // - replacePiece()
  // - checkPenalties()
  // - performPenalties()
  // - finishGame()
  // - sendShotToNetwork()
}

