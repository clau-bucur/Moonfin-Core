import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/trickplay_preview_layout.dart';
import '../../../util/focus/dpad_keys.dart';
import '../../../util/playback_time_label.dart';
import 'trickplay.dart';

/// A chapter browser that keeps the selected chapter in the center, like the
/// seek preview. Browsing leaves playback alone until a chapter is activated.
class ChapterFilmstrip extends StatefulWidget {
  const ChapterFilmstrip({
    super.key,
    required this.chapters,
    required this.position,
    required this.planFor,
    required this.isStrip,
    required this.thumbnailBuilder,
    required this.onSelected,
    required this.onPositionChanged,
    required this.onDismiss,
    required this.onDown,
  });

  final List<Map<String, dynamic>> chapters;
  final Duration position;
  final TrickplayPreviewPlan Function(double trackWidth, Duration position)
  planFor;
  final bool isStrip;
  final Widget? Function(int index) thumbnailBuilder;
  final ValueChanged<Duration> onSelected;
  final ValueChanged<Duration> onPositionChanged;
  final VoidCallback onDismiss;
  final VoidCallback onDown;

  @override
  State<ChapterFilmstrip> createState() => _ChapterFilmstripState();
}

class _ChapterFilmstripState extends State<ChapterFilmstrip> {
  final _focus = FocusNode(debugLabel: 'video_player_chapter_filmstrip');
  int _selected = 0;

  Duration _position(int index) =>
      Duration(milliseconds: widget.chapters[index]['startMs'] as int);

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.chapters.length; i++) {
      if (_position(i) <= widget.position) _selected = i;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      widget.onPositionChanged(_position(_selected));
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final select =
        key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter;
    if (!key.isDirectional && !key.isBackKey && !select) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        setState(() {
          _selected =
              (_selected + (key == LogicalKeyboardKey.arrowLeft ? -1 : 1))
                  .clamp(0, widget.chapters.length - 1);
        });
        widget.onPositionChanged(_position(_selected));
      } else if (event is KeyDownEvent) {
        if (select) widget.onSelected(_position(_selected));
        if (key.isBackKey) widget.onDismiss();
        if (key == LogicalKeyboardKey.arrowDown) widget.onDown();
      }
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plan = widget.planFor(
            constraints.maxWidth,
            _position(_selected),
          );
          return TrickplayPreviewArea(
            plan: plan,
            trackWidth: constraints.maxWidth,
            allowOverflow: widget.isStrip,
            child: Trickplay(
              tileWidth: plan.tileWidth,
              tileHeight: plan.tileHeight,
              leftCount: plan.leftCount,
              rightCount: plan.rightCount,
              content: (slot) {
                final index = _selected + slot;
                if (index < 0 || index >= widget.chapters.length) {
                  return null;
                }
                final chapter = widget.chapters[index];
                final title = chapter['title'] as String;
                final time = formatPlaybackDuration(_position(index));
                return Semantics(
                  button: true,
                  selected: slot == 0,
                  label: '$title, $time',
                  child: GestureDetector(
                    onTap: () => widget.onSelected(_position(index)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.thumbnailBuilder(index) ??
                            const ColoredBox(
                              color: Color(0xFF252525),
                              child: Center(
                                child: Icon(
                                  Icons.movie_outlined,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ColoredBox(
                            color: const Color(0xB3000000),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    time,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
