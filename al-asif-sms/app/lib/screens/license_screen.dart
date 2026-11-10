import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../services/license_service.dart';
import '../widgets/school_app_bar.dart';
import 'boot_screen.dart';

/// License-key entry screen.
///
/// Shown at boot when no valid license is stored (blocking — the app
/// cannot be used without a key), and from Settings > License to enter or
/// change the key. A key is validated fully offline (HMAC signature +
/// product + expiry); no internet is needed to activate.
class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key, this.fromSettings = false});

  /// True when opened from Settings (shows a back button; success just
  /// pops back). False at boot (blocking; success enters the app).
  final bool fromSettings;

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _messageOk = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    final status = LicenseService.instance.status;
    if (status.key != null && status.key!.isNotEmpty) {
      _keyController.text = status.key!;
    }
    LicenseService.instance.getDeviceId().then((id) {
      if (mounted) setState(() => _deviceId = id);
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _message = 'Pehle license key likhein.';
        _messageOk = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await LicenseService.instance.activate(key);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.valid) {
      setState(() {
        _message = result.reason ?? 'Key valid nahi hai.';
        _messageOk = false;
      });
      return;
    }
    setState(() {
      _message =
          'License active ho gayi — expiry: ${_fmtDate(result.expiryDate!)}'
          ' (${result.daysLeft} din reh gaye).';
      _messageOk = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    if (widget.fromSettings) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = LicenseService.instance.status;
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: widget.fromSettings
          ? const SchoolAppBar(title: 'License')
          : null,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 84,
                      width: 84,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.school,
                        size: 64,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppConfig.schoolNameRegistered,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'License Key',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Is app ko istemal karne ke liye license key chahiye. '
                      'Key sirf aik customer ke liye hoti hai — dosre school '
                      'ki key yahan nahi chalegi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    if (status.message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        status.message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF0F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Is device ki ID',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _deviceId ?? 'Loading...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Device-locked key ke liye ye ID Daniel ko '
                            'bhejein — key sirf isi device par chalegi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          if (_deviceId != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _deviceId!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Device ID copy ho gayi.'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy Device ID'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _keyController,
                      inputFormatters: [_LicenseKeyFormatter()],
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 17,
                        letterSpacing: 1,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'License key',
                        hintText: 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _busy ? null : _activate,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Activate'),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _messageOk
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Nayi key chahiye ya key khatam ho gayi ho to rabta karein:\n${LicenseService.supportPhone}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _fmtDate(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Upper-cases the key, drops anything outside the Crockford alphabet and
/// inserts a dash every 5 characters (max 25 key characters).
class _LicenseKeyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clean = newValue.text
        .toUpperCase()
        .replaceAll(RegExp(r'[^0-9A-Z]'), '');
    final filtered = clean
        .split('')
        .where((c) => LicenseService.alphabet.contains(c))
        .join();
    final limited =
        filtered.length > 25 ? filtered.substring(0, 25) : filtered;
    final groups = <String>[];
    for (var i = 0; i < limited.length; i += 5) {
      groups.add(limited.substring(
        i,
        i + 5 > limited.length ? limited.length : i + 5,
      ));
    }
    final text = groups.join('-');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
