import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/academics_provider.dart';
import '../../providers/fees_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/school_app_bar.dart';
import '../../widgets/ui_helpers.dart';

class ChallanGenerateScreen extends StatefulWidget {
  const ChallanGenerateScreen({super.key});

  @override
  State<ChallanGenerateScreen> createState() => _ChallanGenerateScreenState();
}

class _ChallanGenerateScreenState extends State<ChallanGenerateScreen> {
  int? _classId;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  final Set<int> _headIds = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademicsProvider>().loadClasses();
      context.read<FeesProvider>().loadHeads();
    });
  }

  Future<void> _generate() async {
    if (_classId == null) {
      showSnack(context, 'Select a class.', error: true);
      return;
    }
    if (_headIds.isEmpty) {
      showSnack(context, 'Select at least one fee head.', error: true);
      return;
    }
    final ok = await confirmDialog(context, 'Generate challans',
        'Generate challans for the whole class for ${monthName(_month)} $_year?');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final created = await context.read<FeesProvider>().generateChallans(
          classId: _classId!,
          month: _month,
          year: _year,
          headIds: _headIds.toList());
      if (!mounted) return;
      showSnack(context, '$created challans generated.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<AcademicsProvider>().classes;
    final heads = context.watch<FeesProvider>().heads;
    final loadingHeads = context.watch<FeesProvider>().loading;
    return Scaffold(
      appBar: const SchoolAppBar(title: 'Generate Challans'),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          DropdownButtonFormField<int?>(
            value: _classId,
            decoration: fieldDecoration('Class *'),
            items: classes
                .map((c) => DropdownMenuItem<int?>(
                    value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() => _classId = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _month,
                  decoration: fieldDecoration('Month'),
                  items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(monthName(i + 1)))),
                  onChanged: (v) => setState(() => _month = v ?? _month),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _year,
                  decoration: fieldDecoration('Year'),
                  items: [for (var y = _year - 1; y <= _year + 1; y++) y]
                      .map((y) => DropdownMenuItem(
                          value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) => setState(() => _year = v ?? _year),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Fee heads',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (loadingHeads && heads.isEmpty)
            const LoadingView()
          else
            ...heads.map((h) => CheckboxListTile(
                  value: _headIds.contains(h.id),
                  title: Text(h.name),
                  subtitle: Text(h.frequency),
                  secondary: Text(fmtMoney(h.amount),
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _headIds.add(h.id);
                    } else {
                      _headIds.remove(h.id);
                    }
                  }),
                )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.receipt),
              label: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Generate Challans'),
              onPressed: _busy ? null : _generate,
            ),
          ),
        ],
      ),
    );
  }
}
