import 'package:alasif_sms/navigation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the HTML-parity rule (v1.3.6): the app menu must match the final
/// HTML (Complete v7) exactly — Dashboard, Students, Staff, Fees, Exams,
/// Attendance, Expenses, Reports, Settings — and nothing else. No Academics,
/// Profit & Loss (top level), Notices, Complaints, Audit Log, Salaries or
/// parent menu.
void main() {
  List<String> titles(String role) =>
      menuForRole(role).map((m) => m.title).toList();

  test('principal and administrator see the 9 HTML screens', () {
    const expected = [
      'Dashboard',
      'Students',
      'Staff',
      'Fees',
      'Exams',
      'Attendance',
      'Expenses',
      'Reports',
      'Settings',
    ];
    expect(titles('principal'), expected);
    expect(titles('administrator'), expected);
  });

  test('teacher hides Fees, Expenses, Staff and Settings', () {
    expect(titles('teacher'), [
      'Dashboard',
      'Students',
      'Attendance',
      'Exams',
      'Reports',
    ]);
  });

  test('accountant sees only finance screens', () {
    expect(titles('accountant'), ['Fees', 'Expenses', 'Reports']);
  });

  test('unknown roles see nothing', () {
    expect(titles('parent'), isEmpty);
    expect(titles('nobody'), isEmpty);
  });
}
