import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final DateTime? createdAt;

  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    this.createdAt,
  });

  factory Question.fromMap(String id, Map<String, dynamic> map) {
    return Question(
      id: id,
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctAnswerIndex: map['correctAnswerIndex'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}

class PlayerState {
  final String name;
  final int score;
  final bool connected;

  PlayerState({
    required this.name,
    required this.score,
    required this.connected,
  });

  factory PlayerState.fromMap(Map<String, dynamic> map) {
    return PlayerState(
      name: map['name'] ?? '',
      score: map['score'] ?? 0,
      connected: map['connected'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'score': score,
      'connected': connected,
    };
  }
}

class RoomState {
  final String status; // 'lobby', 'question_displayed', 'player_buzzed', 'answered'
  final int currentQuestionIndex;
  final int? activePlayerSlot; // 1-4
  final bool buzzLocked;
  final DateTime? timestamp;
  final int? answeredOptionIndex;

  RoomState({
    required this.status,
    required this.currentQuestionIndex,
    this.activePlayerSlot,
    required this.buzzLocked,
    this.timestamp,
    this.answeredOptionIndex,
  });

  factory RoomState.fromMap(Map<String, dynamic> map) {
    return RoomState(
      status: map['status'] ?? 'lobby',
      currentQuestionIndex: map['currentQuestionIndex'] ?? 0,
      activePlayerSlot: map['activePlayerSlot'],
      buzzLocked: map['buzzLocked'] ?? true,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
      answeredOptionIndex: map['answeredOptionIndex'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'currentQuestionIndex': currentQuestionIndex,
      'activePlayerSlot': activePlayerSlot,
      'buzzLocked': buzzLocked,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
      'answeredOptionIndex': answeredOptionIndex,
    };
  }
}

class SessionState {
  final RoomState roomState;
  final Map<int, PlayerState> players;

  SessionState({
    required this.roomState,
    required this.players,
  });

  factory SessionState.fromMap(Map<String, dynamic> map) {
    final Map<int, PlayerState> playersMap = {};
    if (map['players'] != null) {
      final playersData = map['players'] as Map<String, dynamic>;
      playersData.forEach((key, value) {
        if (key.startsWith('player_')) {
          final slot = int.tryParse(key.split('_')[1]);
          if (slot != null) {
            playersMap[slot] = PlayerState.fromMap(value as Map<String, dynamic>);
          }
        }
      });
    }

    return SessionState(
      roomState: RoomState.fromMap(map['room_state'] ?? {}),
      players: playersMap,
    );
  }
}
