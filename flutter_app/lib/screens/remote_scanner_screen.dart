import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../widgets/barcode_scanner_modal.dart';

class RemoteScannerScreen extends StatefulWidget {
  const RemoteScannerScreen({super.key});

  @override
  State<RemoteScannerScreen> createState() => _RemoteScannerScreenState();
}

class _RemoteScannerScreenState extends State<RemoteScannerScreen> {
  // Mode: 'sender' (Phone transmitting to PC) or 'receiver' (PC listening for scans)
  String _currentMode = 'sender';

  // Sender State
  final TextEditingController _pairCodeController = TextEditingController();
  final TextEditingController _scanInputController = TextEditingController();
  bool _isLinked = false;
  String _linkedCode = '';
  String _sendStatus = 'idle'; // idle, pushing, success, error
  String _lastSentData = '';
  final List<Map<String, String>> _senderHistory = [];

  // Receiver State
  String _hostCode = '8429';
  bool _isPolling = false;
  Timer? _pollTimer;
  final List<Map<String, dynamic>> _receivedScans = [];

  @override
  void initState() {
    super.initState();
    _generateRandomHostCode();
  }

  @override
  void dispose() {
    _pairCodeController.dispose();
    _scanInputController.dispose();
    _stopPolling();
    super.dispose();
  }

  void _generateRandomHostCode() {
    final code = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
    setState(() {
      _hostCode = code;
    });
    if (_currentMode == 'receiver') {
      _startPolling();
    }
  }

  void _startPolling() {
    _stopPolling();
    _isPolling = true;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (!mounted || !_isPolling) return;
      try {
        final res = await ApiService.pollRemoteScan(_hostCode);
        if (res['status'] == 'success' && res['data'] != null) {
          final scanText = res['data'].toString();
          if (mounted) {
            final now = DateTime.now();
            final timeStr =
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
            setState(() {
              _receivedScans.insert(0, {
                'data': scanText,
                'time': timeStr,
              });
            });

            // Automatically copy to clipboard for operator convenience
            Clipboard.setData(ClipboardData(text: scanText));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Received: $scanText (Copied to Clipboard)')),
                  ],
                ),
                backgroundColor: const Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        }
      } catch (_) {}
    });
  }

  void _stopPolling() {
    _isPolling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _handleLinkToPc() {
    final code = _pairCodeController.text.trim();
    if (code.length == 4) {
      setState(() {
        _isLinked = true;
        _linkedCode = code;
        _sendStatus = 'idle';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paired successfully to PC Terminal #$code'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _pushScan(String scannedText) async {
    final clean = scannedText.trim();
    if (clean.isEmpty) return;

    setState(() {
      _sendStatus = 'pushing';
    });

    try {
      await ApiService.pushRemoteScan(_linkedCode, clean);
      if (mounted) {
        final now = DateTime.now();
        final timeStr =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

        setState(() {
          _lastSentData = clean;
          _sendStatus = 'success';
          _senderHistory.insert(0, {'data': clean, 'time': timeStr});
          _scanInputController.clear();
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _sendStatus == 'success') {
            setState(() => _sendStatus = 'idle');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendStatus = 'error';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to transmit scan: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scansRelayedCount = _currentMode == 'sender' ? _senderHistory.length : _receivedScans.length;
    final activePin = _currentMode == 'sender' ? (_isLinked ? _linkedCode : 'UNPAIRED') : _hostCode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Executive Cockpit Header
            _buildCockpitHeader(
              isDark: isDark,
              activePin: activePin,
              scansCount: scansRelayedCount,
            ),

            // Body Container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Mode Selector Tabs
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildModeTab(
                                label: 'Smartphone Scanner Gun',
                                modeKey: 'sender',
                                icon: Icons.smartphone_rounded,
                                isDark: isDark,
                              ),
                              _buildModeTab(
                                label: 'Desktop Terminal Receiver',
                                modeKey: 'receiver',
                                icon: Icons.computer_rounded,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Mode Content
                      if (_currentMode == 'sender')
                        _buildSenderView(isDark)
                      else
                        _buildReceiverView(isDark),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCockpitHeader({
    required bool isDark,
    required String activePin,
    required int scansCount,
  }) {
    final isConnected = _currentMode == 'sender' ? _isLinked : _isPolling;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top breadcrumb tag & actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_tethering_rounded, size: 12, color: Color(0xFF818CF8)),
                        SizedBox(width: 6),
                        Text(
                          'WIRELESS HARNESS // REALTIME SCANNER & COMPANION HUB',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFFC7D2FE),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                              : const Color(0xFF64748B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isConnected
                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                : const Color(0xFF64748B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isConnected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isConnected ? 'LINK ACTIVE' : 'STANDBY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: isConnected ? const Color(0xFF6EE7B7) : const Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title & Description
              const Text(
                'Remote Barcode & E-Way Scanner',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Use any smartphone camera as a wireless physical barcode gun linked directly into your PC billing terminal.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              // KPI Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 750;
                  return isNarrow
                      ? Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildKpiCard(
                              title: 'CURRENT MODE',
                              value: _currentMode == 'sender' ? 'PHONE GUN' : 'PC RECEIVER',
                              subtitle: _currentMode == 'sender' ? 'Transmitting scans' : 'Listening on port',
                              icon: _currentMode == 'sender' ? Icons.smartphone_rounded : Icons.computer_rounded,
                              color: const Color(0xFF6366F1),
                            ),
                            _buildKpiCard(
                              title: 'STATION PIN',
                              value: activePin,
                              subtitle: '4-Digit sync channel',
                              icon: Icons.pin_rounded,
                              color: const Color(0xFF3B82F6),
                            ),
                            _buildKpiCard(
                              title: 'SCANS RELAYED',
                              value: scansCount.toString(),
                              subtitle: 'This active session',
                              icon: Icons.qr_code_scanner_rounded,
                              color: const Color(0xFF10B981),
                            ),
                            _buildKpiCard(
                              title: 'AUTO-CLIPBOARD',
                              value: 'ENABLED',
                              subtitle: 'Zero-touch paste',
                              icon: Icons.content_paste_rounded,
                              color: const Color(0xFFF59E0B),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                title: 'CURRENT MODE',
                                value: _currentMode == 'sender' ? 'PHONE GUN' : 'PC RECEIVER',
                                subtitle: _currentMode == 'sender' ? 'Transmitting scans' : 'Listening on port',
                                icon: _currentMode == 'sender' ? Icons.smartphone_rounded : Icons.computer_rounded,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'STATION PIN',
                                value: activePin,
                                subtitle: '4-Digit sync channel',
                                icon: Icons.pin_rounded,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'SCANS RELAYED',
                                value: scansCount.toString(),
                                subtitle: 'This active session',
                                icon: Icons.qr_code_scanner_rounded,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'AUTO-CLIPBOARD',
                                value: 'ENABLED',
                                subtitle: 'Zero-touch paste',
                                icon: Icons.content_paste_rounded,
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required String modeKey,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _currentMode == modeKey;

    return InkWell(
      onTap: () {
        if (_currentMode != modeKey) {
          setState(() {
            _currentMode = modeKey;
          });
          if (modeKey == 'receiver') {
            _startPolling();
          } else {
            _stopPolling();
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF4F46E5) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SENDER / PHONE SCANNER MODE ---
  Widget _buildSenderView(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: !_isLinked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6366F1), size: 32),
                ),
                const SizedBox(height: 18),
                Text(
                  'Link to PC Terminal',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the 4-digit PIN displayed on your PC screen to sync scans wirelessly.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),

                // 4-Digit Code Input
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _pairCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 14,
                      color: Color(0xFF6366F1),
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '0000',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        letterSpacing: 14,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    onChanged: (val) {
                      if (val.length == 4) {
                        _handleLinkToPc();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Link Button
                SizedBox(
                  width: 260,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.link_rounded, size: 20),
                    label: const Text('Pair to Terminal', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    onPressed: _handleLinkToPc,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Linked Header Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Paired with PC Terminal #$_linkedCode',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLinked = false;
                            _pairCodeController.clear();
                          });
                        },
                        child: const Text('Unlink', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Status Animation
                if (_sendStatus == 'success') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sent to PC: "$_lastSentData"',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF15803D),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else if (_sendStatus == 'pushing') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1))),
                        const SizedBox(width: 14),
                        Text(
                          'Syncing scan to PC screen...',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Live Camera Barcode Scanner Button
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                    label: const Text(
                      'Open Camera Barcode / QR Scanner',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    onPressed: () async {
                      final scanned = await BarcodeScannerModal.show(
                        context,
                        title: 'Wireless Terminal Scanner (#$_linkedCode)',
                        subtitle: 'Scanned barcode will be sent directly to your PC',
                      );
                      if (scanned != null && scanned.isNotEmpty) {
                        _scanInputController.text = scanned;
                        await _pushScan(scanned);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // Barcode / EWB Input
                const Text(
                  'BARCODE / E-WAY BILL NUMBER',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: TextField(
                          controller: _scanInputController,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter 12-digit E-Way Bill or scan barcode...',
                            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: InputBorder.none,
                          ),
                          onSubmitted: _pushScan,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Send to PC', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _pushScan(_scanInputController.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quick Demo Preset Scans
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDemoChip('EWB #231049281745', () => _pushScan('231049281745'), isDark),
                    _buildDemoChip('EWB #892019482710', () => _pushScan('892019482710'), isDark),
                    _buildDemoChip('GC #AP-1025', () => _pushScan('AP-1025'), isDark),
                    _buildDemoChip('GC #TN-4091', () => _pushScan('TN-4091'), isDark),
                  ],
                ),

                // Session Send History
                if (_senderHistory.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const Text(
                    'RECENT TRANSMISSIONS (THIS SESSION)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _senderHistory.length.clamp(0, 5),
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      itemBuilder: (context, idx) {
                        final item = _senderHistory[idx];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                          title: Text(
                            item['data'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          trailing: Text(
                            item['time'] ?? '',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  // --- RECEIVER / PC HOST MODE ---
  Widget _buildReceiverView(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.sensors_rounded, color: Color(0xFF6366F1), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terminal Receiver Hub',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Listening live for scans pushed from mobile devices on the network.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Host Code Display Box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PAIRING CODE FOR WORKER SMARTPHONES',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _hostCode,
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 10,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Generate New Code',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _generateRandomHostCode,
                    ),
                    const SizedBox(height: 4),
                    const Text('New PIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Live Polling Pulse Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Live Channel Connected — Any barcode scanned on phone copies here instantly.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Received Scans Log
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIVE RECEIVED SCANS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
              if (_receivedScans.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _receivedScans.clear()),
                  child: const Text('Clear Log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (_receivedScans.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(36),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.wifi_tethering_rounded,
                    size: 36,
                    color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Waiting for incoming remote scans...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text('Open this screen on a mobile phone to scan into this PC.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _receivedScans.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                ),
                itemBuilder: (context, idx) {
                  final scan = _receivedScans[idx];
                  final scanText = scan['data']?.toString() ?? '';
                  final timeStr = scan['time']?.toString() ?? '';

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    title: Text(
                      scanText,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    subtitle: Text('Received at $timeStr (Auto-copied)', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    trailing: IconButton(
                      tooltip: 'Copy to Clipboard',
                      icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF6366F1)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: scanText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied "$scanText"'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDemoChip(String label, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
