import 'package:flutter/material.dart';

import '../theme.dart';

/// Full-screen soft gradient behind a page.
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: context.style.backgroundGradient),
    child: child,
  );
}

/// The colorful rounded header at the top of a page, with the user's motif
/// drawn faintly in the corner.
class GradientHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const GradientHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 28),
  });

  @override
  Widget build(BuildContext context) {
    final style = context.style;
    return Container(
      decoration: BoxDecoration(
        gradient: style.headerGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: style.header.last.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -10,
              child: Icon(
                style.motif,
                size: 190,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            if (style.playful)
              Positioned(
                left: -20,
                bottom: -30,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 110,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            SafeArea(
              bottom: false,
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// White rounded card with a soft colored shadow.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool highlighted;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.style;
    final radius = BorderRadius.circular(style.playful ? 24 : 18);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: highlighted
            ? Color.alphaBlend(
                style.accent.withValues(alpha: 0.10),
                Colors.white,
              )
            : Colors.white,
        borderRadius: radius,
        border: Border.all(
          color: highlighted ? style.accent : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: style.cardShadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Translucent round icon button for use on gradient headers.
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    ),
  );
}

/// Pill-shaped button filled with the user's header gradient.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.style;
    final enabled = onPressed != null && !busy;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: style.header.sublist(1)),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: style.header.last.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, color: Colors.white),
                  if (busy || icon != null) const SizedBox(width: 10),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
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

/// Round avatar showing the first letter of [name] on the user's gradient.
class InitialAvatar extends StatelessWidget {
  final String name;
  final bool selected;

  const InitialAvatar({super.key, required this.name, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final style = context.style;
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected
            ? null
            : LinearGradient(
                colors: [
                  style.header.first.withValues(alpha: 0.35),
                  style.header.last.withValues(alpha: 0.35),
                ],
              ),
        color: selected ? style.accent : null,
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white)
          : Text(
              letter,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: style.accent),
            ),
    );
  }
}

/// Gradient header for inner pages: back button, title and an optional
/// big figure underneath.
class PageHeader extends StatelessWidget {
  final String title;
  final String? caption;
  final String? figure;

  const PageHeader({super.key, required this.title, this.caption, this.figure});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BackButton(color: Colors.white),
              const SizedBox(width: 4),
              Text(
                title,
                style: context.style
                    .greeting(context.style.playful ? 30 : 22)
                    .copyWith(color: Colors.white),
              ),
            ],
          ),
          if (figure != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (caption != null)
                    Text(
                      caption!,
                      style: text.titleSmall?.copyWith(color: Colors.white70),
                    ),
                  Text(
                    figure!,
                    style: text.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
