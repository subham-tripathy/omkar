import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';

class ExplanationSheet extends StatefulWidget {
  final DetectedObject detectedObject;

  const ExplanationSheet({super.key, required this.detectedObject});

  @override
  State<ExplanationSheet> createState() => _ExplanationSheetState();
}

class _ExplanationSheetState extends State<ExplanationSheet> {
  String _selectedLevel = 'simple';
  String? _explanation;
  bool _isLoading = false;
  String? _errorText;
  late String _objectName;

  final List<_LevelOption> _levels = [
    _LevelOption('simple', '🌱', 'Simple', 'For kids'),
    _LevelOption('medium', '📚', 'Medium', 'Student level'),
    _LevelOption('advanced', '🔬', 'Advanced', 'In-depth'),
  ];

  @override
  void initState() {
    super.initState();
    _objectName = widget.detectedObject.displayLabel;
    _fetchExplanation();
  }

  Future<void> _fetchExplanation() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
      _explanation = null;
    });

    try {
      final text =
          await ApiService.getExplanation(_objectName, _selectedLevel);
      if (mounted) {
        setState(() {
          _explanation = text;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Could not load explanation. Check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _onLevelChanged(String level) {
    if (level == _selectedLevel) return;
    setState(() => _selectedLevel = level);
    _fetchExplanation();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Object name + edit
                      _ObjectNameRow(
                        name: _objectName,
                        onNameChanged: (n) {
                          setState(() => _objectName = n);
                          _fetchExplanation();
                        },
                      ),

                      const SizedBox(height: 8),
                      Text(
                        'Confidence: ${widget.detectedObject.confidencePercent}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13),
                      ),

                      const SizedBox(height: 24),

                      // Level selector
                      const Text(
                        'Explanation Level',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: _levels
                            .map((l) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _LevelButton(
                                      option: l,
                                      isSelected: _selectedLevel == l.value,
                                      onTap: () => _onLevelChanged(l.value),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),

                      const SizedBox(height: 28),

                      // Explanation area
                      _ExplanationArea(
                        isLoading: _isLoading,
                        explanation: _explanation,
                        errorText: _errorText,
                        onRetry: _fetchExplanation,
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOut);
      },
    );
  }
}

// ─── Subwidgets ───────────────────────────────────────────────────────────────

class _ObjectNameRow extends StatelessWidget {
  final String name;
  final void Function(String) onNameChanged;

  const _ObjectNameRow({required this.name, required this.onNameChanged});

  void _editName(BuildContext context) async {
    final controller = TextEditingController(text: name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Edit object name',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter object name',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF6C63FF))),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3ECFCF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK',
                style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      onNameChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded,
              color: Color(0xFF3ECFCF), size: 22),
          onPressed: () => _editName(context),
          tooltip: 'Correct object name',
        ),
      ],
    );
  }
}

class _LevelOption {
  final String value;
  final String emoji;
  final String label;
  final String sub;
  const _LevelOption(this.value, this.emoji, this.label, this.sub);
}

class _LevelButton extends StatelessWidget {
  final _LevelOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelButton(
      {required this.option, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Column(
          children: [
            Text(option.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(option.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                )),
            Text(option.sub,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                )),
          ],
        ),
      ),
    );
  }
}

class _ExplanationArea extends StatelessWidget {
  final bool isLoading;
  final String? explanation;
  final String? errorText;
  final VoidCallback onRetry;

  const _ExplanationArea({
    required this.isLoading,
    required this.explanation,
    required this.errorText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Color(0xFF6C63FF),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 12),
              Text('Generating explanation...',
                  style: TextStyle(color: Colors.white60, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (errorText != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(errorText!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF)),
            ),
          ],
        ),
      );
    }

    if (explanation != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFF3ECFCF), size: 18),
                const SizedBox(width: 8),
                Text(
                  'AI Explanation',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              explanation!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.6,
              ),
            ).animate().fadeIn(duration: 400.ms),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
