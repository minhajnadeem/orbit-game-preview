import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

final firestoreServiceProvider = Provider((ref) => FirestoreService());

final questionsStreamProvider = StreamProvider<List<Question>>((ref) {
  return ref.read(firestoreServiceProvider).getQuestions();
});

final activeSessionStreamProvider = StreamProvider<SessionState?>((ref) {
  return ref.read(firestoreServiceProvider).getActiveSession();
});

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Questions
  Stream<List<Question>> getQuestions() {
    return _db.collection('questions').orderBy('createdAt', descending: false).snapshots().map(
      (snapshot) => snapshot.docs.map(
        (doc) => Question.fromMap(doc.id, doc.data()),
      ).toList(),
    );
  }

  Future<void> addQuestion(Question question) async {
    await _db.collection('questions').add(question.toMap());
  }

  Future<void> updateQuestion(Question question) async {
    await _db.collection('questions').doc(question.id).update(question.toMap());
  }

  Future<void> deleteQuestion(String id) async {
    await _db.collection('questions').doc(id).delete();
  }

  Future<void> clearAllQuestions() async {
    final snapshot = await _db.collection('questions').get();
    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Session
  Stream<SessionState?> getActiveSession() {
    return _db.collection('sessions').doc('active_game').snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return SessionState.fromMap(doc.data()!);
    });
  }

  Future<void> initializeGame() async {
    await _db.collection('sessions').doc('active_game').set({
      'room_state': {
        'status': 'lobby',
        'currentQuestionIndex': 0,
        'activePlayerSlot': null,
        'buzzLocked': true,
        'timestamp': FieldValue.serverTimestamp(),
      },
      'players': {},
    }, SetOptions(merge: true));
  }

  Future<void> setPlayerName(int slot, String name) async {
    await _db.collection('sessions').doc('active_game').set({
      'players': {
        'player_$slot': {
          'name': name,
          'score': 0,
          'connected': true,
        }
      }
    }, SetOptions(merge: true));
  }
  
  Future<void> updatePlayerScore(int slot, int newScore) async {
    await _db.collection('sessions').doc('active_game').set({
      'players': {
        'player_$slot': {
          'score': newScore,
        }
      }
    }, SetOptions(merge: true));
  }

  Future<void> displayQuestion(int index) async {
    await _db.collection('sessions').doc('active_game').set({
      'room_state': {
        'status': 'question_displayed',
        'currentQuestionIndex': index,
        'activePlayerSlot': null,
        'buzzLocked': false,
        'timestamp': FieldValue.serverTimestamp(),
        'answeredOptionIndex': null,
      }
    }, SetOptions(merge: true));
  }

  Future<void> submitBuzz(int slot) async {
    final docRef = _db.collection('sessions').doc('active_game');
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      
      final roomState = snapshot.data()?['room_state'] ?? {};
      final isLocked = roomState['buzzLocked'] ?? true;
      
      if (!isLocked) {
        transaction.update(docRef, {
          'room_state.buzzLocked': true,
          'room_state.activePlayerSlot': slot,
          'room_state.status': 'player_buzzed',
          'room_state.timestamp': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> submitAnswer(int slot, int optionIndex, String questionId) async {
    final sessionRef = _db.collection('sessions').doc('active_game');
    final questionRef = _db.collection('questions').doc(questionId);

    await _db.runTransaction((transaction) async {
      // 1. Read the question to get the correct answer
      final questionSnap = await transaction.get(questionRef);
      if (!questionSnap.exists) return;
      final correctIndex = questionSnap.data()?['correctAnswerIndex'] ?? -1;

      // 2. Read the current player score
      final sessionSnap = await transaction.get(sessionRef);
      if (!sessionSnap.exists) return;
      final currentScore =
          sessionSnap.data()?['players']?['player_$slot']?['score'] ?? 0;

      // 3. Compute score change
      final isCorrect = optionIndex == correctIndex;
      final newScore = currentScore + (isCorrect ? 10 : -10);

      // 4. Atomically update score + room state
      transaction.update(sessionRef, {
        'room_state.status': 'answered',
        'room_state.answeredOptionIndex': optionIndex,
        'room_state.timestamp': FieldValue.serverTimestamp(),
        'players.player_$slot.score': newScore,
      });
    });
  }

  Future<void> endGame() async {
    await _db.collection('sessions').doc('active_game').set({
      'room_state': {
        'status': 'game_over',
        'buzzLocked': true,
        'timestamp': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> clearRoom() async {
    await _db.collection('sessions').doc('active_game').delete();
  }
  
  Future<void> resetBuzz() async {
    await _db.collection('sessions').doc('active_game').set({
      'room_state': {
        'status': 'question_displayed',
        'activePlayerSlot': null,
        'buzzLocked': false,
        'answeredOptionIndex': null,
        'timestamp': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }
}
