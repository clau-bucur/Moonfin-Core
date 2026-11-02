import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../data/models/aggregated_item.dart';
import '../../l10n/app_localizations.dart';
import 'focusable_dialog_row.dart';
import 'overlay_sheet.dart';

class TrackActionDialog extends StatelessWidget {
  final AggregatedItem track;
  final VoidCallback? onPlay;
  final VoidCallback? onPlayNext;
  final VoidCallback? onViewDetails;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onRemoveFromPlaylist;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onGoToAlbum;
  final VoidCallback? onGoToArtist;

  const TrackActionDialog({
    super.key,
    required this.track,
    this.onPlay,
    this.onPlayNext,
    this.onViewDetails,
    this.onAddToQueue,
    this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
    this.onMoveUp,
    this.onMoveDown,
    this.onToggleFavorite,
    this.onGoToAlbum,
    this.onGoToArtist,
  });

  static Future<void> show(
    BuildContext context, {
    required AggregatedItem track,
    VoidCallback? onPlay,
    VoidCallback? onPlayNext,
    VoidCallback? onViewDetails,
    VoidCallback? onAddToQueue,
    VoidCallback? onAddToPlaylist,
    VoidCallback? onRemoveFromPlaylist,
    VoidCallback? onMoveUp,
    VoidCallback? onMoveDown,
    VoidCallback? onToggleFavorite,
    VoidCallback? onGoToAlbum,
    VoidCallback? onGoToArtist,
  }) {
    return showFocusRestoringDialog(
      context: context,
      builder: (_) => TrackActionDialog(
        track: track,
        onPlay: onPlay,
        onPlayNext: onPlayNext,
        onViewDetails: onViewDetails,
        onAddToQueue: onAddToQueue,
        onAddToPlaylist: onAddToPlaylist,
        onRemoveFromPlaylist: onRemoveFromPlaylist,
        onMoveUp: onMoveUp,
        onMoveDown: onMoveDown,
        onToggleFavorite: onToggleFavorite,
        onGoToAlbum: onGoToAlbum,
        onGoToArtist: onGoToArtist,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(minWidth: 340, maxWidth: 440),
                decoration: BoxDecoration(
                  color: AppColorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: AppRadius.circular(20),
                  border: Border.fromBorderSide(ThemeRegistry.active.borders.chipBorder),
                ),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.85,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (track.artists.isNotEmpty)
                                  Text(
                                    track.artists.join(', '),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                else if (track.albumArtist != null)
                                  Text(
                                    track.albumArtist!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                        const SizedBox(height: 8),
                        if (onPlay != null)
                          FocusableDialogRow(
                            icon: Icons.play_arrow,
                            label: l10n.play,
                            onTap: () {
                              Navigator.pop(context);
                              onPlay!();
                            },
                            autofocus: true,
                          ),
                        if (onPlayNext != null)
                          FocusableDialogRow(
                            icon: Icons.queue_play_next,
                            label: l10n.trackActionPlayNext,
                            onTap: () {
                              Navigator.pop(context);
                              onPlayNext!();
                            },
                          ),
                        if (onViewDetails != null)
                          FocusableDialogRow(
                            icon: Icons.info_outline,
                            label: l10n.trackActionViewDetails,
                            onTap: () {
                              Navigator.pop(context);
                              onViewDetails!();
                            },
                          ),
                        if (onAddToQueue != null)
                          FocusableDialogRow(
                            icon: Icons.add_to_queue,
                            label: l10n.trackActionAddToQueue,
                            onTap: () {
                              Navigator.pop(context);
                              onAddToQueue!();
                            },
                          ),
                        if (onAddToPlaylist != null)
                          FocusableDialogRow(
                            icon: Icons.playlist_add,
                            label: l10n.trackActionAddToPlaylist,
                            onTap: () {
                              Navigator.pop(context);
                              onAddToPlaylist!();
                            },
                          ),
                        if (onRemoveFromPlaylist != null)
                          FocusableDialogRow(
                            icon: Icons.playlist_remove,
                            label: l10n.trackActionDeleteFromPlaylist,
                            onTap: () {
                              Navigator.pop(context);
                              onRemoveFromPlaylist!();
                            },
                          ),
                        if (onMoveUp != null)
                          FocusableDialogRow(
                            icon: Icons.arrow_upward,
                            label: l10n.trackActionMoveUp,
                            onTap: () {
                              Navigator.pop(context);
                              onMoveUp!();
                            },
                          ),
                        if (onMoveDown != null)
                          FocusableDialogRow(
                            icon: Icons.arrow_downward,
                            label: l10n.trackActionMoveDown,
                            onTap: () {
                              Navigator.pop(context);
                              onMoveDown!();
                            },
                          ),
                        if (onToggleFavorite != null)
                          FocusableDialogRow(
                            icon: track.isFavorite ? Icons.favorite : Icons.favorite_border,
                            label: track.isFavorite
                                ? l10n.trackActionRemoveFromFavorites
                                : l10n.trackActionAddToFavorites,
                            onTap: () {
                              Navigator.pop(context);
                              onToggleFavorite!();
                            },
                          ),
                        if (onGoToAlbum != null)
                          FocusableDialogRow(
                            icon: Icons.album,
                            label: l10n.trackActionGoToAlbum,
                            onTap: () {
                              Navigator.pop(context);
                              onGoToAlbum!();
                            },
                          ),
                        if (onGoToArtist != null)
                          FocusableDialogRow(
                            icon: Icons.person,
                            label: l10n.trackActionGoToArtist,
                            onTap: () {
                              Navigator.pop(context);
                              onGoToArtist!();
                            },
                          ),
                        const SizedBox(height: 4),
                        Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                        const SizedBox(height: 4),
                        FocusableDialogRow(
                          label: l10n.cancel,
                          onTap: () => Navigator.pop(context),
                          dimmed: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
  }


}
