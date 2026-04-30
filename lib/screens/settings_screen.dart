import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/animated_theme_toggle.dart';

/// Settings Screen — clean sectioned list with consistent design tokens
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String appVersion = '1.0.0';
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _setNotificationPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (mounted) {
      setState(() => _notificationsEnabled = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header with back button
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppConstants.responsivePadding(context),
                  8,
                  AppConstants.responsivePadding(context),
                  8,
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightSurface,
                        borderRadius: AppConstants.borderRadiusMedium,
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark
                              ? AppColors.textLightSecondary
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: AppTypography.headingStyle(
                              color: isDark
                                  ? AppColors.textLight
                                  : AppColors.textPrimary,
                              size: 24,
                            ),
                          ),
                          Text(
                            'Manage your preferences',
                            style: AppTypography.captionStyle(
                              color: isDark
                                  ? AppColors.textLightSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Settings List
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.responsivePadding(context),
                vertical: 8,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // General Section
                  _buildSectionHeader('General', isDark),
                  _buildSettingCard(
                    isDark: isDark,
                    children: [
                      _buildSettingTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        isDark: isDark,
                        trailing: Switch(
                          value: _notificationsEnabled,
                          onChanged: _setNotificationPref,
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.emeraldGreen,
                          inactiveThumbColor: isDark
                              ? AppColors.mediumGrey
                              : Colors.white,
                          inactiveTrackColor: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightGrey,
                        ),
                      ),
                      _buildCardDivider(isDark),
                      _buildSettingTile(
                        icon: Icons.language_rounded,
                        title: 'Language',
                        subtitle: 'English',
                        isDark: isDark,
                        showArrow: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Appearance Section
                  _buildSectionHeader('Appearance', isDark),
                  _buildSettingCard(
                    isDark: isDark,
                    children: [_buildThemeToggle(context, isDark)],
                  ),

                  const SizedBox(height: 20),

                  // About Section
                  _buildSectionHeader('About', isDark),
                  _buildSettingCard(
                    isDark: isDark,
                    children: [
                      _buildSettingTile(
                        icon: Icons.info_outline_rounded,
                        title: 'App Version',
                        subtitle: 'v$appVersion',
                        isDark: isDark,
                      ),
                      _buildCardDivider(isDark),
                      _buildSettingTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        isDark: isDark,
                        onTap: () => _showPrivacyPolicy(context),
                        showArrow: true,
                      ),
                      _buildCardDivider(isDark),
                      _buildSettingTile(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        isDark: isDark,
                        onTap: () => _showTermsOfService(context),
                        showArrow: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Support Section
                  _buildSectionHeader('Support', isDark),
                  _buildSettingCard(
                    isDark: isDark,
                    children: [
                      _buildSettingTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Help & Support',
                        isDark: isDark,
                        onTap: () => _showHelpSupport(context),
                        showArrow: true,
                      ),
                      _buildCardDivider(isDark),
                      _buildSettingTile(
                        icon: Icons.feedback_outlined,
                        title: 'Send Feedback',
                        isDark: isDark,
                        onTap: () => _showFeedbackDialog(context),
                        showArrow: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Account Section
                  _buildSectionHeader('Account', isDark),
                  _buildSettingCard(
                    isDark: isDark,
                    children: [
                      _buildSettingTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign Out',
                        titleColor: AppColors.error,
                        isDark: isDark,
                        onTap: () => _confirmLogout(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'GHAR KA KHANA',
                          style: AppTypography.labelStyle(
                            color: AppColors.emeraldGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Delivery Partner App',
                          style: AppTypography.captionStyle(
                            color: isDark
                                ? AppColors.textLightSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '© ${DateTime.now().year} GKK. All rights reserved.',
                          style: AppTypography.captionStyle(
                            color: isDark
                                ? AppColors.textLightSecondary
                                : AppColors.textTertiary,
                          ).copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.captionStyle(
          color: isDark
              ? AppColors.textLightSecondary
              : AppColors.textSecondary,
          weight: FontWeight.w600,
        ).copyWith(letterSpacing: 1.2, fontSize: 11),
      ),
    );
  }

  Widget _buildSettingCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, mode, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emeraldGreen.withValues(alpha: 0.08),
                  borderRadius: AppConstants.borderRadiusMedium,
                ),
                child: Icon(
                  mode == ThemeMode.dark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: AppColors.emeraldGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark Mode',
                      style: AppTypography.bodyStyle(
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      mode == ThemeMode.dark
                          ? 'Night mode enabled'
                          : 'Day mode enabled',
                      style: AppTypography.captionStyle(
                        color: isDark
                            ? AppColors.textLightSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const AnimatedThemeToggle(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isDark,
    VoidCallback? onTap,
    bool showArrow = false,
    Color? titleColor,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppConstants.borderRadiusLarge,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (titleColor ?? AppColors.emeraldGreen)
                      .withValues(alpha: 0.08),
                  borderRadius: AppConstants.borderRadiusMedium,
                ),
                child: Icon(
                  icon,
                  color: titleColor ?? AppColors.emeraldGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyStyle(
                        color: titleColor ??
                            (isDark
                                ? AppColors.textLight
                                : AppColors.textPrimary),
                        weight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: AppTypography.captionStyle(
                          color: isDark
                              ? AppColors.textLightSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else if (showArrow)
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? AppColors.textLightSecondary
                      : AppColors.mediumGrey,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 52),
      child: Container(
        height: 1,
        color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'GHAR KA KHANA Privacy Policy\n\n'
            'Your privacy is important to us. This policy explains how we collect, '
            'use, and protect your personal information when you use our delivery partner app.\n\n'
            '1. Information We Collect\n'
            '• Location data for delivery tracking\n'
            '• Personal identification information\n'
            '• Device information\n\n'
            '2. How We Use Your Information\n'
            '• To process delivery orders\n'
            '• To improve our services\n'
            '• To communicate with you\n\n'
            '3. Data Protection\n'
            'We implement security measures to protect your data.\n\n'
            'For more details, visit our website.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'GHAR KA KHANA Terms of Service\n\n'
            'By using this app, you agree to these terms:\n\n'
            '1. Eligibility\n'
            'You must be 18+ and have a valid license.\n\n'
            '2. Your Responsibilities\n'
            '• Deliver orders on time\n'
            '• Maintain professionalism\n'
            '• Follow safety guidelines\n\n'
            '3. Payment Terms\n'
            'Earnings are paid weekly.\n\n'
            'For complete terms, visit our website.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Need help? Contact us:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email, color: AppColors.emeraldGreen),
              title: const Text('Email'),
              subtitle: const Text('support@gkk.com'),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.emeraldGreen),
              title: const Text('Phone'),
              subtitle: const Text('+91 1800-XXX-XXXX'),
              dense: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext ctx) {
    final controller = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Send Feedback'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Tell us what you think...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(dialogCtx);
              // Submit to Supabase
              try {
                final userId = Supabase.instance.client.auth.currentUser?.id;
                await DatabaseService().primary.from('agent_feedback').insert({
                  'agent_id': userId,
                  'feedback': text,
                  'created_at': DateTime.now().toIso8601String(),
                });
              } catch (_) {}
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for your feedback!'),
                    backgroundColor: AppColors.emeraldGreen,
                  ),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              AuthService.signOut(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
