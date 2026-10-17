import 'package:flutter/material.dart';

import '../../models/staff.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';
import 'package:provider/provider.dart';

class StaffDetailScreen extends StatefulWidget {
  final int id;
  const StaffDetailScreen({super.key, required this.id});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  StaffMember? _staff;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _staff = await context.read<StaffProvider>().detail(widget.id);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Staff Detail'),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? EmptyState(message: _error!, icon: Icons.cloud_off_outlined)
              : _body(),
    );
  }

  Widget _body() {
    final s = _staff!;
    return ListView(
      children: [
        InfoCard(title: 'Profile', children: [
          InfoRow(label: 'Name', value: s.name),
          InfoRow(label: 'Type', value: s.staffType == 'teaching' ? 'Teaching' : 'Non-teaching'),
          InfoRow(label: 'Designation', value: s.designation),
          InfoRow(label: 'Phone', value: s.phone),
          InfoRow(label: 'CNIC', value: s.cnic),
          InfoRow(label: 'Joining date', value: fmtDate(s.joiningDate)),
          InfoRow(label: 'Status', value: s.status),
        ]),
        InfoCard(title: 'Salary', children: [
          InfoRow(label: 'Monthly basic', value: fmtMoney(s.salaryMonthly)),
        ]),
      ],
    );
  }
}
