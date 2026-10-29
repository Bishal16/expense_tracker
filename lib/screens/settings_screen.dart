import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../fonts.dart';
import '../format.dart';
import '../models/theme_prefs.dart';
import '../services/auth_service.dart';
import '../services/prefs_repository.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// "Make it yours": colors, fonts, emoji, motif, corners, text size.
/// Every change is saved at once and the whole app restyles live.
class SettingsScreen extends StatefulWidget {
  final User user;
  final AuthService auth;

  const SettingsScreen({super.key, required this.user, required this.auth});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = PrefsRepository();
  final _name = TextEditingController();
  Timer? _nameDebounce;
  double? _dragScale;
  bool _nameLoaded = false;

  /// Latest prefs from the theme; kept so dispose() can still save.
  late ThemePrefs _prefs;

  String get _defaultName => isAdminEmail(widget.user.email)
      ? 'Admin'
      : friendlyName(widget.user.email);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefs = context.style.prefs;
    if (!_nameLoaded) {
      _nameLoaded = true;
      _name.text = _prefs.displayName ?? '';
    }
  }

  @override
  void dispose() {
    // Flush a name still waiting on the debounce.
    if (_nameDebounce?.isActive ?? false) {
      _nameDebounce!.cancel();
      _saveName();
    }
    _name.dispose();
    super.dispose();
  }

  void _update(ThemePrefs next) {
    HapticFeedback.selectionClick();
    _repo.save(widget.user.uid, next).catchError((Object e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    });
  }

  void _saveName() {
    final name = _name.text.trim();
    _repo.save(
      widget.user.uid,
      name.isEmpty
          ? _prefs.copyWith(clearName: true)
          : _prefs.copyWith(displayName: name),
    );
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded, size: 36),
        title: const Text('Back to default?'),
        content: const Text(
          'Colors, fonts and the rest go back to how they started.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 48)),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _name.clear();
      await _repo.reset(widget.user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = context.style;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              PageHeader(title: 'Make it yours ${style.emoji}'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    _preview(),
                    Section(
                      title: 'Your name',
                      icon: Icons.badge_outlined,
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: _defaultName,
                          helperText: 'Used in your greeting',
                          prefixIcon: const Icon(Icons.waving_hand_outlined),
                        ),
                        onChanged: (_) {
                          _nameDebounce?.cancel();
                          _nameDebounce = Timer(
                            const Duration(milliseconds: 700),
                            _saveName,
                          );
                        },
                      ),
                    ),
                    Section(
                      title: 'Color theme',
                      icon: Icons.palette_outlined,
                      padding: const EdgeInsets.all(14),
                      child: _palettes(),
                    ),
                    Section(
                      title: 'Greeting font',
                      icon: Icons.auto_fix_high_rounded,
                      padding: const EdgeInsets.all(14),
                      child: _greetingFonts(),
                    ),
                    Section(
                      title: 'Text font',
                      icon: Icons.text_fields_rounded,
                      padding: const EdgeInsets.all(14),
                      child: _bodyFonts(),
                    ),
                    Section(
                      title: 'Emoji',
                      icon: Icons.emoji_emotions_outlined,
                      padding: const EdgeInsets.all(14),
                      child: _emojis(),
                    ),
                    Section(
                      title: 'Background motif',
                      icon: Icons.local_florist_outlined,
                      padding: const EdgeInsets.all(14),
                      child: _motifs(),
                    ),
                    Section(
                      title: 'Look & feel',
                      icon: Icons.tune_rounded,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: _lookAndFeel(),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reset to default'),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.popUntil(context, (r) => r.isFirst);
                        widget.auth.signOut();
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: Text('Sign out (${widget.user.email})'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A small replica of the home screen, in the current style.
  Widget _preview() {
    final style = context.style;
    final text = Theme.of(context).textTheme;
    final name = style.displayName ?? _defaultName;
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(style.radius),
              bottom: Radius.circular(style.radius),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(gradient: style.headerGradient),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -16,
                    top: -16,
                    child: Icon(
                      style.motif,
                      size: 96,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, $name ${style.emoji}',
                        style: style.greeting(22).copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total remaining',
                        style: text.labelMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        taka(1250),
                        style: text.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: Row(
              children: [
                const InitialAvatar(name: 'Rice'),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rice',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '2 kg',
                        style: text.bodySmall?.copyWith(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Text(
                  taka(240),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: style.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _palettes() {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - 2 * 10) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final p in Palette.all)
              Semantics(
                button: true,
                selected: _prefs.palette == p.id,
                label: p.name,
                child: GestureDetector(
                  onTap: () => _update(_prefs.copyWith(palette: p.id)),
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: p.header,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _prefs.palette == p.id
                                  ? Colors.black87
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: _prefs.palette == p.id
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 28,
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.name,
                          style: text.labelMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _greetingFonts() {
    final style = context.style;
    final name = style.displayName ?? _defaultName;
    return Column(
      children: [
        for (final f in greetingFonts)
          _optionTile(
            selected: _prefs.greetingFont == f,
            onTap: () => _update(_prefs.copyWith(greetingFont: f)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Hi, $name',
                    style: AppStyle.fromPrefs(_prefs.copyWith(greetingFont: f))
                        .greeting(20)
                        .copyWith(color: style.accent),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  f,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: Colors.black45),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _bodyFonts() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final f in bodyFonts)
        ChoiceChip(
          label: Text(f, style: fontStyle(f)),
          selected: _prefs.bodyFont == f,
          onSelected: (_) => _update(_prefs.copyWith(bodyFont: f)),
        ),
    ],
  );

  Widget _emojis() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final e in emojis)
        _roundOption(
          selected: _prefs.emoji == e,
          onTap: () => _update(_prefs.copyWith(emoji: e)),
          label: e,
          child: Text(e, style: const TextStyle(fontSize: 24)),
        ),
    ],
  );

  Widget _motifs() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final m in motifs.entries)
        _roundOption(
          selected: _prefs.motif == m.key,
          onTap: () => _update(_prefs.copyWith(motif: m.key)),
          label: m.key,
          child: Icon(m.value, color: context.style.accent),
        ),
    ],
  );

  Widget _lookAndFeel() {
    final text = Theme.of(context).textTheme;
    final scale = _dragScale ?? _prefs.textScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Corners',
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<double>(
          showSelectedIcon: false,
          segments: [
            for (final c in cornerStyles.entries)
              ButtonSegment(value: c.value, label: Text(c.key)),
          ],
          selected: {_prefs.radius},
          onSelectionChanged: (v) => _update(_prefs.copyWith(radius: v.first)),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Text size',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text('${(scale * 100).round()}%', style: text.labelLarge),
          ],
        ),
        Row(
          children: [
            const Text('A', style: TextStyle(fontSize: 13)),
            Expanded(
              child: Slider(
                value: scale,
                min: 0.85,
                max: 1.3,
                divisions: 9,
                onChanged: (v) => setState(() => _dragScale = v),
                onChangeEnd: (v) {
                  setState(() => _dragScale = null);
                  _update(_prefs.copyWith(textScale: v));
                },
              ),
            ),
            const Text('A', style: TextStyle(fontSize: 22)),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sweet touches'),
          subtitle: const Text('Hearts in the header and cuter wording'),
          value: _prefs.decorations,
          onChanged: (v) => _update(_prefs.copyWith(decorations: v)),
        ),
      ],
    );
  }

  Widget _optionTile({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final style = context.style;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? style.accent.withValues(alpha: 0.12)
            : style.accent.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? style.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _roundOption({
    required bool selected,
    required VoidCallback onTap,
    required String label,
    required Widget child,
  }) {
    final style = context.style;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? style.accent.withValues(alpha: 0.16)
                : style.accent.withValues(alpha: 0.05),
            border: Border.all(
              color: selected ? style.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
