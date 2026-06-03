import 'package:flutter/material.dart';
import '../data/legal_content.dart';
import '../services/auth_service.dart';
import 'legal_page_screen.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const AuthScreen({super.key, required this.onSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _showVerification = false;
  bool _isCheckingVerification = false;
  String? _error;
  String _registeredEmail = '';
  bool _obscurePassword = true;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  int _authMethod = 0;
  final _phoneCtrl = TextEditingController();
  final _smsCodeCtrl = TextEditingController();
  bool _phoneCodeSent = false;
  bool _phoneLoading = false;
  String _phoneNumber = '';

  @override
  void initState() {
    super.initState();
    if (_auth.isLoggedIn && !_auth.isEmailVerified) {
      _registeredEmail = _auth.currentUser?.email ?? '';
      _showVerification = true;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _smsCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showVerification) return _buildVerificationScreen();
    return _buildAuthScreen();
  }

  Widget _buildVerificationScreen() {
    final theme = Theme.of(context);
    _startAutoVerificationCheck();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: _isCheckingVerification
                      ? SizedBox(
                          width: 30, height: 30,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.amber),
                        )
                      : const Icon(Icons.mark_email_unread, color: Colors.amber, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'E-Mail bestätigen',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Wir haben eine Bestätigungs-E-Mail an',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _registeredEmail,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'gesendet. Klicken Sie auf den Link in der E-Mail und warten Sie, '
                  'bis die Bestätigung automatisch erkannt wird.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isCheckingVerification ? null : () async {
                      setState(() => _isCheckingVerification = true);
                      final verified = await _auth.verifyEmail();
                      if (!mounted) return;
                      setState(() => _isCheckingVerification = false);
                      if (verified) {
                        setState(() => _showVerification = false);
                        widget.onSuccess();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('E-Mail wurde noch nicht bestätigt. Bitte klicken Sie auf den Link in der E-Mail.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Bestätigung prüfen'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await _auth.sendVerificationEmail();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bestätigungs-E-Mail erneut gesendet!')),
                    );
                  },
                  child: const Text('E-Mail erneut senden'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _auth.logout();
                    setState(() {
                      _showVerification = false;
                      _isLogin = true;
                    });
                  },
                  child: const Text('Andere E-Mail verwenden'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startAutoVerificationCheck() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted || !_showVerification) return;
      if (_auth.isEmailVerified) {
        setState(() => _showVerification = false);
        widget.onSuccess();
        return;
      }
      setState(() => _isCheckingVerification = true);
      final verified = await _auth.verifyEmail();
      if (!mounted) return;
      setState(() => _isCheckingVerification = false);
      if (!verified) {
        _startAutoVerificationCheck();
      } else {
        setState(() => _showVerification = false);
        widget.onSuccess();
      }
    });
  }

  Widget _buildAuthScreen() {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'ServicePlace',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Melden Sie sich an',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildMethodTab(0, Icons.email_outlined, 'E-Mail'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMethodTab(1, Icons.phone_outlined, 'Telefon'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_authMethod == 0) _buildEmailAuth(theme),
                if (_authMethod == 1) _buildPhoneAuth(theme),
                const SizedBox(height: 32),
                _buildLegalLinks(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegalLinks() {
    return Column(
      children: [
        Divider(color: Colors.grey[200]),
        const SizedBox(height: 12),
        Text(
          'Rechtliche Hinweise',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            _legalLink('Impressum', LegalContent.impressum),
            _legalLink('Datenschutz', LegalContent.datenschutz),
            _legalLink('Nutzungsbedingungen', LegalContent.nutzungsbedingungen),
            _legalLink('AGB', LegalContent.agb),
          ],
        ),
      ],
    );
  }

  Widget _legalLink(String label, LegalContent content) {
    return TextButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LegalPageScreen(content: content)),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    );
  }

  Widget _buildMethodTab(int index, IconData icon, String label) {
    final isActive = _authMethod == index;
    return GestureDetector(
      onTap: () => setState(() {
        _authMethod = index;
        _error = null;
        _phoneCodeSent = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailAuth(ThemeData theme) {
    return Column(
      children: [
        if (!_isLogin)
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
          ),
        if (!_isLogin) const SizedBox(height: 16),
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'E-Mail-Adresse',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordCtrl,
          decoration: InputDecoration(
            labelText: 'Passwort',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _buildErrorBox(),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isLoading ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_isLogin ? 'Anmelden' : 'Konto erstellen', style: const TextStyle(fontSize: 16)),
          ),
        ),
        if (_isLogin) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _showPasswordResetDialog,
            child: Text(
              'Passwort vergessen?',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('oder', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        if (AuthService().isGoogleSignInAvailable) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _signInWithGoogle,
              icon: const Icon(Icons.login),
              label: const Text('Mit Google anmelden'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _isLogin = !_isLogin;
              _error = null;
            });
          },
          child: Text(
            _isLogin ? 'Noch kein Konto? Jetzt registrieren' : 'Bereits ein Konto? Anmelden',
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneAuth(ThemeData theme) {
    return Column(
      children: [
        if (!_phoneCodeSent) ...[
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Telefonnummer',
              hintText: 'z.B. +49 123 456789',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendPhoneCode(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _buildErrorBox(),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _phoneLoading ? null : _sendPhoneCode,
              icon: _phoneLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                    )
                  : const Icon(Icons.smartphone),
              label: Text(_phoneLoading ? 'Code wird gesendet...' : 'Bestätigungscode senden'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ] else ...[
          Text(
            'Code wurde an $_phoneNumber gesendet',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _smsCodeCtrl,
            decoration: const InputDecoration(
              labelText: 'Bestätigungscode',
              hintText: 'Code eingeben',
              prefixIcon: Icon(Icons.sms),
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verifyPhoneCode(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _buildErrorBox(),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _phoneLoading ? null : _verifyPhoneCode,
              icon: _phoneLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                    )
                  : const Icon(Icons.check),
              label: Text(_phoneLoading ? 'Wird überprüft...' : 'Bestätigen'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _phoneCodeSent = false;
                _error = null;
                _smsCodeCtrl.clear();
              });
            },
            child: const Text('Andere Telefonnummer verwenden'),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showPasswordResetDialog() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Passwort zurücksetzen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Geben Sie Ihre E-Mail-Adresse ein. Wir senden Ihnen einen Link zum Zurücksetzen des Passworts.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'E-Mail-Adresse',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              final error = await _auth.resetPassword(emailCtrl.text.trim());
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('E-Mail zum Zurücksetzen wurde gesendet!')),
                );
              }
            },
            child: const Text('Senden'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPhoneCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Bitte geben Sie eine Telefonnummer ein.');
      return;
    }
    setState(() {
      _error = null;
      _phoneLoading = true;
    });
    _phoneNumber = phone;
    _auth.sendPhoneCode(
      phoneNumber: phone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() {
          _phoneCodeSent = true;
          _phoneLoading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _error = error;
          _phoneLoading = false;
        });
      },
      onAutoVerified: () {
        if (!mounted) return;
        widget.onSuccess();
      },
    );
  }

  Future<void> _verifyPhoneCode() async {
    final code = _smsCodeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Bitte geben Sie den Bestätigungscode ein.');
      return;
    }
    setState(() {
      _error = null;
      _phoneLoading = true;
    });
    final error = await _auth.verifyPhoneCode(code);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _error = error;
        _phoneLoading = false;
      });
    } else {
      widget.onSuccess();
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      final error = await _auth.signInWithGoogle();
      if (error != null) {
        if (!mounted) return;
        setState(() {
          _error = error;
          _isLoading = false;
        });
        return;
      }
      if (!mounted) return;
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Google Sign-In fehlgeschlagen: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      String? error;
      if (_isLogin) {
        error = await _auth.login(_emailCtrl.text, _passwordCtrl.text);
      } else {
        error = await _auth.register(_emailCtrl.text, _passwordCtrl.text, name: _nameCtrl.text.trim());
      }

      if (!mounted) return;

      if (error != null) {
        if (error.contains('E-Mail-Adresse')) {
          _registeredEmail = _emailCtrl.text.trim();
          setState(() {
            _showVerification = true;
            _isLoading = false;
          });
          return;
        }
        setState(() {
          _error = error;
          _isLoading = false;
        });
      } else if (!_isLogin) {
        _registeredEmail = _emailCtrl.text.trim();
        setState(() {
          _showVerification = true;
          _isLoading = false;
        });
      } else {
        widget.onSuccess();
      }
    } catch (e) {
      setState(() {
        _error = 'Ein Fehler ist aufgetreten: $e';
        _isLoading = false;
      });
    }
  }
}
