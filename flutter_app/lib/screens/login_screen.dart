import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import 'system_boot_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // React stone & indigo palette
  static const Color _stone950 = Color(0xFF0C0A09);
  static const Color _stone900 = Color(0xFF1C1917);
  static const Color _stone800 = Color(0xFF292524);
  static const Color _stone700 = Color(0xFF44403C);
  static const Color _stone500 = Color(0xFF78716C);
  static const Color _stone400 = Color(0xFFA8A29E);
  static const Color _indigo500 = Color(0xFF6366F1);
  static const Color _indigo600 = Color(0xFF4F46E5);
  static const Color _indigo700 = Color(0xFF4338CA);

  List<dynamic> _users = [];
  bool _isLoadingUsers = true;
  String? _errorMessage;
  String? _lastUserId;
  final FocusNode _pinFocusNode = FocusNode();

  Map<String, dynamic>? _selectedUser;
  String _pin = '';
  bool _isAuthenticating = false;
  bool _showOnScreenNumpad = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLastId = prefs.getString('last_login_user_id');
      final users = await ApiService.getPublicUsers();
      final hasAdminFallback = users.any((u) => u['id']?.toString() == 'admin');
      final fullList = [
        ...users,
        if (!hasAdminFallback)
          {'id': 'admin', 'username': 'System Admin', 'role': 'admin', 'branch': 'ALL'},
      ];
      if (savedLastId != null) {
        fullList.sort((a, b) {
          final aMatch = a['id']?.toString() == savedLastId ? 0 : 1;
          final bMatch = b['id']?.toString() == savedLastId ? 0 : 1;
          return aMatch.compareTo(bMatch);
        });
      }
      if (mounted) {
        setState(() {
          _lastUserId = savedLastId;
          _users = fullList;
          _isLoadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to reach server. Check your connection or server URL.';
          _isLoadingUsers = false;
        });
      }
    }
  }

  void _handleUserSelect(Map<String, dynamic> user) {
    setState(() {
      _selectedUser = user;
      _pin = '';
      _errorMessage = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pinFocusNode.requestFocus();
    });
  }

  void _handleBackToUsers() {
    setState(() {
      _selectedUser = null;
      _pin = '';
      _errorMessage = null;
      _showOnScreenNumpad = false;
    });
  }

  void _handleKeyPress(String digit) {
    if (_isAuthenticating) return;
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _errorMessage = null;
      });
      if (_pin.length == 4) {
        _handleLogin();
      }
    }
  }

  void _handleDelete() {
    if (_isAuthenticating) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_pin.length != 4 || _selectedUser == null) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      await AuthService.login(_selectedUser!['id'], _pin);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_login_user_id', _selectedUser!['id'].toString());
      } catch (_) {}
      if (mounted) {
        final role = (_selectedUser!['role'] ?? '').toString().toUpperCase();
        final branch = (_selectedUser!['branch'] ?? '').toString().toUpperCase();
        final isAdmin = role == 'ADMIN' || branch == 'ALL';

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SystemBootScreen(isAdmin: isAdmin),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _pin = '';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  void _showServerConfigDialog() {
    final urlController = TextEditingController(text: ApiService.baseUrl);
    String? pingStatus;
    bool isPinging = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: _stone900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _stone800),
          ),
          title: const Row(
            children: [
              Icon(Icons.dns_rounded, color: Color(0xFF818CF8), size: 22),
              SizedBox(width: 10),
              Text(
                'Server Endpoint Config',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set the backend server URL for this device (PC localhost, Android emulator, or LAN IP):',
                style: TextStyle(color: _stone400, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: urlController,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _stone950,
                  hintText: 'http://192.168.1.xxx:5005/api',
                  hintStyle: const TextStyle(color: _stone500, fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _stone800),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _stone800),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _indigo500),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    backgroundColor: _stone950,
                    side: const BorderSide(color: _stone800),
                    label: const Text('Localhost (PC)', style: TextStyle(color: Color(0xFFD6D3D1), fontSize: 11)),
                    onPressed: () {
                      setModalState(() {
                        urlController.text = 'http://localhost:5005/api';
                        pingStatus = null;
                      });
                    },
                  ),
                  ActionChip(
                    backgroundColor: _stone950,
                    side: const BorderSide(color: _stone800),
                    label: const Text('Android Emu (10.0.2.2)', style: TextStyle(color: Color(0xFFD6D3D1), fontSize: 11)),
                    onPressed: () {
                      setModalState(() {
                        urlController.text = 'http://10.0.2.2:5005/api';
                        pingStatus = null;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: isPinging
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _indigo500),
                          )
                        : const Icon(Icons.network_ping_rounded, size: 16),
                    label: const Text('Test Ping'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF818CF8),
                      side: const BorderSide(color: _indigo600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isPinging
                        ? null
                        : () async {
                            setModalState(() {
                              isPinging = true;
                              pingStatus = null;
                            });
                            final original = ApiService.baseUrl;
                            ApiService.baseUrl = urlController.text.trim();
                            final ok = await ApiService.checkHealth();
                            ApiService.baseUrl = original;
                            setModalState(() {
                              isPinging = false;
                              pingStatus = ok ? 'SUCCESS: Connected!' : 'FAILED: Host Unreachable';
                            });
                          },
                  ),
                  const SizedBox(width: 12),
                  if (pingStatus != null)
                    Expanded(
                      child: Text(
                        pingStatus!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: pingStatus!.startsWith('SUCCESS') ? const Color(0xFF34D399) : const Color(0xFFFB7185),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _stone400)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final newUrl = urlController.text.trim();
                await ApiService.setCustomBaseUrl(newUrl);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  setState(() {
                    _isLoadingUsers = true;
                    _errorMessage = null;
                  });
                  _fetchUsers();
                }
              },
              child: const Text('Save & Reconnect', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    ).then((_) => urlController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 640;

    return Scaffold(
      backgroundColor: _stone950,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 576),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo Header (1:1 React Login.jsx)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_indigo500, _indigo700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _indigo500.withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Transport ERP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enterprise Authentication',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _stone400,
                  ),
                ),
                const SizedBox(height: 32),

                // Login Card (bg-stone-900 rounded-3xl border-stone-800)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isDesktop ? 32 : 24),
                  decoration: BoxDecoration(
                    color: _stone900,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _stone800),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 36,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _selectedUser == null
                        ? _buildUserSelectionStep(isDesktop)
                        : _buildPinEntryStep(isDesktop),
                  ),
                ),

                const SizedBox(height: 20),

                // Subtle Footer Pills (Server Config + Version / Update Check)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InkWell(
                      onTap: _showServerConfigDialog,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _stone900,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _stone800),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.dns_rounded, size: 13, color: _indigo500),
                            const SizedBox(width: 6),
                            Text(
                              'SERVER: ${ApiService.baseUrl.replaceAll('/api', '')}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: _stone400,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.settings_rounded, size: 12, color: _stone500),
                          ],
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Click to check for Web / APK updates',
                      child: InkWell(
                        onTap: () => UpdateService.checkForUpdate(context, manual: true),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _stone900,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _indigo500.withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_outlined, size: 13, color: Color(0xFF818CF8)),
                              const SizedBox(width: 6),
                              Text(
                                UpdateService.buildLabel,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFC7D2FE),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(Icons.system_update_rounded, size: 12, color: Color(0xFF818CF8)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSelectionStep(bool isDesktop) {
    return Column(
      key: const ValueKey('user-grid'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Select your profile',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        if (_isLoadingUsers)
          const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: _indigo500, strokeWidth: 3),
          )
        else if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFB7185),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _fetchUsers,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry Connection', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC7D2FE),
                    side: BorderSide(color: _indigo500.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 3 : 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.02,
              ),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final u = _users[index] as Map<String, dynamic>;
                final String username = (u['username'] ?? 'User').toString();
                final String role = (u['role'] ?? 'worker').toString();
                final String branch = (u['branch'] ?? 'MAIN').toString().toUpperCase();
                final bool isAdmin = role.toLowerCase() == 'admin';
                final bool isLastUsed = _lastUserId != null && u['id']?.toString() == _lastUserId;

                return Material(
                  color: _stone800,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => _handleUserSelect(u),
                    borderRadius: BorderRadius.circular(16),
                    hoverColor: _stone700.withValues(alpha: 0.7),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isLastUsed ? _indigo500 : _stone700,
                          width: isLastUsed ? 1.6 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAdmin
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                  : _indigo500.withValues(alpha: 0.2),
                            ),
                            child: Icon(
                              Icons.account_circle_outlined,
                              size: 27,
                              color: isAdmin
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFF818CF8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                role.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _stone400,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: branch == 'AP_BNG'
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
                                      : const Color(0xFF10B981).withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  branch == 'AP_BNG' ? 'AP BNG' : branch,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: branch == 'AP_BNG'
                                        ? const Color(0xFFFCD34D)
                                        : const Color(0xFF6EE7B7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isLastUsed) ...[
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: _indigo500.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'LAST USED',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFC7D2FE),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPinEntryStep(bool isDesktop) {
    final String username = (_selectedUser?['username'] ?? 'User').toString();
    final String role = (_selectedUser?['role'] ?? 'worker').toString();
    final bool isAdmin = role.toLowerCase() == 'admin';
    final bool canSubmit = _pin.length == 4 && !_isAuthenticating;
    final bool showNumpad = !isDesktop || _showOnScreenNumpad;

    return Focus(
      key: ValueKey('pin-$username'),
      focusNode: _pinFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.backspace) {
          _handleDelete();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
          if (_pin.length == 4 && !_isAuthenticating) _handleLogin();
          return KeyEventResult.handled;
        }
        final ch = event.character;
        if (ch != null && ch.length == 1 && ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
          _handleKeyPress(ch);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _handleBackToUsers,
            icon: const Icon(Icons.arrow_back_rounded, size: 16, color: _stone400),
            label: const Text(
              'Back to Users',
              style: TextStyle(
                color: _stone400,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Selected User Avatar & Greeting
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isAdmin
                ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                : _indigo500.withValues(alpha: 0.2),
          ),
          child: Icon(
            Icons.account_circle_outlined,
            size: 36,
            color: isAdmin ? const Color(0xFFFBBF24) : const Color(0xFF818CF8),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hi, $username',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isDesktop && !showNumpad
              ? 'Type your 4-digit PIN on keyboard'
              : 'Enter your 4-digit PIN',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _stone400,
          ),
        ),
        const SizedBox(height: 24),

        // PIN Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final filled = _pin.length > i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? _indigo500 : _stone700,
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: _indigo500.withValues(alpha: 0.6),
                          blurRadius: 15,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        if (_errorMessage != null) ...[
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFB7185),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 10),

        if (showNumpad) ...[
          // Numpad (max-w-[280px])
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                for (var d = 1; d <= 9; d++) _buildNumKey('$d'),
                const SizedBox.shrink(),
                _buildNumKey('0'),
                _buildNumKey('del'),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 12),

        // Access System Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: canSubmit ? _handleLogin : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? _indigo600 : _stone800,
              disabledBackgroundColor: _stone800,
              foregroundColor: Colors.white,
              disabledForegroundColor: _stone500,
              elevation: canSubmit ? 6 : 0,
              shadowColor: _indigo500.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isAuthenticating ? 'Authenticating...' : 'Access System',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() => _showOnScreenNumpad = !_showOnScreenNumpad),
            icon: Icon(
              _showOnScreenNumpad ? Icons.keyboard_hide_rounded : Icons.dialpad_rounded,
              size: 14,
              color: _stone400,
            ),
            label: Text(
              _showOnScreenNumpad ? 'Hide on-screen keypad' : 'Use on-screen keypad',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _stone400,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
        ],
      ),
    );
  }

  Widget _buildNumKey(String action) {
    final isDelete = action == 'del';
    return Material(
      color: _stone950,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isDelete ? _handleDelete : () => _handleKeyPress(action),
        borderRadius: BorderRadius.circular(16),
        hoverColor: _stone800,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _stone800),
          ),
          alignment: Alignment.center,
          child: Text(
            isDelete ? '⌫' : action,
            style: TextStyle(
              fontSize: isDelete ? 18 : 20,
              fontWeight: FontWeight.w700,
              color: isDelete ? _stone400 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
