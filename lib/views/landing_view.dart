import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_config.dart';
import '../theme/app_theme.dart';

class LandingView extends StatelessWidget {
  const LandingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.glowAmber,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.glowAmber.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppConfig.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppConfig.accentColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppConfig.appTagline,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 34),
                  _MenuButton(
                    title: 'JOIN AS PLAYER',
                    icon: Icons.person_add,
                    onTap: () => context.go('/player'),
                  ),
                  const SizedBox(height: 14),
                  _MenuButton(
                    title: 'HOST GAME',
                    icon: Icons.monitor,
                    onTap: () => context.go('/host'),
                    isSecondary: true,
                  ),
                  const SizedBox(height: 14),
                  _MenuButton(
                    title: 'ADMIN PANEL',
                    icon: Icons.settings,
                    onTap: () => context.go('/admin'),
                    isSecondary: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSecondary;

  const _MenuButton({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary
              ? theme.colorScheme.surface
              : AppTheme.buzzerAccent,
          foregroundColor: isSecondary ? Colors.white : Colors.black,
          side: isSecondary
              ? BorderSide(
                  color: AppTheme.buzzerAccent.withOpacity(0.5))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
