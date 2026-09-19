import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/tracker_view_model.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Personal
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Step 2: Wallet
  final Map<String, bool> _walletSelected = {
    'MTN Mobile Money': true,
    'Airtel Money': true,
    'Cash': true,
    'Bank': true,
  };
  final Map<String, TextEditingController> _walletBalanceCtrls = {
    'MTN Mobile Money': TextEditingController(text: '0'),
    'Airtel Money': TextEditingController(text: '0'),
    'Cash': TextEditingController(text: '0'),
    'Bank': TextEditingController(text: '0'),
  };
  final Map<String, TextEditingController> _walletDetailCtrls = {
    'MTN Mobile Money': TextEditingController(),
    'Airtel Money': TextEditingController(),
    'Cash': TextEditingController(),
    'Bank': TextEditingController(),
  };

  // Step 3: Income
  String _incomeSource = 'salary';
  final _occupationCtrl = TextEditingController();
  final _monthlyIncomeCtrl = TextEditingController();

  // Step 4: Security
  final _pinCtrl = TextEditingController();
  final _pinConfirmCtrl = TextEditingController();
  bool _enableLock = true;
  bool _obscurePin = true;

  // Step 5: Preferences
  String _currency = 'UGX';
  bool _darkMode = false;
  bool _notifications = true;

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    for (final c in _walletBalanceCtrls.values) {
      c.dispose();
    }
    for (final c in _walletDetailCtrls.values) {
      c.dispose();
    }
    _occupationCtrl.dispose();
    _monthlyIncomeCtrl.dispose();
    _pinCtrl.dispose();
    _pinConfirmCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep == 1) {
      if (_nameCtrl.text.trim().isEmpty) {
        _showSnack('Please enter your username');
        return;
      }
      if (_phoneCtrl.text.trim().isEmpty) {
        _showSnack('Please enter your phone number');
        return;
      }
    }
    if (_currentStep == 4) {
      if (_enableLock) {
        if (_pinCtrl.text.length < 4) {
          _showSnack('PIN must be at least 4 digits');
          return;
        }
        if (_pinCtrl.text != _pinConfirmCtrl.text) {
          _showSnack('PINs do not match');
          return;
        }
      }
    }
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _completeOnboarding();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _completeOnboarding() async {
    final vm = context.read<TrackerViewModel>();
    // Update existing seeded wallets with user-provided balances and details
    for (final entry in _walletSelected.entries) {
      final bal = double.tryParse(_walletBalanceCtrls[entry.key]!.text.replaceAll(',', '')) ?? 0;
      final detail = _walletDetailCtrls[entry.key]!.text.trim();
      final existing = vm.wallets.where((w) => w.name == entry.key).toList();
      if (existing.isNotEmpty) {
        final w = existing.first;
        // If wallet is deselected, we could keep it but onboarding keeps all; for now update balance if selected
        if (entry.value) {
          w.openingBalance = bal;
          w.currentBalance = bal;
          // If detail provided for bank/mobile, append to name for personalization (e.g., "Bank – Stanbic")
          if (detail.isNotEmpty && entry.key == 'Bank' && !w.name.contains(detail)) {
            w.name = 'Bank – $detail';
          }
          // For mobile money, detail is phone number - stored as wallet name suffix for display
          // Keep icon as 'mobile' to preserve icon, not overwriting with phone number
          await vm.saveWallet(w);
        }
      }
    }

    await vm.completeOnboarding(
      name: _nameCtrl.text.trim().isEmpty ? 'Ian' : _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      incomeSource: _incomeSource,
      occupation: _occupationCtrl.text.trim(),
      pin: _enableLock ? _pinCtrl.text : null,
      enableLock: _enableLock && _pinCtrl.text.isNotEmpty,
      currencyCode: _currency,
      currencySymbol: _currency,
      darkMode: _darkMode,
      notificationsEnabled: _notifications,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created successfully')));
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: _back,
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Row(
                      children: List.generate(5, (i) {
                        final isActive = i == _currentStep;
                        final isDone = i < _currentStep;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDone || isActive ? AppColors.primary : AppColors.divider,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Step ${_currentStep + 1} of 5',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomeStep(onNext: _next),
                  _PersonalStep(
                    nameCtrl: _nameCtrl,
                    phoneCtrl: _phoneCtrl,
                    emailCtrl: _emailCtrl,
                  ),
                  _WalletStep(
                    walletSelected: _walletSelected,
                    walletBalanceCtrls: _walletBalanceCtrls,
                    walletDetailCtrls: _walletDetailCtrls,
                    onChanged: () => setState(() {}),
                  ),
                  _IncomeStep(
                    incomeSource: _incomeSource,
                    occupationCtrl: _occupationCtrl,
                    monthlyIncomeCtrl: _monthlyIncomeCtrl,
                    onChanged: (v) => setState(() => _incomeSource = v),
                  ),
                  _SecurityAndPreferenceStep(
                    pinCtrl: _pinCtrl,
                    pinConfirmCtrl: _pinConfirmCtrl,
                    enableLock: _enableLock,
                    obscurePin: _obscurePin,
                    onEnableLock: (v) => setState(() => _enableLock = v),
                    onObscure: () => setState(() => _obscurePin = !_obscurePin),
                    currency: _currency,
                    onCurrency: (v) => setState(() => _currency = v),
                    darkMode: _darkMode,
                    onDarkMode: (v) => setState(() => _darkMode = v),
                    notifications: _notifications,
                    onNotifications: (v) => setState(() => _notifications = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _back,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(color: AppColors.divider),
                        ),
                        child: const Text('Back', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(_currentStep == 4 ? 'Create account' : 'Continue',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomeStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: ClipOval(child: Image.asset('assets/app_icon.png', fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.account_balance_wallet, size: 40, color: AppColors.primary))),
          ),
          const SizedBox(height: 24),
          const Text('Welcome to\nMoneyTrack', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2)),
          const SizedBox(height: 12),
          const Text('Your personal expense tracker for MTN, Airtel and bank — built for Uganda.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 28),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _WelcomeFeature(icon: Icons.lock_outline, title: 'Secure & private', desc: 'Set a PIN to protect your data. Nothing leaves your phone without confirmation.'),
                  const Divider(height: 24, color: AppColors.divider),
                  _WelcomeFeature(icon: Icons.account_balance_wallet_outlined, title: 'All wallets in one', desc: 'MTN Mobile Money, Airtel, Bank and Cash — track every shilling.'),
                  const Divider(height: 24, color: AppColors.divider),
                  _WelcomeFeature(icon: Icons.auto_awesome_outlined, title: 'Auto-capture', desc: 'Reads money SMS so you don’t type every transaction.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('By continuing, you agree to our Terms and Privacy Policy.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _WelcomeFeature({required this.icon, required this.title, required this.desc});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 36, height: 36, decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle), child: Icon(icon, size: 18, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
          ]),
        ),
      ],
    );
  }
}

class _PersonalStep extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  const _PersonalStep({required this.nameCtrl, required this.phoneCtrl, required this.emailCtrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Let’s set up your account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Tell us about yourself. You can change this later in Settings.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Username *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Ian',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Phone number *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '+256 700 000000',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textSecondary, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Email (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'ian@example.com',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDBEAFE))),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              const Expanded(child: Text('We use your phone to link mobile money alerts for auto-capture. Never shared.', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB)))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _WalletStep extends StatelessWidget {
  final Map<String, bool> walletSelected;
  final Map<String, TextEditingController> walletBalanceCtrls;
  final Map<String, TextEditingController> walletDetailCtrls;
  final VoidCallback onChanged;

  const _WalletStep({required this.walletSelected, required this.walletBalanceCtrls, required this.walletDetailCtrls, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Set up your wallets', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Select the wallets you use. Add initial balances and details — you can edit later.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          for (final name in walletSelected.keys) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: _walletColor(name).withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: Icon(_walletIcon(name), color: _walletColor(name), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                        Switch(value: walletSelected[name]!, onChanged: (v) { walletSelected[name] = v; onChanged(); }, activeThumbColor: AppColors.primary),
                      ],
                    ),
                    if (walletSelected[name]!) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name.contains('Bank') ? 'Bank name' : name.contains('Cash') ? 'Location' : 'Phone number', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: walletDetailCtrls[name],
                              decoration: InputDecoration(
                                hintText: name.contains('Bank') ? 'e.g. Stanbic' : name.contains('MTN') ? '07XX XXX XXX' : name.contains('Airtel') ? '07XX XXX XXX' : 'e.g. Home',
                                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                filled: true,
                                fillColor: AppColors.bg,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Initial balance (UGX)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: walletBalanceCtrls[name],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '0',
                                filled: true,
                                fillColor: AppColors.bg,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ]),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Color _walletColor(String name) {
    if (name.contains('MTN')) return const Color(0xFFFFCC00);
    if (name.contains('Airtel')) return const Color(0xFFED1C24);
    if (name.contains('Bank')) return AppColors.primary;
    return const Color(0xFF16A34A);
  }

  IconData _walletIcon(String name) {
    if (name.contains('Bank')) return Icons.account_balance_outlined;
    if (name.contains('Cash')) return Icons.payments_outlined;
    return Icons.smartphone_outlined;
  }
}

class _IncomeStep extends StatelessWidget {
  final String incomeSource;
  final TextEditingController occupationCtrl;
  final TextEditingController monthlyIncomeCtrl;
  final ValueChanged<String> onChanged;

  const _IncomeStep({required this.incomeSource, required this.occupationCtrl, required this.monthlyIncomeCtrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Source of income', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('This helps us personalize budgets and income tracking. Choose what fits best.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          _IncomeCard(
            selected: incomeSource == 'salary',
            icon: Icons.work_outline,
            title: 'Salary',
            desc: 'Fixed monthly income — employed, government, NGO, etc.',
            onTap: () => onChanged('salary'),
          ),
          const SizedBox(height: 12),
          _IncomeCard(
            selected: incomeSource == 'informal',
            icon: Icons.handyman_outlined,
            title: 'Informal work',
            desc: 'Business, freelance, boda, market, farming — variable income.',
            onTap: () => onChanged('informal'),
          ),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Other details (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  const Text('Occupation / Business type', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: occupationCtrl,
                    decoration: InputDecoration(
                      hintText: incomeSource == 'salary' ? 'e.g. Teacher' : 'e.g. Shop owner',
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Text('Average monthly income (UGX)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: monthlyIncomeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g. 2,500,000',
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;
  const _IncomeCard({required this.selected, required this.icon, required this.title, required this.desc, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.bg, shape: BoxShape.circle), child: Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: selected ? AppColors.primary : AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
              ]),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppColors.primary : AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SecurityAndPreferenceStep extends StatelessWidget {
  final TextEditingController pinCtrl;
  final TextEditingController pinConfirmCtrl;
  final bool enableLock;
  final bool obscurePin;
  final ValueChanged<bool> onEnableLock;
  final VoidCallback onObscure;
  final String currency;
  final ValueChanged<String> onCurrency;
  final bool darkMode;
  final ValueChanged<bool> onDarkMode;
  final bool notifications;
  final ValueChanged<bool> onNotifications;

  const _SecurityAndPreferenceStep({
    required this.pinCtrl,
    required this.pinConfirmCtrl,
    required this.enableLock,
    required this.obscurePin,
    required this.onEnableLock,
    required this.onObscure,
    required this.currency,
    required this.onCurrency,
    required this.darkMode,
    required this.onDarkMode,
    required this.notifications,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Secure your data', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Set a PIN to view your data — required on every sign in. You can change it later.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(width: 36, height: 36, decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle), child: const Icon(Icons.lock_outline, color: AppColors.primary, size: 18)),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('App lock', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                      Switch(value: enableLock, onChanged: onEnableLock, activeThumbColor: AppColors.primary),
                    ],
                  ),
                  if (enableLock) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: pinCtrl,
                      obscureText: obscurePin,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Create PIN (4-6 digits)',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        suffixIcon: IconButton(icon: Icon(obscurePin ? Icons.visibility_off : Icons.visibility, size: 18), onPressed: onObscure),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pinConfirmCtrl,
                      obscureText: obscurePin,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Confirm PIN',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(children: [
                      Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                      SizedBox(width: 6),
                      Expanded(child: Text('PIN is required every time you open MoneyTrack.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _PrefRow(icon: Icons.attach_money, title: 'Currency', trailing: DropdownButton<String>(value: currency, underline: const SizedBox(), items: const [DropdownMenuItem(value: 'UGX', child: Text('UGX')), DropdownMenuItem(value: 'KES', child: Text('KES')), DropdownMenuItem(value: 'USD', child: Text('USD'))], onChanged: (v) { if (v != null) onCurrency(v); })),
                  _PrefRow(icon: Icons.dark_mode_outlined, title: 'Dark mode', trailing: Switch(value: darkMode, onChanged: onDarkMode, activeThumbColor: AppColors.primary)),
                  _PrefRow(icon: Icons.notifications_outlined, title: 'Notifications', trailing: Switch(value: notifications, onChanged: onNotifications, activeThumbColor: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;
  const _PrefRow({required this.icon, required this.title, required this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle), child: Icon(icon, size: 16, color: AppColors.textSecondary)),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        trailing,
      ]),
    );
  }
}
