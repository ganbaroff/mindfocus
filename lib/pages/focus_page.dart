import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/focus_provider.dart';
import '../theme/app_theme.dart';

class FocusPage extends StatelessWidget {
  const FocusPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Provider.of<FocusProvider>(context);
    final mins = p.remaining ~/ 60;
    final secs = p.remaining % 60;

    return Container(
      decoration: AppTheme.pageGradient,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Title
            const Text('Focus Timer',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              '${p.sessionsToday} sessions  ·  ${p.totalMinutesToday} min today',
              style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 40),

            // Circular Progress Timer
            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background ring
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CustomPaint(
                      painter: _TimerRingPainter(
                        progress: p.progress,
                        isRunning: p.isRunning,
                      ),
                    ),
                  ),
                  // Glass center
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.card.withOpacity(0.4),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.08), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.1),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w300,
                            color: AppTheme.textPrimary,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.isRunning ? 'FOCUSING' : 'READY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: p.isRunning
                                ? AppTheme.accent
                                : AppTheme.textSecondary,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reset
                _controlButton(
                  icon: Icons.refresh,
                  color: AppTheme.textSecondary,
                  onTap: p.reset,
                ),
                const SizedBox(width: 24),
                // Play/Pause (large)
                GestureDetector(
                  onTap: p.toggle,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: p.isRunning
                            ? [
                                AppTheme.danger,
                                AppTheme.danger.withOpacity(0.7)
                              ]
                            : [AppTheme.primary, AppTheme.accent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (p.isRunning ? AppTheme.danger : AppTheme.primary)
                                  .withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      p.isRunning ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Skip (placeholder)
                _controlButton(
                  icon: Icons.skip_next,
                  color: AppTheme.textSecondary,
                  onTap: p.reset,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Presets
            if (!p.isRunning)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: FocusProvider.presets.map((preset) {
                    final isSelected = p.totalSeconds == preset['seconds'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () => p.setDuration(preset['seconds'] as int),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withOpacity(0.3)
                                : AppTheme.surfaceLight.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.divider,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            preset['label'] as String,
                            style: TextStyle(
                              color: isSelected
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 20),

            // Session Log
            if (p.log.isNotEmpty)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassCard(opacity: 0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Today\'s Sessions',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...p.log.take(5).map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              const Icon(Icons.check_circle,
                                  color: AppTheme.success, size: 14),
                              const SizedBox(width: 8),
                              Text(s,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13)),
                            ]),
                          )),
                    ],
                  ),
                ),
              )
            else
              const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _controlButton(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surfaceLight.withOpacity(0.5),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

/// Custom painter for the animated circular timer ring
class _TimerRingPainter extends CustomPainter {
  final double progress;
  final bool isRunning;

  _TimerRingPainter({required this.progress, required this.isRunning});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background ring
    final bgPaint = Paint()
      ..color = AppTheme.divider.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -pi / 2,
          endAngle: 3 * pi / 2,
          colors: isRunning
              ? [AppTheme.accent, AppTheme.primary]
              : [AppTheme.primary, AppTheme.accent],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        progressPaint,
      );

      // Glow dot at tip
      final tipAngle = -pi / 2 + 2 * pi * progress;
      final tipX = center.dx + radius * cos(tipAngle);
      final tipY = center.dy + radius * sin(tipAngle);
      final glowPaint = Paint()
        ..color = AppTheme.accent.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(tipX, tipY), 6, glowPaint);
      canvas.drawCircle(
          Offset(tipX, tipY), 4, Paint()..color = AppTheme.accent);
    }
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter old) =>
      old.progress != progress || old.isRunning != isRunning;
}
