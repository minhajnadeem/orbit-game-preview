import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_app_bar.dart';

class AdminView extends ConsumerStatefulWidget {
  const AdminView({super.key});

  @override
  ConsumerState<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends ConsumerState<AdminView> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  int _correctAnswerIndex = 0;
  String? _editingQuestionId;

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final question = Question(
      id: _editingQuestionId ?? '',
      question: _questionController.text,
      options: _optionControllers.map((c) => c.text).toList(),
      correctAnswerIndex: _correctAnswerIndex,
    );

    try {
      if (_editingQuestionId != null) {
        await ref.read(firestoreServiceProvider).updateQuestion(question);
      } else {
        await ref.read(firestoreServiceProvider).addQuestion(question);
      }

      _clearForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingQuestionId != null
                  ? 'Question updated'
                  : 'Question added',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _clearForm() {
    setState(() {
      _questionController.clear();
      for (var controller in _optionControllers) {
        controller.clear();
      }
      _correctAnswerIndex = 0;
      _editingQuestionId = null;
    });
  }

  void _editQuestion(Question question) {
    setState(() {
      _editingQuestionId = question.id;
      _questionController.text = question.question;
      for (int i = 0; i < 4; i++) {
        if (i < question.options.length) {
          _optionControllers[i].text = question.options[i];
        } else {
          _optionControllers[i].text = '';
        }
      }
      _correctAnswerIndex = question.correctAnswerIndex;
    });
  }

  void _confirmClearAllQuestions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Questions'),
          content: const Text(
            'Are you sure you want to delete all questions? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await ref.read(firestoreServiceProvider).clearAllQuestions();
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('All questions cleared')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Clear All', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsyncValue = ref.watch(questionsStreamProvider);

    return Scaffold(
      appBar: BrandAppBar(
        pageTitle: 'Admin Panel',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            final pad = isWide ? 20.0 : 12.0;

            final formSide = Padding(
              padding: EdgeInsets.all(pad),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(pad),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _editingQuestionId != null
                                ? 'Edit Question'
                                : 'Add New Question',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _questionController,
                            decoration: const InputDecoration(
                              labelText: 'Question Text',
                            ),
                            maxLines: 3,
                            validator: (value) =>
                                value == null || value.isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(4, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                children: [
                                  Radio<int>(
                                    value: index,
                                    groupValue: _correctAnswerIndex,
                                    onChanged: (value) {
                                      setState(() =>
                                          _correctAnswerIndex = value!);
                                    },
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller:
                                          _optionControllers[index],
                                      decoration: InputDecoration(
                                        labelText:
                                            'Option ${String.fromCharCode(65 + index)}',
                                      ),
                                      validator: (value) =>
                                          value == null || value.isEmpty
                                              ? 'Required'
                                              : null,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _submitForm,
                                  child: Text(
                                    _editingQuestionId != null
                                        ? 'Update Question'
                                        : 'Add Question',
                                  ),
                                ),
                              ),
                              if (_editingQuestionId != null) ...[
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: _clearForm,
                                  child: const Text('Cancel Edit'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );

            // Question count badge
            final questionCount = questionsAsyncValue.whenOrNull(
                  data: (q) => q.length,
                ) ??
                0;

            // List Side
            final listSide = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                      left: pad, right: pad, top: pad, bottom: 8),
                  child: Row(
                    children: [
                      Text('Questions',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.buzzerAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$questionCount',
                            style: TextStyle(
                                color: AppTheme.buzzerAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                      const Spacer(),
                      if (questionCount > 0)
                        TextButton.icon(
                          onPressed: () => _confirmClearAllQuestions(context),
                          icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                          label: const Text('Clear All', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: questionsAsyncValue.when(
                    data: (questions) => ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      itemCount: questions.length,
                      itemBuilder: (context, index) {
                        final question = questions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            dense: true,
                            title: Text(question.question,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              'Correct: ${question.options[question.correctAnswerIndex]}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue, size: 20),
                                  onPressed: () =>
                                      _editQuestion(question),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red, size: 20),
                                  onPressed: () {
                                    ref
                                        .read(firestoreServiceProvider)
                                        .deleteQuestion(question.id);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: formSide),
                  Expanded(child: listSide),
                ],
              );
            } else {
              return Column(
                children: [
                  Expanded(child: formSide),
                  Expanded(child: listSide),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
