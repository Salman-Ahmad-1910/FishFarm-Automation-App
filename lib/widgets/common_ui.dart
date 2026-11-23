import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Colours shared by every screen.
class AppColors {
  AppColors._();
  static const Color bg = Color(0xFF263746);
  static const Color card = Color(0xFF172633);
  static const Color border = Color(0xFF2A3F52);
  static const Color pill = Color(0xFF203342);
  static const Color muted = Color(0xFF808B96);
  static const Color label = Color(0xFFAAB8C4);
  static const Color green = Color(0xFF8BC34A);
  static const Color red = Color(0xFFF44336);
  static const Color orange = Color(0xFFFF9800);
  static const Color blue = Color(0xFF536FC0);
}

/// Centres page content, limits its width on tablets / landscape and scales
/// the side padding with the screen width.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({super.key, required this.child, this.maxWidth = 1100});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final pad = w < 360 ? 10.0 : (w < 600 ? 14.0 : 20.0);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(padding: EdgeInsets.all(pad), child: child),
          ),
        );
      },
    );
  }
}

/// Plain card used for most panels.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 14,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );
  }
}

/// Page header: icon, title, subtitle, server status and refresh button.
class AppHeader extends StatelessWidget {
  final IconData icon;
  final String subtitle;
  final bool serverConnected;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  const AppHeader({
    super.key,
    required this.icon,
    required this.subtitle,
    required this.serverConnected,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final connColor = serverConnected ? AppColors.green : AppColors.red;
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 380;
          final statusText = serverConnected
              ? (narrow ? 'ONLINE' : 'SERVER CONNECTED')
              : (narrow ? 'OFFLINE' : 'SERVER DISCONNECTED');
          return Row(
            children: [
              Icon(icon, color: AppColors.blue, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fish Farm Monitoring',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.label),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.pill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: connColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: connColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: isRefreshing ? null : () => onRefresh(),
                icon: isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.blue,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded,
                        color: AppColors.label),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SummaryTileData {
  final String label;
  final String value;
  final Color color;
  const SummaryTileData(this.label, this.value, this.color);
}

/// Row of summary tiles. On very narrow screens it becomes a 2 x 2 grid.
class SummaryTiles extends StatelessWidget {
  final List<SummaryTileData> tiles;
  const SummaryTiles({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth >= 330 ? tiles.length : 2;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final t in tiles)
              SizedBox(
                width: tileWidth,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          t.value,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: t.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          t.label,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.label,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
      ),
      child: Text(
        'SERVER DISCONNECTED: $message',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.red,
        ),
      ),
    );
  }
}

class LastUpdateFooter extends StatelessWidget {
  final DateTime? lastServerUpdate;
  final bool isStale;
  const LastUpdateFooter(
      {super.key, required this.lastServerUpdate, required this.isStale});

  @override
  Widget build(BuildContext context) {
    String text;
    if (lastServerUpdate == null) {
      text = 'No successful server update yet.';
    } else {
      text =
          'Last server update: ${DateFormat('dd MMM yyyy, HH:mm:ss').format(lastServerUpdate!.toLocal())}';
      if (isStale) text += ' (stale)';
    }
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
      ),
    );
  }
}

class SkeletonBlock extends StatelessWidget {
  final double height;
  const SkeletonBlock({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
