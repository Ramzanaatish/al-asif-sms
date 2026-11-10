import 'package:flutter/material.dart';

/// Professional cards matching the HTML app: white cards, navy/gold brand,
/// compact content. The old dashboard/report grids stretched one icon and one
/// number across a giant square, which is why the screens looked empty.

/// Columns for a stat grid at the current width: 4 on a wide desktop
/// window, 3 on a narrow window, 2 on a phone. Takes the GRID width, not
/// the screen width: on desktop the pinned sidebar (260px) eats part of
/// the window, and 4 columns in the remaining space would truncate values
/// like "Rs 145,200" with an ellipsis.
int statColumnsForWidth(double width) {
  if (width >= 980) return 4;
  if (width >= 650) return 3;
  return 2;
}

/// Columns for a stat grid, from the screen width (no sidebar in play).
int statColumns(BuildContext context) =>
    statColumnsForWidth(MediaQuery.sizeOf(context).width);

/// Columns for a menu-tile grid: 2 on a wide window, 1 on a phone.
/// Takes the GRID width (see [statColumnsForWidth]).
int tileColumnsForWidth(double width) => width >= 780 ? 2 : 1;

/// Columns for a menu-tile grid, from the screen width (no sidebar in play).
int tileColumns(BuildContext context) =>
    tileColumnsForWidth(MediaQuery.sizeOf(context).width);

/// A compact stat card: tinted icon chip on the left, small grey label and
/// a large bold value on the right. Fixed height comes from the grid's
/// mainAxisExtent, never from stretching content apart.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact menu tile: tinted icon chip, title + subtitle, chevron.
/// Used by hub screens (Reports) so a tile reads as one row, not a square.
class ReportTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ReportTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
