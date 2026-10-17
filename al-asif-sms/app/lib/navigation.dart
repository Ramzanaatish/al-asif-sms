import 'package:flutter/material.dart';

import 'screens/academics/academics_home_screen.dart';
import 'screens/attendance/attendance_home_screen.dart';
import 'screens/attendance/mark_attendance_screen.dart';
import 'screens/audit_log_screen.dart';
import 'screens/comms/complaints_screen.dart';
import 'screens/comms/notices_screen.dart';
import 'screens/comms/parent_home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/exams/exams_home_screen.dart';
import 'screens/expenses/expense_list_screen.dart';
import 'screens/expenses/profit_loss_screen.dart';
import 'screens/fees/fees_home_screen.dart';
import 'screens/reports_home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/staff/salary_screen.dart';
import 'screens/staff/staff_list_screen.dart';
import 'screens/students/student_list_screen.dart';

/// One drawer entry.
class MenuEntry {
  final String title;
  final IconData icon;
  final Widget Function() builder;
  const MenuEntry(this.title, this.icon, this.builder);
}

/// Role -> visible screens. Every role sees only its own screens.
List<MenuEntry> menuForRole(String role) {
  switch (role) {
    case 'principal':
      return [
        MenuEntry('Dashboard', Icons.dashboard,
            () => const PrincipalDashboardScreen()),
        MenuEntry('Students', Icons.people,
            () => const StudentListScreen()),
        MenuEntry('Staff', Icons.badge, () => const StaffListScreen()),
        MenuEntry(
            'Academics', Icons.school, () => const AcademicsHomeScreen()),
        MenuEntry('Attendance', Icons.fact_check,
            () => const AttendanceHomeScreen()),
        MenuEntry('Exams', Icons.assignment, () => const ExamsHomeScreen()),
        MenuEntry(
            'Fees', Icons.receipt_long, () => const FeesHomeScreen()),
        MenuEntry('Expenses', Icons.money_off,
            () => const ExpenseListScreen()),
        MenuEntry('Profit & Loss', Icons.trending_up,
            () => const ProfitLossScreen()),
        MenuEntry(
            'Notices', Icons.campaign, () => const NoticesScreen()),
        MenuEntry('Complaints', Icons.report_problem,
            () => const ComplaintsScreen()),
        MenuEntry(
            'Reports', Icons.bar_chart, () => const ReportsHomeScreen()),
        MenuEntry('Audit Log', Icons.history, () => const AuditLogScreen()),
        MenuEntry('Settings', Icons.settings, () => const SettingsScreen()),
      ];
    case 'administrator':
      return [
        MenuEntry('Dashboard', Icons.dashboard,
            () => const PrincipalDashboardScreen()),
        MenuEntry('Students', Icons.people,
            () => const StudentListScreen()),
        MenuEntry('Staff', Icons.badge, () => const StaffListScreen()),
        MenuEntry(
            'Academics', Icons.school, () => const AcademicsHomeScreen()),
        MenuEntry('Attendance', Icons.fact_check,
            () => const AttendanceHomeScreen()),
        MenuEntry('Exams', Icons.assignment, () => const ExamsHomeScreen()),
        MenuEntry(
            'Fees', Icons.receipt_long, () => const FeesHomeScreen()),
        MenuEntry('Expenses', Icons.money_off,
            () => const ExpenseListScreen()),
        MenuEntry('Profit & Loss', Icons.trending_up,
            () => const ProfitLossScreen()),
        MenuEntry(
            'Notices', Icons.campaign, () => const NoticesScreen()),
        MenuEntry('Complaints', Icons.report_problem,
            () => const ComplaintsScreen()),
        MenuEntry(
            'Reports', Icons.bar_chart, () => const ReportsHomeScreen()),
        MenuEntry('Settings', Icons.settings, () => const SettingsScreen()),
      ];
    case 'teacher':
      return [
        MenuEntry('Mark Attendance', Icons.fact_check,
            () => const MarkAttendanceScreen()),
        MenuEntry('Students', Icons.people,
            () => const StudentListScreen(readOnly: true)),
        MenuEntry(
            'Academics', Icons.school, () => const AcademicsHomeScreen()),
        MenuEntry('Exams', Icons.assignment, () => const ExamsHomeScreen()),
        MenuEntry(
            'Notices', Icons.campaign, () => const NoticesScreen()),
        MenuEntry('Complaints', Icons.report_problem,
            () => const ComplaintsScreen()),
      ];
    case 'accountant':
      return [
        MenuEntry(
            'Fees', Icons.receipt_long, () => const FeesHomeScreen()),
        MenuEntry('Expenses', Icons.money_off,
            () => const ExpenseListScreen()),
        MenuEntry('Salaries', Icons.payments, () => const SalaryScreen()),
        MenuEntry('Profit & Loss', Icons.trending_up,
            () => const ProfitLossScreen()),
        MenuEntry(
            'Reports', Icons.bar_chart, () => const ReportsHomeScreen()),
        MenuEntry(
            'Notices', Icons.campaign, () => const NoticesScreen()),
      ];
    case 'parent':
      return [
        MenuEntry('My Children', Icons.child_care,
            () => const ParentHomeScreen()),
        MenuEntry(
            'Notices', Icons.campaign, () => const NoticesScreen()),
        MenuEntry('Complaints', Icons.report_problem,
            () => const ComplaintsScreen()),
      ];
    default:
      return [
        MenuEntry(
            'Notices', Icons.campaign, () => const NoticesScreen()),
      ];
  }
}
