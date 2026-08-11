import 'package:flutter/material.dart';

import '../../game/systems/purchases_controller.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';

/// Unlock sheet for Challenge ($2.99 / store price). Levels still Coming soon.
Future<bool> showChallengeUnlockSheet(BuildContext context) async {
  final purchases = PurchasesController.instance;
  await purchases.refresh();
  if (!context.mounted) return purchases.hasChallenge;

  final unlocked = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: GameColors.spaceDeep,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => ChallengeUnlockPanel(
      onUnlocked: () => Navigator.of(ctx).pop(true),
    ),
  );
  return unlocked == true || purchases.hasChallenge;
}

/// Shared Challenge unlock UI (sheet + App Store review screenshot).
class ChallengeUnlockPanel extends StatefulWidget {
  const ChallengeUnlockPanel({
    super.key,
    this.onUnlocked,
    this.previewMode = false,
  });

  final VoidCallback? onUnlocked;
  final bool previewMode;

  @override
  State<ChallengeUnlockPanel> createState() => _ChallengeUnlockPanelState();
}

class _ChallengeUnlockPanelState extends State<ChallengeUnlockPanel> {
  bool _busy = false;

  PurchasesController get _purchases => PurchasesController.instance;

  Future<void> _buy() async {
    if (widget.previewMode) return;
    setState(() => _busy = true);
    final ok = await _purchases.purchaseChallenge();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onUnlocked?.call();
  }

  Future<void> _restore() async {
    if (widget.previewMode) return;
    setState(() => _busy = true);
    final ok = await _purchases.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.onUnlocked?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _purchases.lastError ?? 'No purchase found to restore',
            style: GameFonts.ui(fontSize: 14),
          ),
          backgroundColor: GameColors.space,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.previewMode
        ? r'$2.99'
        : _purchases.challengePriceLabel;
    final err = widget.previewMode ? null : _purchases.lastError;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Unlock Challenge',
              textAlign: TextAlign.center,
              style: GameFonts.ui(fontSize: 20, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'Preset starts. Limited shots. Levels are still being built — '
              'buy now and they unlock when they ship.',
              textAlign: TextAlign.center,
              style: GameFonts.prose(
                fontSize: 15,
                color: GameColors.mutedText,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _busy ? null : _buy,
              child: Text(_busy ? 'Working…' : 'Unlock · $price'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _restore,
              child: Text(
                'Restore purchases',
                style: GameFonts.ui(
                  fontSize: 14,
                  color: GameColors.mutedText,
                ),
              ),
            ),
            if (!widget.previewMode && !_purchases.isConfigured) ...[
              const SizedBox(height: 8),
              Text(
                'Store billing is available on Android and iOS builds.',
                textAlign: TextAlign.center,
                style: GameFonts.ui(
                  fontSize: 12,
                  color: GameColors.mutedText.withValues(alpha: 0.85),
                ),
              ),
            ],
            if (err != null && err.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                err,
                textAlign: TextAlign.center,
                style: GameFonts.ui(
                  fontSize: 12,
                  color: GameColors.rimWarning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
