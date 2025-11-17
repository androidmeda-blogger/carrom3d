import 'game_engine.dart'; // For CarromDbAdapter

/// ScoreboardEntry - Tracks wins between two players/teams
class ScoreboardEntry {
  int team1;
  int team2;
  int wins1;
  int rwins1; // Red wins for team1
  int wins2;
  int rwins2; // Red wins for team2
  
  String team1Str = '';
  String team2Str = '';

  ScoreboardEntry(this.team1, this.team2, this.wins1, this.rwins1, this.wins2, this.rwins2);
}

/// GameConfig - 1:1 port of GameConfig.java
/// Manages game configuration, player settings, and score tracking
class GameConfig {
  static const String dbConfigKey = "configs";
  static const int defaultStartingPort = 8888; // NetworkUtils.DEFAULT_STARTING_PORT

  List<String> playerNames = [];
  List<int> playerTypes = [];
  
  List<int> player = [0, 0, 0, 0];
  
  int gamePlayerCount = 2;
  int get playerCount => gamePlayerCount; // Alias for compatibility
  CarromDbAdapter? dbAdapter;
  
  List<String> basicPlayers = [
    "Human",
    "Machine: Beginner",
    "Machine: Intermediate",
    "Machine: Expert",
    "Network",
    "Internet"
  ];
  
  // Using nested maps instead of SparseArray
  Map<int, Map<int, ScoreboardEntry>> scores = {};
  
  bool gameInProgress = false;
  bool cameraFixability = true;
  
  String remoteIp = "";
  bool isPlayingNetwork = false;
  bool isNetwokHost = false;
  bool veryFirstTime = true;
  
  int hideScoreboard = 0; // 0 for max, 1 for hide, 2 for mini
  bool hideArrow = false;
  bool lockOrientation = false;
  bool muted = false;
  
  int orientationValue = 1; // Portrait orientation
  int startingPort = defaultStartingPort;
  
  int gameId = -1;
  int score1 = 0;
  int score2 = 0;
  
  bool tableTop = false;
  int frontPlayer = 0;
  
  bool useBluetooth = false;
  String networkToken = "null";
  int guidingWidth = 20; // Default 20, max 63

  GameConfig(this.dbAdapter) {
    playerNames = [];
    playerTypes = [];
    player = List.filled(4, 0);
    
    gameInProgress = false;
    cameraFixability = true;
    veryFirstTime = true;
    gameId = -1;
    score1 = 0;
    score2 = 0;
    
    hideScoreboard = 0;
    hideArrow = false;
    lockOrientation = false;
    muted = false;
    orientationValue = 1;
    startingPort = defaultStartingPort;
    
    scores = {};
    
    tableTop = false;
    frontPlayer = 0;
    useBluetooth = false;
    networkToken = "null";
    guidingWidth = 20;
  }

  void saveConfigs() {
    String pieces = "";
    
    pieces += "${playerNames.length}";
    for (int i = 0; i < playerNames.length; i++) {
      pieces += ",${playerNames[i]}";
      pieces += ",${playerTypes[i]}";
    }
    
    pieces += ",2"; // Player count, for the time being
    pieces += ",${player[0]}";
    pieces += ",${player[1]}";
    
    List<String> scorePlayers = [];
    for (int i = 0; i < playerNames.length; i++) {
      scorePlayers.add(playerNames[i]);
    }
    for (int i = 0; i < basicPlayers.length; i++) {
      scorePlayers.add(basicPlayers[i]);
    }
    
    // Save the scores
    for (int i = 0; i < scorePlayers.length; i++) {
      for (int j = i + 1; j < scorePlayers.length; j++) {
        ScoreboardEntry entry = scores[i]![j]!;
        pieces += ",${entry.wins1}";
        pieces += ",${entry.rwins1}";
        pieces += ",${entry.wins2}";
        pieces += ",${entry.rwins2}";
      }
    }
    
    pieces += ",${gameInProgress ? "1" : "0"}";
    pieces += ",${cameraFixability ? "1" : "0"}";
    
    if (remoteIp.isEmpty) {
      remoteIp = "0.0.0.0";
    }
    pieces += ",$remoteIp";
    pieces += ",${isPlayingNetwork ? "1" : "0"}";
    pieces += ",${isNetwokHost ? "1" : "0"}";
    pieces += ",${veryFirstTime ? "1" : "0"}";
    
    pieces += ",$hideScoreboard";
    pieces += ",${hideArrow ? "1" : "0"}";
    pieces += ",${lockOrientation ? "1" : "0"}";
    pieces += ",$orientationValue";
    
    // From version 1.1
    pieces += ",${muted ? "1" : "0"}";
    pieces += ",$startingPort";
    pieces += ",$gameId";
    pieces += ",$score1";
    pieces += ",$score2";
    
    // From version 1.11
    pieces += ",${tableTop ? "1" : "0"}";
    pieces += ",$frontPlayer";
    
    // From version 1.12
    pieces += ",${useBluetooth ? "1" : "0"}";
    pieces += ",$networkToken";
    pieces += ",$guidingWidth";
    
    dbAdapter?.addValue(dbConfigKey, pieces);
  }

  void loadConfigs() {
    String pieces = "";
    try {
      pieces = dbAdapter?.getValue(dbConfigKey) ?? "";
    } catch (e) {
      // Ignore errors
    }
    
    if (pieces.isEmpty) {
      startupDefaultConfigs();
      return;
    }
    
    int j = 0;
    List<String> items = pieces.split(",");
    
    int playerCount = int.parse(items[j++]);
    for (int i = 0; i < playerCount; i++) {
      playerNames.add(items[j++]);
      playerTypes.add(int.parse(items[j++]));
    }
    
    gamePlayerCount = int.parse(items[j++]);
    
    player[0] = int.parse(items[j++]);
    player[1] = int.parse(items[j++]);
    
    // Load the scores
    List<String> scorePlayers = [];
    for (int i = 0; i < playerNames.length; i++) {
      scorePlayers.add(playerNames[i]);
    }
    for (int i = 0; i < basicPlayers.length; i++) {
      scorePlayers.add(basicPlayers[i]);
    }
    
    for (int i = 0; i < scorePlayers.length; i++) {
      Map<int, ScoreboardEntry> row = {};
      for (int k = i + 1; k < scorePlayers.length; k++) {
        int wins1 = int.parse(items[j++]);
        int rwins1 = int.parse(items[j++]);
        int wins2 = int.parse(items[j++]);
        int rwins2 = int.parse(items[j++]);
        ScoreboardEntry entry = ScoreboardEntry(i, k, wins1, rwins1, wins2, rwins2);
        
        row[k] = entry;
      }
      scores[i] = row;
    }
    
    gameInProgress = items[j++] == "1";
    cameraFixability = items[j++] == "1";
    
    remoteIp = items[j++];
    isPlayingNetwork = items[j++] == "1";
    isNetwokHost = items[j++] == "1";
    veryFirstTime = items[j++] == "1";
    
    hideScoreboard = int.parse(items[j++]);
    hideArrow = items[j++] == "1";
    lockOrientation = items[j++] == "1";
    orientationValue = int.parse(items[j++]);
    
    // For version 1.1
    try {
      if (j < items.length) {
        muted = items[j++] == "1";
        startingPort = int.parse(items[j++]);
        gameId = int.parse(items[j++]);
        score1 = int.parse(items[j++]);
        score2 = int.parse(items[j++]);
      }
    } catch (e) {
      // Ignore errors
    }
    
    // For version 1.11
    try {
      if (j < items.length) {
        tableTop = items[j++] == "1";
        frontPlayer = int.parse(items[j++]);
      }
    } catch (e) {
      // Ignore errors
    }
    
    // For version 1.12
    try {
      if (j < items.length) {
        useBluetooth = items[j++] == "1";
        networkToken = items[j++];
        guidingWidth = int.parse(items[j++]);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  void startupDefaultConfigs() {
    playerNames.clear();
    playerTypes.clear();
    loadDefaultConfigs();
    
    for (int i = 0; i < basicPlayers.length; i++) {
      Map<int, ScoreboardEntry> row = {};
      for (int k = i + 1; k < basicPlayers.length; k++) {
        ScoreboardEntry entry = ScoreboardEntry(i, k, 0, 0, 0, 0);
        row[k] = entry;
      }
      scores[i] = row;
    }
    
    remoteIp = "";
    isPlayingNetwork = false;
    isNetwokHost = false;
    veryFirstTime = true;
    cameraFixability = true;
    
    hideScoreboard = 0;
    hideArrow = false;
    lockOrientation = false;
    muted = false;
    orientationValue = 1;
    startingPort = defaultStartingPort;
    
    gameId = -1;
    score1 = 0;
    score2 = 0;
    
    tableTop = false;
    frontPlayer = 0;
    useBluetooth = false;
    networkToken = "null";
    guidingWidth = 20;
  }

  void loadDefaultConfigs() {
    player[0] = -1;
    player[1] = -2;
  }

  String getPlayerName(int i) {
    if (player[i] >= 0) {
      return playerNames[player[i]];
    } else {
      return basicPlayers[-(player[i] + 1)];
    }
  }

  int getPlayerType(int i) {
    if (player[i] >= 0) {
      return playerTypes[player[i]];
    } else {
      return -(player[i] + 1);
    }
  }

  bool addPlayer(String name, int type) {
    name = name.replaceAll(",", "-");
    for (int i = 0; i < playerNames.length; i++) {
      if (name == playerNames[i]) {
        return false;
      }
    }
    
    List<String> scorePlayers = [];
    for (int i = 0; i < playerNames.length; i++) {
      scorePlayers.add(playerNames[i]);
    }
    for (int i = 0; i < basicPlayers.length; i++) {
      scorePlayers.add(basicPlayers[i]);
    }
    
    int playerId = playerNames.length;
    
    // Move the records greater than playerId
    for (int i = 0; i < playerId; i++) {
      Map<int, ScoreboardEntry> replacingRow = scores[i]!;
      for (int j = scorePlayers.length - 1; j > i + 1; j--) {
        if (j >= playerId) {
          ScoreboardEntry replacingEntry = replacingRow[j]!;
          replacingEntry.team2 = j + 1;
          replacingRow[j + 1] = replacingEntry;
        }
      }
      // Add a new entry here
      ScoreboardEntry entry = ScoreboardEntry(i, playerId, 0, 0, 0, 0);
      replacingRow[playerId] = entry;
    }
    
    for (int i = playerId; i < scorePlayers.length; i++) {
      Map<int, ScoreboardEntry> replacingRow = scores[i]!;
      
      for (int j = scorePlayers.length - 1; j > i + 1; j--) {
        ScoreboardEntry replacingEntry = replacingRow[j]!;
        replacingEntry.team1 = i + 1;
        replacingEntry.team2 = j + 1;
        replacingRow[j + 1] = replacingEntry;
      }
      scores[i + 1] = replacingRow;
    }
    
    Map<int, ScoreboardEntry> newRow = {};
    
    // Add the new player to the scores to the lower players
    for (int i = playerId + 1; i < scorePlayers.length + 1; i++) {
      ScoreboardEntry entry = ScoreboardEntry(playerId, i, 0, 0, 0, 0);
      newRow[i] = entry;
    }
    scores[playerId] = newRow;
    
    playerNames.add(name);
    playerTypes.add(type);
    
    return true;
  }

  bool updatePlayer(int i, String name, int type) {
    for (int j = 0; j < playerNames.length; j++) {
      if (i != j && name == playerNames[j]) {
        return false;
      }
    }
    
    playerNames[i] = name;
    playerTypes[i] = type;
    
    return true;
  }

  void deletePlayer(int id) {
    // Remove the scores from the scores array
    List<String> scorePlayers = [];
    for (int i = 0; i < playerNames.length; i++) {
      scorePlayers.add(playerNames[i]);
    }
    for (int i = 0; i < basicPlayers.length; i++) {
      scorePlayers.add(basicPlayers[i]);
    }
    
    for (int i = 0; i < id; i++) {
      Map<int, ScoreboardEntry> replacingRow = scores[i]!;
      for (int j = i + 1; j < scorePlayers.length - 1; j++) {
        if (j >= id) {
          ScoreboardEntry replacingEntry = replacingRow[j + 1]!;
          replacingEntry.team2 = j;
          replacingRow[j] = replacingEntry;
        }
      }
      replacingRow.remove(scorePlayers.length - 1);
    }
    
    for (int i = id; i < scorePlayers.length - 1; i++) {
      Map<int, ScoreboardEntry> replacingRow = scores[i + 1]!;
      
      for (int j = i + 1; j < scorePlayers.length - 1; j++) {
        ScoreboardEntry replacingEntry = replacingRow[j + 1]!;
        replacingEntry.team1 = i;
        replacingEntry.team2 = j;
        replacingRow[j] = replacingEntry;
      }
      
      scores[i] = replacingRow;
    }
    scores.remove(scorePlayers.length - 1);
    
    playerNames.removeAt(id);
    playerTypes.removeAt(id);
  }

  // red can be 0- team1, 1-team2, 2-non
  void addGame(int team1, int team2, bool team1won, int red) {
    if (team1 < 0) {
      team1 = playerNames.length - (team1 + 1);
    }
    if (team2 < 0) {
      team2 = playerNames.length - (team2 + 1);
    }
    if (team1 > team2) {
      // Swap
      int tmp = team2;
      team2 = team1;
      team1 = tmp;
      team1won = !team1won;
      
      if (red == 0) {
        red = 1;
      } else if (red == 1) {
        red = 0;
      }
    }
    
    ScoreboardEntry entry = scores[team1]![team2]!;
    if (team1won) {
      entry.wins1++;
      
      if (red == 0) {
        entry.rwins1++;
      }
    } else {
      entry.wins2++;
      
      if (red == 1) {
        entry.rwins2++;
      }
    }
  }

  List<ScoreboardEntry> getScores() {
    List<ScoreboardEntry> entries = [];
    
    List<String> scorePlayers = [];
    for (int i = 0; i < playerNames.length; i++) {
      scorePlayers.add(playerNames[i]);
    }
    for (int i = 0; i < basicPlayers.length; i++) {
      scorePlayers.add(basicPlayers[i]);
    }
    
    for (int i = 0; i < scorePlayers.length; i++) {
      for (int j = i + 1; j < scorePlayers.length; j++) {
        ScoreboardEntry entry = scores[i]![j]!;
        
        if (entry.wins1 == 0 && entry.wins2 == 0) {
          continue;
        }
        entry.team1Str = scorePlayers[i];
        entry.team2Str = scorePlayers[j];
        entries.add(entry);
      }
    }
    return entries;
  }
}

