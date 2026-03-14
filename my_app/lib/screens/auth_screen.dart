import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'user_dashboard.dart';
import 'admin_dashboard.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Login fields
  final _loginEmail = TextEditingController();
  final _loginPass  = TextEditingController();

  // Sign-up fields
  final _signUser    = TextEditingController();
  final _signEmail   = TextEditingController();
  final _signPass    = TextEditingController();
  final _signConfirm = TextEditingController();

  bool _loginPassVisible = false;
  bool _signPassVisible  = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose(); _loginPass.dispose();
    _signUser.dispose(); _signEmail.dispose();
    _signPass.dispose(); _signConfirm.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (_loginEmail.text.trim().isEmpty || _loginPass.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final err = await AuthService.login(_loginEmail.text, _loginPass.text);
    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _loading = false; });
      return;
    }
    _navigate();
  }

  Future<void> _doSignUp() async {
    if (_signUser.text.trim().isEmpty || _signEmail.text.trim().isEmpty ||
        _signPass.text.isEmpty || _signConfirm.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (_signPass.text != _signConfirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final err = await AuthService.signUp(
        _signUser.text, _signEmail.text, _signPass.text);
    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _loading = false; });
      return;
    }
    _navigate();
  }

  Future<void> _navigate() async {
    final user = await AuthService.currentUser();
    if (!mounted || user == null) return;
    final dest = user.role == 'admin'
        ? const AdminDashboard()
        : UserDashboard(user: user);
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => dest));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(children: [
              // Logo
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF2D9CDB).withOpacity(0.4),
                    blurRadius: 24, spreadRadius: 2,
                  )],
                ),
                child: const Icon(Icons.document_scanner_rounded,
                    color: Color(0xFF2D9CDB), size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Object Learner',
                  style: TextStyle(color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              const Text('AI-powered object detection',
                  style: TextStyle(color: Color(0xFF8B9CB6), fontSize: 13)),
              const SizedBox(height: 32),

              // Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(children: [
                  // Tab bar
                  Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tab,
                      indicator: BoxDecoration(
                        color: const Color(0xFF2D9CDB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: const Color(0xFF8B9CB6),
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      tabs: const [Tab(text: 'Login'), Tab(text: 'Sign Up')],
                    ),
                  ),

                  SizedBox(
                    height: _tab.index == 0 ? 280 : 360,
                    child: TabBarView(
                      controller: _tab,
                      children: [_loginForm(), _signUpForm()],
                    ),
                  ),
                ]),
              ),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE74C3C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFE74C3C).withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFE74C3C), size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(
                        color: Color(0xFFE74C3C), fontSize: 13))),
                  ]),
                ),
              ],

              const SizedBox(height: 20),
              const Text('Admin account is set up in Firebase Console.',
                  style: TextStyle(color: Color(0xFF8B9CB6), fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _loginForm() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    child: Column(children: [
      _field(_loginEmail, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress),
      const SizedBox(height: 12),
      _field(_loginPass, 'Password', Icons.lock_outline_rounded,
          obscure: !_loginPassVisible,
          suffix: _eyeBtn(_loginPassVisible,
              () => setState(() => _loginPassVisible = !_loginPassVisible))),
      const SizedBox(height: 20),
      _btn('Login', _loading ? null : _doLogin),
    ]),
  );

  Widget _signUpForm() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    child: Column(children: [
      _field(_signUser, 'Username', Icons.person_outline_rounded),
      const SizedBox(height: 12),
      _field(_signEmail, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress),
      const SizedBox(height: 12),
      _field(_signPass, 'Password', Icons.lock_outline_rounded,
          obscure: !_signPassVisible,
          suffix: _eyeBtn(_signPassVisible,
              () => setState(() => _signPassVisible = !_signPassVisible))),
      const SizedBox(height: 12),
      _field(_signConfirm, 'Confirm Password', Icons.lock_outline_rounded, obscure: true),
      const SizedBox(height: 20),
      _btn('Create Account', _loading ? null : _doSignUp),
    ]),
  );

  Widget _eyeBtn(bool visible, VoidCallback toggle) => IconButton(
    icon: Icon(visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: const Color(0xFF8B9CB6), size: 18),
    onPressed: toggle,
  );

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false, Widget? suffix,
       TextInputType keyboard = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8B9CB6), fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF8B9CB6), size: 18),
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFF0D1117),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF30363D))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF30363D))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2D9CDB), width: 1.5)),
        ),
      );

  Widget _btn(String label, VoidCallback? onTap) => SizedBox(
    width: double.infinity, height: 48,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2D9CDB),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF2D9CDB).withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _loading
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    ),
  );
}
