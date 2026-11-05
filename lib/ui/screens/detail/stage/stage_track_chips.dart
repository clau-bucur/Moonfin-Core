import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../widgets/focus/focusable_button.dart';
import '../detail_buttons.dart';
import '../item_detail_screen.dart';

/// The audio, subtitle and version pickers as a row of chips, each showing
/// what it's set to. Select opens the same picker the button row would.
class StageTrackChips extends StatefulWidget {
  final List<DetailTrackChoice> choices;
  final FocusNode firstFocusNode;
  final Future<void> Function(DetailButton) onOpen;
  final VoidCallback onNavigateUp;
  final VoidCallback onNavigateDown;

  /// Left off the first chip, back to the buttons beside the poster.
  final VoidCallback? onLeftEdge;

  final bool shareRow;

  const StageTrackChips({
    super.key,
    required this.choices,
    required this.firstFocusNode,
    required this.onOpen,
    required this.onNavigateUp,
    required this.onNavigateDown,
    this.onLeftEdge,
    this.shareRow = false,
  });

  @override
  State<StageTrackChips> createState() => _StageTrackChipsState();
}

class _StageTrackChipsState extends State<StageTrackChips> {
  final Map<int, FocusNode> _nodes = {};
  FocusNode node(int index) => index == 0
      ? widget.firstFocusNode
      : _nodes.putIfAbsent(
          index,
          () => FocusNode(debugLabel: 'StageTrack:$index'),
        );
  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final muted = AppColorScheme.onBackground.withValues(alpha: 0.62);

    final chips = <Widget>[
      for (final (index, choice) in widget.choices.indexed)
        FocusableButton(
          focusNode: node(index),
          onPressed: () async {
            await widget.onOpen(choice.kind);
            if (mounted &&
                index < widget.choices.length &&
                widget.choices[index].kind == choice.kind &&
                ModalRoute.of(context)?.isCurrent != false) {
              node(index).requestFocus();
            }
          },
          onNavigateUp: widget.onNavigateUp,
          onNavigateDown: widget.onNavigateDown,
          onNavigateLeft: () {
            if (index == 0) {
              widget.onLeftEdge?.call();
            } else {
              node(index - 1).requestFocus();
            }
          },
          onNavigateRight: () {
            if (index + 1 < widget.choices.length) {
              node(index + 1).requestFocus();
            }
          },
          borderRadius: 20,
          padding: EdgeInsets.zero,
          semanticLabel: '${choice.kind.label(l10n)}: ${choice.current}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColorScheme.onBackground.withValues(alpha: 0.06),
              borderRadius: AppRadius.circular(20),
              border: Border.all(
                color: AppColorScheme.onBackground.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(choice.kind.icon, size: 18, color: muted),
                const SizedBox(width: 8),
                if (!widget.shareRow)
                  Text(
                    choice.kind.label(l10n),
                    style: textTheme.bodySmall?.copyWith(color: muted),
                  ),
                if (!widget.shareRow) const SizedBox(width: 8),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: choice.kind == DetailButton.version ? 320 : 240,
                    ),
                    child: Text(
                      choice.current,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColorScheme.onBackground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
    if (widget.shareRow) {
      return Row(
        key: const ValueKey('stage-track-chips'),
        spacing: 8,
        children: [for (final chip in chips) Flexible(child: chip)],
      );
    }
    return Wrap(
      key: const ValueKey('stage-track-chips'),
      spacing: 10,
      runSpacing: 10,
      children: chips,
    );
  }
}
