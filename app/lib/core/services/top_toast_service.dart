import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum TopToastType { info, success, warning, error }

class TopToast {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    TopToastType type = TopToastType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    try {
      _currentEntry?.remove();
      _currentEntry = null;
    } catch (_) {}

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    Color iconBg;
    IconData iconData;
    Color borderColor;

    switch (type) {
      case TopToastType.success:
        iconBg = Colors.greenAccent;
        iconData = Icons.check_circle_rounded;
        borderColor = Colors.greenAccent.withOpacity(0.5);
        break;
      case TopToastType.warning:
        iconBg = Colors.amber;
        iconData = Icons.warning_amber_rounded;
        borderColor = Colors.amber.withOpacity(0.5);
        break;
      case TopToastType.error:
        iconBg = Colors.redAccent;
        iconData = Icons.error_outline_rounded;
        borderColor = Colors.redAccent.withOpacity(0.5);
        break;
      case TopToastType.info:
      default:
        iconBg = AppColors.primary;
        iconData = Icons.info_outline_rounded;
        borderColor = AppColors.primary.withOpacity(0.5);
        break;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopToastWidget(
        title: title,
        message: message,
        iconData: iconData,
        iconBg: iconBg,
        borderColor: borderColor,
        onDismiss: () {
          try {
            entry.remove();
          } catch (_) {}
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (_currentEntry == entry) {
        try {
          entry.remove();
        } catch (_) {}
        _currentEntry = null;
      }
    });
  }
}

class _TopToastWidget extends StatefulWidget {
  final String title;
  final String message;
  final IconData iconData;
  final Color iconBg;
  final Color borderColor;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    required this.title,
    required this.message,
    required this.iconData,
    required this.iconBg,
    required this.borderColor,
    required this.onDismiss,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 10;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.iconBg.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.iconData, color: widget.iconBg, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _dismiss,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
