import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'system_boot_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  List<dynamic> _users = [];
  bool _isLoadingUsers = true;
  String? _errorMessage;

  Map<String, dynamic>? _selectedUser;
  String _pin = '';
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await ApiService.getPublicUsers();
      final hasAdminFallback = users.any((u) => u['id']?.toString() == 'admin');
      final fullList = [
        ...users,
        if (!hasAdminFallback)
          {'id': 'admin', 'username': 'System Admin', 'role': 'admin', 'branch': 'ALL'},
      ];
      if (mounted) {
        setState(() {
          _users = fullList;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load user profiles: $e';
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
  }

  void _handleBackToUsers() {
    setState(() {
      _selectedUser = null;
      _pin = '';
      _errorMessage = null;
    });
  }

  void _handleKeyPress(String digit) {
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
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          title: const Row(
            children: [
              Icon(Icons.dns_rounded, color: Color(0xFF38BDF8), size: 22),
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
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                  fillColor: const Color(0xFF0F172A),
                  hintText: 'http://192.168.1.xxx:5005/api',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8)),
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
                    backgroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFF334155)),
                    label: const Text('Localhost (PC)', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                    onPressed: () {
                      setModalState(() {
                        urlController.text = 'http://localhost:5005/api';
                        pingStatus = null;
                      });
                    },
                  ),
                  ActionChip(
                    backgroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFF334155)),
                    label: const Text('Android Emu (10.0.2.2)', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                          )
                        : const Icon(Icons.network_ping_rounded, size: 16),
                    label: const Text('Test Ping'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF0284C7)),
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
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
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
    );
  }

  LinearGradient _getRoleGradient(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'manager':
        return const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'operator':
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Stack(
        children: [
          // Ambient Radial Glow 1 (Top Left)
          Positioned(
            top: -120,
            left: -120,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4F46E5).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Ambient Radial Glow 2 (Bottom Right)
          Positioned(
            bottom: -150,
            right: -150,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF06B6D4).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Subtle Geometric Grid / Vignette Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0F172A).withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
          ),

          // Main Center Console
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Corporate Header with Glowing Badge
                        _buildCorporateHeader(),
                        const SizedBox(height: 24),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBE123C).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBE123C).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFFB7185)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFFFE4E6),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFFB7185)),
                                  onPressed: () => setState(() => _errorMessage = null),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Interactive Screen View (Profiles vs PIN Pad)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.04),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _selectedUser == null ? _buildUserSelectionGrid() : _buildPinAuthPad(),
                        ),

                        const SizedBox(height: 20),
                        // Dynamic Server Connection Pill
                        InkWell(
                          onTap: _showServerConfigDialog,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.dns_rounded, size: 13, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'SERVER: ${ApiService.baseUrl.replaceAll('/api', '')}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace',
                                      color: Color(0xFF94A3B8),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.settings_rounded, size: 12, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFF334155), height: 1),
                        const SizedBox(height: 16),

                        // Terminal Security Footer
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, size: 14, color: Color(0xFF64748B)),
                            SizedBox(width: 6),
                            Text(
                              'PROTECTED WORKSTATION • AUDIT TRAIL LOGGING ACTIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorporateHeader() {
    return Column(
      children: [
        // App / Logo Badge
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_shipping_rounded,
            size: 36,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ARUNACHALAM & BELL',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'ENTERPRISE LOGISTICS SUITE • SECURE TERMINAL',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF818CF8),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        // Live Status Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 3, backgroundColor: Color(0xFF34D399)),
              SizedBox(width: 6),
              Text(
                'HOST SYSTEM READY • TLS ENCRYPTED',
                style: TextStyle(
                  color: Color(0xFF34D399),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserSelectionGrid() {
    if (_isLoadingUsers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: Color(0xFF818CF8), strokeWidth: 2.5),
            ),
            SizedBox(height: 14),
            Text(
              'Authenticating Directory...',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            const Icon(Icons.person_off_rounded, size: 40, color: Color(0xFF64748B)),
            const SizedBox(height: 12),
            const Text(
              'No active operator profiles found.',
              style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Fetch'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 14, left: 4),
          child: Row(
            children: [
              Icon(Icons.badge_rounded, size: 16, color: Color(0xFF818CF8)),
              SizedBox(width: 8),
              Text(
                'SELECT OPERATOR PROFILE TO LOG IN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isVeryNarrow = constraints.maxWidth < 340;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isVeryNarrow ? 1 : 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: isVeryNarrow ? 2.6 : 1.15,
              ),
              itemCount: _users.length,
              itemBuilder: (context, index) {
            final user = _users[index];
            final role = (user['role'] ?? 'staff').toString();
            final branch = (user['branch'] ?? 'ALL').toString();
            final username = (user['username'] ?? 'User').toString();

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleUserSelect(user),
                  borderRadius: BorderRadius.circular(16),
                  hoverColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: _getRoleGradient(role),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8,
                                  color: Color(0xFFCBD5E1),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (branch.isNotEmpty && branch != 'ALL') ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF475569)),
                                ),
                                child: Text(
                                  branch,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 8,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  ],
);
  }

  Widget _buildPinAuthPad() {
    final role = (_selectedUser!['role'] ?? 'staff').toString();
    final username = (_selectedUser!['username'] ?? 'User').toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Back To Profiles Button & Active User Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: _getRoleGradient(role),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      role.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF818CF8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _isAuthenticating ? null : _handleBackToUsers,
                icon: const Icon(Icons.arrow_back_rounded, size: 14),
                label: const Text('Switch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Enter 4-Digit Security PIN',
          style: TextStyle(
            color: Color(0xFFCBD5E1),
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 18),

        // Glowing PIN Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = _pin.length > index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: isFilled ? 18 : 14,
              height: isFilled ? 18 : 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? const Color(0xFF818CF8) : const Color(0xFF1E293B),
                border: Border.all(
                  color: isFilled ? const Color(0xFFA5B4FC) : const Color(0xFF475569),
                  width: 1.5,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),

        const SizedBox(height: 24),

        // High-Speed Tactile Numpad
        SizedBox(
          width: 290,
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              for (var i = 1; i <= 9; i++) _buildTactileKeypadButton(i.toString()),
              _buildKeypadEmptySlot(),
              _buildTactileKeypadButton('0'),
              _buildTactileKeypadButton('del'),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Authenticate Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_pin.length == 4 && !_isAuthenticating) ? _handleLogin : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              disabledBackgroundColor: const Color(0xFF334155),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isAuthenticating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Access System Console',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadEmptySlot() {
    return const SizedBox.shrink();
  }

  Widget _buildTactileKeypadButton(String action) {
    final isDel = action == 'del';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isAuthenticating
            ? null
            : () {
                if (isDel) {
                  _handleDelete();
                } else {
                  _handleKeyPress(action);
                }
              },
        borderRadius: BorderRadius.circular(14),
        hoverColor: const Color(0xFF4F46E5).withValues(alpha: 0.25),
        splashColor: const Color(0xFF818CF8).withValues(alpha: 0.3),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: isDel
              ? const Icon(Icons.backspace_rounded, color: Color(0xFF94A3B8), size: 20)
              : Text(
                  action,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
