import 'package:flutter/material.dart';
import '../app_config.dart';

/// A reusable branded AppBar that shows:
///   [AppConfig.appName]  |  [pageTitle]
///
/// When [pageTitle] is null only the logo name is shown, centred.
///
/// Usage:
/// ```dart
/// appBar: BrandAppBar(
///   pageTitle: 'Host Board',
///   leading: backButton,
///   actions: [...],
/// )
/// ```
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({
    super.key,
    this.pageTitle,
    this.leading,
    this.actions,
    this.centerTitle = false,
  });

  /// Optional subtitle shown after the logo divider.
  final String? pageTitle;

  /// Optional leading widget (e.g. a back button).
  final Widget? leading;

  /// Optional action widgets on the trailing side.
  final List<Widget>? actions;

  /// When true the title row is centred (useful for game screens that have
  /// no page subtitle).
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      title: _BrandTitle(pageTitle: pageTitle),
    );
  }
}

// ── Internal title widget ──────────────────────────────────────────────────
class _BrandTitle extends StatelessWidget {
  const _BrandTitle({this.pageTitle});
  final String? pageTitle;

  @override
  Widget build(BuildContext context) {
    final logo = Text(
      AppConfig.appName,
      style: const TextStyle(
        color: AppConfig.accentColor,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        fontSize: 16,
      ),
    );

    if (pageTitle == null) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 10),
        Container(height: 16, width: 1.5, color: Colors.white24),
        const SizedBox(width: 10),
        Text(
          pageTitle!,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
