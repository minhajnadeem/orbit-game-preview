import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_app_bar.dart';

class PlayerView extends ConsumerWidget {
  final int? slot;
  const PlayerView({super.key, this.slot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (slot == null) {
      return const _PlayerSetupView();
    }

    return _PlayerGameView(slot: slot!);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SETUP VIEW
// ═════════════════════════════════════════════════════════════════════════════
class _PlayerSetupView extends ConsumerStatefulWidget {
  const _PlayerSetupView();

  @override
  ConsumerState<_PlayerSetupView> createState() => _PlayerSetupViewState();
}

class _PlayerSetupViewState extends ConsumerState<_PlayerSetupView> {
  final _nameController = TextEditingController();
  int? _selectedSlot;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _claimSlot() {
    if (_nameController.text.isEmpty || _selectedSlot == null) return;
    ref
        .read(firestoreServiceProvider)
        .setPlayerName(_selectedSlot!, _nameController.text);
    context.go('/player?slot=$_selectedSlot');
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeSessionStreamProvider);

    return Scaffold(
      appBar: BrandAppBar(
        pageTitle: 'Player Setup',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: sessionAsync.when(
            data: (session) {
              if (session == null) {
                return const Text('Waiting for Host to initialize game...');
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Select Your Slot',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          ...List.generate(4, (index) {
                            final s = index + 1;
                            final p = session.players[s];
                            final isAvailable =
                                p == null || p.name.isEmpty;

                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 10.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    if (_selectedSlot != s) {
                                      _selectedSlot = s;
                                      if (!isAvailable) {
                                        _nameController.text = p.name;
                                      } else {
                                        _nameController.clear();
                                      }
                                    }
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedSlot == s
                                      ? AppTheme.buzzerAccent
                                      : AppTheme.surface,
                                  side: BorderSide(
                                      color: _selectedSlot == s
                                          ? AppTheme.surface
                                          : AppTheme.buzzerAccent),
                                  minimumSize:
                                      const Size.fromHeight(52),
                                ),
                                child: Text(isAvailable
                                    ? 'Slot $s (Available)'
                                    : 'Slot $s (${p.name})'),
                              ),
                            );
                          }),
                          if (_selectedSlot != null) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                  labelText: 'Enter Your Name'),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _claimSlot,
                              style: ElevatedButton.styleFrom(
                                  minimumSize:
                                      const Size.fromHeight(52)),
                              child: const Text('JOIN GAME'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, st) => Text('Error: $e'),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GAME VIEW — viewport-fit, zero scroll
// ═════════════════════════════════════════════════════════════════════════════
class _PlayerGameView extends ConsumerStatefulWidget {
  final int slot;
  const _PlayerGameView({required this.slot});

  @override
  ConsumerState<_PlayerGameView> createState() => _PlayerGameViewState();
}

class _PlayerGameViewState extends ConsumerState<_PlayerGameView> {
  bool _isProcessingBuzz = false;
  int? _selectedAnswerIndex;
  bool _isSubmittingAnswer = false;
  // Tracks the last seen question index so we can detect when the host
  // advances to a new question and auto-reset all local UI state.
  int? _lastQuestionIndex;

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeSessionStreamProvider);
    final questionsAsync = ref.watch(questionsStreamProvider);

    // ── Stream listener: auto-reset local state ──────────────────────────
    // This is the single source of truth for resetting UI state.
    // We never rely on the async callback after submitBuzz() — the stream
    // drives everything, which is race-condition-free.
    ref.listen<AsyncValue<SessionState?>>(activeSessionStreamProvider,
        (prev, next) {
      next.whenData((session) {
        if (session == null) return;
        final qIndex = session.roomState.currentQuestionIndex;
        final isLocked = session.roomState.buzzLocked;

        // Case A: Host moved to a new question → full local reset
        if (_lastQuestionIndex != null && _lastQuestionIndex != qIndex) {
          if (mounted) {
            setState(() {
              _isProcessingBuzz = false;
              _selectedAnswerIndex = null;
              _isSubmittingAnswer = false;
            });
          }
        }

        // Case B: Host reset the buzz (lock released) → clear processing flag
        // This covers the "Reset Buzz" button on the host screen.
        if (!isLocked && _isProcessingBuzz) {
          if (mounted) {
            setState(() {
              _isProcessingBuzz = false;
            });
          }
        }

        _lastQuestionIndex = qIndex;
      });
    });

    return Scaffold(
      appBar: BrandAppBar(centerTitle: true),
      body: SafeArea(
        child: sessionAsync.when(
          data: (session) {
            if (session == null) {
              return const Center(child: Text('Waiting for game...'));
            }

            final rs = session.roomState;
            final p = session.players[widget.slot];
            if (p == null) {
              return const Center(child: Text('Slot not configured.'));
            }

            final isActive = rs.activePlayerSlot == widget.slot;
            final someoneElseActive =
                rs.activePlayerSlot != null && !isActive;

            if (rs.status == 'question_displayed' ||
                rs.status == 'player_buzzed' ||
                rs.status == 'answered') {
              if (isActive && rs.status == 'player_buzzed') {
                return questionsAsync.when(
                  data: (questions) {
                    if (rs.currentQuestionIndex < questions.length) {
                      return _buildAnswerPhase(
                          questions[rs.currentQuestionIndex], session);
                    }
                    return const Center(child: Text('Invalid Question'));
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                );
              } else if (isActive && rs.status == 'answered') {
                return const Center(
                    child: Text(
                        'Answer Submitted!\nLook at the Host screen.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 22, color: Colors.grey)));
              } else {
                return _buildBuzzerPhase(
                    session, isActive, someoneElseActive, p);
              }
            }

            return Center(
                child: Text('Waiting... (${p.name})',
                    style: const TextStyle(
                        fontSize: 22, color: Colors.grey)));
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  // ── BUZZER PHASE — viewport-fit ────────────────────────────────────────
  Widget _buildBuzzerPhase(
    SessionState session,
    bool isActive,
    bool someoneElseActive,
    PlayerState p,
  ) {
    final isLocked = session.roomState.buzzLocked;

    // ── Priority chain (most authoritative → least) ──────────────────────
    // Server-confirmed states always take precedence over local optimistic state.
    // This prevents any flicker or incorrect color when the stream arrives.
    final Color buzzerColor;
    final String buzzerText;

    if (isActive) {
      // ✅ Server confirmed: this player won the buzz race
      buzzerColor = AppTheme.correctState;
      buzzerText = 'YOU BUZZED!';
    } else if (someoneElseActive) {
      // ❌ Server confirmed: another player was faster
      buzzerColor = AppTheme.incorrectState;
      buzzerText = 'LOCKED OUT';
    } else if (_isProcessingBuzz) {
      // ⏳ Local optimistic: tap sent to Firestore, awaiting server round-trip.
      // Distinct amber color so players know their tap registered.
      buzzerColor = Colors.amber.shade600;
      buzzerText = 'BUZZING...';
    } else if (!isLocked) {
      // 🟢 Ready: question is live, buzz is open
      buzzerColor = AppTheme.buzzerAccent;
      buzzerText = 'BUZZ!';
    } else {
      // ⚪ Locked: no active player yet (transitional / lobby state)
      buzzerColor = Colors.grey;
      buzzerText = 'WAITING';
    }

    // Button is interactive only when unlocked AND not already processing.
    final canBuzz = !isLocked && !_isProcessingBuzz;

    return LayoutBuilder(
      builder: (context, constraints) {
        final vw = constraints.maxWidth;
        final vh = constraints.maxHeight;
        final buzzerSize =
            (vh * 0.45).clamp(120.0, vw * 0.7).clamp(120.0, 340.0);
        final nameFontSize = (vh * 0.04).clamp(16.0, 32.0);
        final scoreFontSize = (vh * 0.03).clamp(14.0, 24.0);
        final buzzerFontSize = (buzzerSize * 0.16).clamp(16.0, 44.0);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: vh * 0.04),
                Text(p.name,
                    style: TextStyle(
                        fontSize: nameFontSize,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Score: ${p.score}',
                    style: TextStyle(
                        fontSize: scoreFontSize,
                        color: Colors.greenAccent)),
                const Spacer(),
                // AbsorbPointer is the outer gate: it swallows ALL touch events
                // the instant the player taps, before the widget tree can rebuild.
                // GestureDetector's onTap:null alone is not sufficient because
                // Flutter may process extra pointer events before setState runs.
                AbsorbPointer(
                  absorbing: !canBuzz,
                  child: GestureDetector(
                    onTap: canBuzz
                        ? () async {
                            HapticFeedback.heavyImpact();
                            setState(() {
                              _isProcessingBuzz = true;
                            });
                            await ref
                                .read(firestoreServiceProvider)
                                .submitBuzz(widget.slot);
                            // ⚠️  Do NOT reset _isProcessingBuzz here.
                            // The ref.listen stream callback is the single place
                            // that clears this flag — either on question change
                            // or when the host resets the buzz lock.
                            // Resetting here would re-enable the button during
                            // the Firestore → stream propagation window.
                          }
                        : null,
                    child: _PulsingBuzzer(
                      isReady: canBuzz,
                      size: buzzerSize,
                      color: buzzerColor,
                      text: buzzerText,
                      fontSize: buzzerFontSize,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── ANSWER PHASE — viewport-fit ────────────────────────────────────────
  Widget _buildAnswerPhase(
    Question question,
    SessionState session,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vh = constraints.maxHeight;
        final headerFontSize = (vh * 0.04).clamp(16.0, 28.0);
        final optFontSize = (vh * 0.03).clamp(14.0, 22.0);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'SELECT YOUR ANSWER',
                      style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                  SizedBox(height: vh * 0.02),
                  // Options — evenly distributed
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(question.options.length, (idx) {
                        final isSelected = _selectedAnswerIndex == idx;
                        final isDisabled = _isSubmittingAnswer && !isSelected;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: SizedBox(
                              width: double.infinity,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.buzzerAccent
                                                .withOpacity(0.5),
                                            blurRadius: 16,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isSubmittingAnswer
                                      ? null
                                      : () async {
                                          HapticFeedback.heavyImpact();
                                          setState(() {
                                            _selectedAnswerIndex = idx;
                                            _isSubmittingAnswer = true;
                                          });
                                          await ref
                                              .read(firestoreServiceProvider)
                                              .submitAnswer(
                                                  widget.slot, idx, question.id);
                                          if (mounted) {
                                            setState(() {
                                              _isSubmittingAnswer = false;
                                              _selectedAnswerIndex = null;
                                            });
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected
                                        ? AppTheme.buzzerAccent.withOpacity(0.3)
                                        : AppTheme.surface,
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppTheme.buzzerAccent
                                          : isDisabled
                                              ? Colors.grey.shade700
                                              : AppTheme.buzzerAccent,
                                      width: isSelected ? 2.5 : 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    disabledBackgroundColor: isSelected
                                        ? AppTheme.buzzerAccent.withOpacity(0.3)
                                        : AppTheme.surface.withOpacity(0.4),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected && _isSubmittingAnswer) ...[
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        Text(
                                          '${String.fromCharCode(65 + idx)}. ${question.options[idx]}',
                                          style: TextStyle(
                                            fontSize: optFontSize,
                                            color: isDisabled
                                                ? Colors.grey.shade600
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STATIC BUZZER WIDGET
// ═════════════════════════════════════════════════════════════════════════════
class _PulsingBuzzer extends StatelessWidget {
  final bool isReady;
  final double size;
  final Color color;
  final String text;
  final double fontSize;

  const _PulsingBuzzer({
    required this.isReady,
    required this.size,
    required this.color,
    required this.text,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isReady ? 0.6 : 0.3),
            blurRadius: isReady ? 50 : 30,
            spreadRadius: isReady ? 15 : 5,
          ),
        ],
        border: Border.all(color: Colors.white24, width: 3),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
