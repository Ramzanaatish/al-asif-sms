import 'package:flutter/material.dart';

import '../../config.dart';
import 'classes_screen.dart';
import 'syllabus_screen.dart';
import 'timetable_screen.dart';

/// Tab hub for the Academics module.
class AcademicsHomeScreen extends StatelessWidget {
  const AcademicsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item('Classes & Sections', Icons.class_, const ClassesScreen()),
      _Item('Timetable', Icons.calendar_view_week, const TimetableScreen()),
      _Item('Syllabus', Icons.menu_book, const SyllabusScreen()),
    ];
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: items
          .map((it) => Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => it.screen),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(it.icon, size: 44, color: AppColors.navy),
                      const SizedBox(height: 10),
                      Text(it.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _Item {
  final String title;
  final IconData icon;
  final Widget screen;
  _Item(this.title, this.icon, this.screen);
}
