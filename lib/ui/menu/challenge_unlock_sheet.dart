import 'package:flutter/material.dart';

import '../../game/systems/purchases_config.dart';
import '../../game/systems/purchases_controller.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';

/// Unlock sheet for one Challenge pack, with the all-packs bundle offered to
/// players who own no packs yet. Returns true when [pack] is owned on close.
Future<bool> showPackUnlockSheet(
  BuildContext context, {
  required int pack,
}) async {
  final purchases = PurchasesController.instance;
  await purchases.refresh();
  if (!context.mounted) return purchases.ownsPack(pack);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: GameColors.spaceDeep,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => ChallengeUnlockPanel(
      pack: pack,
      onUnlocked: () => Navigator.of(ctx).pop(),
    ),
  );
  return purchases.ownsPack(pack);
}

/// Shared pack unlock UI (sheet + App Store review screenshot).
class ChallengeUnlockPanel extends StatefulWidget {
  const ChallengeUnlockPanel({
    super.key,
    required this.pack,
    this.onUnlocked,
    this.previewMode = false,
  });

  final int pack;
  final VoidCallback? onUnlocked;
  final bool previewMode;

  @override
  State<ChallengeUnlockPanel> createState() => _ChallengeUnlockPanelState();
}

class _ChallengeUnlockPanelState extends State<ChallengeUnlockPanel> {
  bool _busy = false;

  PurchasesController get _purchases => PurchasesController.instance;

  Future<void> _buy(String productId) async {
    if (widget.previewMode) return;
    setState(() => _busy = true);
    final ok = await _purchases.purchaseProduct(productId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onUnlocked?.call();
  }

  Future<void> _restore() async {
    if (widget.previewMode) return;
    setState(() => _busy = true);
    await _purchases.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    if (_purchases.ownsPack(widget.pack)) {
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
    final packProduct = ProductIds.forPack(widget.pack);
    final packPrice = widget.previewMode
        ? FallbackPrices.singlePack
        : _purchases.priceLabel(
            packProduct,
            fallback: FallbackPrices.singlePack,
          );
    final bundlePrice = widget.previewMode
        ? FallbackPrices.allPacks
        : _purchases.priceLabel(
            ProductIds.challengeAllPacks,
            fallback: FallbackPrices.allPacks,
          );
    final offerBundle = widget.previewMode || !_purchases.ownsAnyPack;
    final err = widget.previewMode ? null : _purchases.lastError;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Unlock Pack ${widget.pack}',
              textAlign: TextAlign.center,
              style: GameFonts.ui(fontSize: 20, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'Preset starts. Limited shots. Twenty levels, unlocked one '
              'clear at a time.',
              textAlign: TextAlign.center,
              style: GameFonts.prose(fontSize: 15, color: GameColors.mutedText),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _busy ? null : () => _buy(packProduct),
              child: Text(
                _busy ? 'Working…' : 'Pack ${widget.pack} · $packPrice',
              ),
            ),
            if (offerBundle) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _busy
                    ? null
                    : () => _buy(ProductIds.challengeAllPacks),
                child: Text(
                  _busy
                      ? 'Working…'
                      : 'All $challengePackCount packs · $bundlePrice',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Buy 2, get 1 free',
                textAlign: TextAlign.center,
                style: GameFonts.label(fontSize: 11),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _restore,
              child: Text(
                'Restore purchases',
                style: GameFonts.ui(fontSize: 14, color: GameColors.mutedText),
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
                style: GameFonts.ui(fontSize: 12, color: GameColors.rimWarning),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
