import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_app_bar.dart';

class HostView extends ConsumerStatefulWidget {
  const HostView({super.key});

  @override
  ConsumerState<HostView> createState() => _HostViewState();
}

class _HostViewState extends ConsumerState<HostView> {
  final List<TextEditingController> _nameControllers =
      List.generate(4, (_) => TextEditingController());

  @override
  void dispose() {
    for (var c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _initGame() {
    ref.read(firestoreServiceProvider).initializeGame();
    for (int i = 0; i < 4; i++) {
      if (_nameControllers[i].text.isNotEmpty) {
        ref
            .read(firestoreServiceProvider)
            .setPlayerName(i + 1, _nameControllers[i].text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeSessionStreamProvider);
    final questionsAsync = ref.watch(questionsStreamProvider);

    return Scaffold(
      appBar: BrandAppBar(
        pageTitle: 'Host Board',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.red),
            onPressed: () {
              ref.read(firestoreServiceProvider).clearRoom();
            },
            tooltip: 'Clear Room',
          ),
        ],
      ),
      body: sessionAsync.when(
        data: (session) {
          if (session == null || session.roomState.status == 'lobby') {
            return _buildLobby(session);
          }

          // Game over state — no need to load questions
          if (session.roomState.status == 'game_over') {
            return _buildGameFinished(session);
          }

          return questionsAsync.when(
            data: (questions) {
              if (questions.isEmpty) {
                return const Center(
                    child:
                        Text('No questions available. Go to Admin Panel.'));
              }
              final currentQIndex = session.roomState.currentQuestionIndex;
              if (currentQIndex >= questions.length) {
                return _buildGameFinished(session);
              }
              return _buildGameBoard(
                  session, questions[currentQIndex], questions.length);
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LOBBY
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildLobby(SessionState? session) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Lobby Setup',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  ...List.generate(4, (index) {
                    final slot = index + 1;
                    final isConnected = session?.players[slot] != null;
                    final playerName =
                        session?.players[slot]?.name ?? '';

                    if (isConnected &&
                        _nameControllers[index].text.isEmpty) {
                      _nameControllers[index].text = playerName;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? AppTheme.correctState
                                  : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                                child: Text('$slot',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _nameControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Player $slot Name',
                                enabled: !isConnected,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _initGame,
                      child: const Text('INITIALIZE / UPDATE GAME'),
                    ),
                  ),
                  if (session != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          ref
                              .read(firestoreServiceProvider)
                              .displayQuestion(0);
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.correctState),
                        child: const Text('START FIRST QUESTION'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GAME BOARD — viewport-fit, zero scroll
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildGameBoard(
      SessionState session, Question question, int totalQuestions) {
    final rs = session.roomState;
    final activeSlot = rs.activePlayerSlot;
    final isLocked = rs.buzzLocked;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vw = constraints.maxWidth;
          final vh = constraints.maxHeight;
          final isCompact = vw < 700;
          final pad = isCompact ? 12.0 : 20.0;

          // Responsive font sizes
          final qFontSize = (vh * 0.05).clamp(18.0, 36.0);
          final optFontSize = (vh * 0.028).clamp(14.0, 22.0);
          final scoreFontSize = (vh * 0.03).clamp(14.0, 22.0);
          final nameFontSize = (vh * 0.025).clamp(12.0, 18.0);

          return Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              children: [
                // ── Player Leaderboard Strip ──────────────────────────
                _buildLeaderboardStrip(
                  session,
                  activeSlot,
                  nameFontSize: nameFontSize,
                  scoreFontSize: scoreFontSize,
                ),

                SizedBox(height: pad * 0.5),

                // ── Question Card (takes remaining space) ────────────
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(isCompact ? 12 : 20),
                      child: Column(
                        children: [
                          // Question counter
                          Text(
                            'Question ${rs.currentQuestionIndex + 1} of $totalQuestions',
                            style: TextStyle(
                                color: Colors.grey, fontSize: optFontSize * 0.8),
                          ),
                          SizedBox(height: pad * 0.4),

                          // Question text — scales to fit
                          Expanded(
                            flex: isLocked && activeSlot != null ? 2 : 5,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: ConstrainedBox(
                                  constraints:
                                      BoxConstraints(maxWidth: vw * 0.85),
                                  child: Text(
                                    question.question,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: qFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ── Options (only when a player has buzzed) ──
                          if (isLocked && activeSlot != null)
                            Expanded(
                              flex: 3,
                              child: _buildOptionsGrid(
                                question,
                                rs,
                                optFontSize,
                                vw,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: pad * 0.5),

                // ── Host Controls (pinned to bottom) ─────────────────
                _buildControlBar(rs, session, question, totalQuestions,
                    activeSlot, isCompact),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Leaderboard row ────────────────────────────────────────────────────
  Widget _buildLeaderboardStrip(
    SessionState session,
    int? activeSlot, {
    required double nameFontSize,
    required double scoreFontSize,
  }) {
    return Row(
      children: List.generate(4, (index) {
        final slot = index + 1;
        final p = session.players[slot];
        final isActive = activeSlot == slot;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.buzzerAccent.withOpacity(0.25)
                  : AppTheme.surface,
              border: Border.all(
                color: isActive
                    ? AppTheme.buzzerAccent
                    : AppTheme.subtleBorder,
                width: isActive ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    p?.name ?? 'Slot $slot',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: nameFontSize),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${p?.score ?? 0} pts',
                    style: TextStyle(
                        fontSize: scoreFontSize,
                        color: Colors.greenAccent),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Options grid (inside the question card) ────────────────────────────
  Widget _buildOptionsGrid(
    Question question,
    RoomState rs,
    double fontSize,
    double viewportWidth,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(question.options.length, (idx) {
            final isAnswered = rs.answeredOptionIndex != null;
            final isSelected = rs.answeredOptionIndex == idx;
            final isCorrect = question.correctAnswerIndex == idx;

            Color bgColor = AppTheme.surface;
            if (isAnswered) {
              if (isCorrect) {
                bgColor = AppTheme.correctState.withOpacity(0.45);
              } else if (isSelected) {
                bgColor = AppTheme.incorrectState.withOpacity(0.45);
              }
            } else if (isSelected) {
              bgColor = AppTheme.buzzerAccent.withOpacity(0.4);
            }

            return Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.subtleBorder),
                ),
                child: Row(
                  children: [
                    Text(
                      '${String.fromCharCode(65 + idx)}.',
                      style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        question.options[idx],
                        style: TextStyle(fontSize: fontSize),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    if (isAnswered && isCorrect)
                      Icon(Icons.check_circle,
                          color: AppTheme.correctState,
                          size: fontSize * 1.3),
                    if (isAnswered && isSelected && !isCorrect)
                      Icon(Icons.cancel,
                          color: AppTheme.incorrectState,
                          size: fontSize * 1.3),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Host control bar ───────────────────────────────────────────────────
  Widget _buildControlBar(
    RoomState rs,
    SessionState session,
    Question question,
    int totalQuestions,
    int? activeSlot,
    bool isCompact,
  ) {
    final btnStyle = ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 18,
          vertical: isCompact ? 8 : 12),
      textStyle: TextStyle(fontSize: isCompact ? 13 : 15),
    );

    final isLastQuestion = rs.currentQuestionIndex >= totalQuestions - 1;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (rs.status == 'answered' || rs.status == 'player_buzzed')
          ElevatedButton(
            onPressed: () {
              ref.read(firestoreServiceProvider).resetBuzz();
            },
            style: btnStyle,
            child: const Text('RESET BUZZ'),
          ),
        ElevatedButton.icon(
          onPressed: rs.currentQuestionIndex > 0
              ? () {
                  ref
                      .read(firestoreServiceProvider)
                      .displayQuestion(rs.currentQuestionIndex - 1);
                }
              : null,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(isCompact ? 'PREV' : 'PREV QUESTION'),
          style: btnStyle,
        ),
        if (isLastQuestion)
          ElevatedButton.icon(
            onPressed: () {
              ref.read(firestoreServiceProvider).endGame();
            },
            icon: const Icon(Icons.emoji_events, size: 18),
            label: Text(isCompact ? 'END' : 'END GAME'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.correctState,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 18,
                  vertical: isCompact ? 8 : 12),
              textStyle: TextStyle(fontSize: isCompact ? 13 : 15, fontWeight: FontWeight.bold),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: () {
              ref
                  .read(firestoreServiceProvider)
                  .displayQuestion(rs.currentQuestionIndex + 1);
            },
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(isCompact ? 'NEXT' : 'NEXT QUESTION'),
            style: btnStyle,
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GAME FINISHED — scoreboard
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildGameFinished(SessionState session) {
    // Sort players by score descending
    final sorted = session.players.entries.toList()
      ..sort((a, b) => b.value.score.compareTo(a.value.score));

    final medals = ['🥇', '🥈', '🥉'];
    final medalColors = [
      const Color(0xFFFFD700), // gold
      const Color(0xFFC0C0C0), // silver
      const Color(0xFFCD7F32), // bronze
    ];

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Trophy header ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2A1F0A),
                        Color(0xFF1E2530),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.buzzerAccent.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.buzzerAccent.withOpacity(0.15),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 8),
                      Text(
                        'GAME OVER',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.buzzerAccent,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Final Scoreboard',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white60,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Player ranking cards ────────────────────────────────
                ...sorted.asMap().entries.map((entry) {
                  final rank = entry.key;
                  final slot = entry.value.key;
                  final player = entry.value.value;
                  final hasMedal = rank < 3;
                  final medalColor =
                      hasMedal ? medalColors[rank] : Colors.white30;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: rank == 0
                          ? const Color(0xFF2A2210)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasMedal
                            ? medalColor.withOpacity(0.5)
                            : AppTheme.subtleBorder,
                        width: rank == 0 ? 1.5 : 1,
                      ),
                      boxShadow: rank == 0
                          ? [
                              BoxShadow(
                                color:
                                    const Color(0xFFFFD700).withOpacity(0.08),
                                blurRadius: 16,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Rank badge
                        SizedBox(
                          width: 44,
                          child: Center(
                            child: hasMedal
                                ? Text(medals[rank],
                                    style: const TextStyle(fontSize: 28))
                                : Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${rank + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white54,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.name.isNotEmpty
                                    ? player.name
                                    : 'Slot $slot',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: rank == 0
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: rank == 0
                                      ? const Color(0xFFFFD700)
                                      : Colors.white,
                                ),
                              ),
                              if (rank == 0)
                                const Text(
                                  'Winner! 🎉',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFFFD700),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Score
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: hasMedal
                                ? medalColor.withOpacity(0.12)
                                : AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: hasMedal
                                  ? medalColor.withOpacity(0.4)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '${player.score} pts',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: hasMedal ? medalColor : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 28),

                // ── Action buttons ──────────────────────────────────────
                Row(
                  children: [
                    // Replay
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref.read(firestoreServiceProvider).initializeGame();
                          },
                          icon: const Icon(Icons.replay, size: 20),
                          label: const Text('PLAY AGAIN'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.correctState,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Exit to lobby
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.home_outlined, size: 20),
                        label: const Text('HOME'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
}
