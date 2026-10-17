import 'package:flutter/material.dart';

import '../../config.dart';
import 'analytics_screen.dart';
import 'annual_result_screen.dart';
import 'datesheet_screen.dart';
import 'marks_entry_screen.dart';
import 'monthly_result_screen.dart';
import 'terms_screen.dart';

/// Tab hub for the Exams module.
class ExamsHomeScreen extends StatelessWidget {
  const ExamsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item('Terms', Icons.event_note, const TermsScreen()),
      _Item('Date Sheets', Icons.calendar_month, const DateSheetScreen()),
      _Item('Marks Entry', Icons.edit_note, const MarksEntryScreen()),
      _Item('Monthly Result', Icons.assignment_turned_in,
          const MonthlyResultScreen()),
      _Item('Annual Result', Icons.emoji_events, const AnnualResultScreen()),
      _Item('Analytics', Icons.analytics, const AnalyticsScreen()),
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
