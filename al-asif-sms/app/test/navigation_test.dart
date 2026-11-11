import 'package:alasif_sms/navigation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the HTML-parity rule (v1.4.0): the app menu must match the final
/// HTML (Complete v7) exactly, in the HTML's own order — Dashboard,
/// Students, Attendance, Fees, Exams & Marks, Staff, Expenses, Reports,
/// Settings — and nothing else. No Academics, Profit & Loss (top level),
/// Notices, Complaints, Audit Log, Salaries or parent menu.
void main() {
  List<String> titles(String role) =>
      menuForRole(role).map((m) => m.title).toList();

  test('principal and administrator see the 9 HTML screens', () {
    const expected = [
      'Dashboard',
      'Students',
      'Attendance',
      'Fees',
      'Exams & Marks',
      'Staff',
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
      'Exams & Marks',
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
