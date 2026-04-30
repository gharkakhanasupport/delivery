import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../models/delivery_agent.dart';
import '../services/delivery_agent_service.dart';
import '../services/order_service.dart';
import '../screens/settings_screen.dart';
import '../widgets/shimmer_loading.dart';
import 'withdrawal_settings_screen.dart';

/// Profile Screen — Enhanced with editable vehicle, real stats, and essential features
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  bool _isUpdating = false;

  // Real stats from DB
  int _totalDeliveries = 0;
  double _totalEarned = 0;
  double _rating = 0;
  bool _statsLoaded = false;

  // Realtime subscription
  RealtimeChannel? _profileChannel;

  @override
  void initState() {
    super.initState();
    if (DeliveryAgentService.currentAgent.value == null) {
      DeliveryAgentService.fetchCurrentProfile();
    }
    _loadStats();
    _subscribeToProfileUpdates();
  }

  @override
  void dispose() {
    _profileChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _clearAllMyDeliveries() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All My Deliveries?'),
        content: const Text(
          'This will permanently delete every delivery_orders row assigned to you. This cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final count = await OrderService.clearAllMyDeliveries();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleared $count deliveries.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _loadStats() async {
    final stats = await DeliveryAgentService.getDeliveryStats();
    if (mounted) {
      setState(() {
        _totalDeliveries = stats['deliveries'] as int? ?? 0;
        _totalEarned = (stats['earned'] as num?)?.toDouble() ?? 0;
        _rating = (stats['rating'] as num?)?.toDouble() ?? 0;
        _statsLoaded = true;
      });
    }
  }

  /// Subscribe to realtime profile and wallet updates
  void _subscribeToProfileUpdates() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _profileChannel = Supabase.instance.client
        .channel('profile-live-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'delivery_profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (_) {
            DeliveryAgentService.fetchCurrentProfile();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicle_details',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) {
            DeliveryAgentService.fetchCurrentProfile();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'agent_wallets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'agent_id',
            value: userId,
          ),
          callback: (_) => _loadStats(),
        )
        .subscribe();
  }

  Future<void> _pickAndUpdatePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isUpdating = true);
      await DeliveryAgentService.updateProfilePhoto(image.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: AppColors.emeraldGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
      body: SafeArea(
        child: Stack(
          children: [
            ValueListenableBuilder<DeliveryAgent?>(
              valueListenable: DeliveryAgentService.currentAgent,
              builder: (context, agent, child) {
                if (agent == null) return _buildShimmerProfile();
                return _buildContent(agent, isDark);
              },
            ),
            if (_isUpdating)
              Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: AppConstants.borderRadiusLarge,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.emeraldGreen, strokeWidth: 2.5,
                        ),
                        SizedBox(height: 12),
                        Text('Updating...'),
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

  Widget _buildShimmerProfile() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ShimmerLoading.card(height: 180),
        const SizedBox(height: 16),
        ShimmerLoading.card(height: 80),
        const SizedBox(height: 16),
        ShimmerLoading.card(height: 200),
      ],
    );
  }

  Widget _buildContent(DeliveryAgent agent, bool isDark) {
    return RefreshIndicator(
      color: AppColors.emeraldGreen,
      onRefresh: () async {
        await DeliveryAgentService.fetchCurrentProfile();
        await _loadStats();
      },
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.responsivePadding(context), 12,
                AppConstants.responsivePadding(context), 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Profile',
                      style: AppTypography.headingStyle(
                        color: isDark ? AppColors.textLight : AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                      borderRadius: AppConstants.borderRadiusMedium,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.settings_rounded,
                        color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
                        size: 22,
                      ),
                      onPressed: () {
                        Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                      tooltip: 'Settings',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Profile Header Card
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.responsivePadding(context), vertical: 8,
              ),
              child: _buildProfileHeader(agent, isDark),
            ),
          ),

          // Stats Grid — REAL DATA
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.responsivePadding(context), vertical: 4,
              ),
              child: _buildStatsGrid(isDark),
            ),
          ),

          // ── Personal Info (Editable) ──
          _buildSectionSliver('Personal Information', isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.responsivePadding(context),
              ),
              child: _buildInfoCard([
                _buildEditableItem(Icons.person_rounded, 'Name', agent.name, isDark,
                  onEdit: () => _editField('Name', agent.name, (v) async {
                    await DeliveryAgentService.updatePersonalInfo(name: v);
                  }),
                ),
                _buildCardDivider(isDark),
                _buildEditableItem(Icons.phone_rounded, 'Phone',
                  agent.phone.isNotEmpty ? agent.phone : '--', isDark,
                  onEdit: () => _editField('Phone', agent.phone, (v) async {
                    await DeliveryAgentService.updatePhoneNumber(v);
                  }),
                ),
                _buildCardDivider(isDark),
                _buildListItem(Icons.email_rounded, 'Email', agent.email, isDark),
                _buildCardDivider(isDark),
                _buildEditableItem(Icons.location_on_rounded, 'Address',
                  agent.address.isNotEmpty ? agent.address : '--', isDark,
                  onEdit: () => _editField('Address', agent.address, (v) async {
                    await DeliveryAgentService.updatePersonalInfo(address: v);
                  }),
                ),
                _buildCardDivider(isDark),
                _buildEditableItem(Icons.location_city_rounded, 'City',
                  agent.city ?? '--', isDark,
                  onEdit: () => _editField('City', agent.city ?? '', (v) async {
                    await DeliveryAgentService.updatePersonalInfo(city: v);
                  }),
                ),
              ], isDark),
            ),
          ),

          // ── Vehicle Details (Editable!) ──
          _buildSectionSliver('Vehicle Details', isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.responsivePadding(context),
              ),
              child: Column(
                children: [
                  _buildInfoCard([
                    _buildListItem(Icons.two_wheeler_rounded, 'Vehicle Type',
                      _getVehicleTypeLabel(agent.vehicleType), isDark,
                      trailing: _buildEditButton(() => _showVehicleEditor(agent)),
                    ),
                    _buildCardDivider(isDark),
                    _buildListItem(Icons.pin_rounded, 'Vehicle Number',
                      agent.vehicleNumber ?? '--', isDark,
                    ),
                    _buildCardDivider(isDark),
                    _buildListItem(Icons.factory_rounded, 'Vehicle Make/Model',
                      agent.vehicleMake ?? '--', isDark,
                    ),
                    if (agent.vehicleType == VehicleType.twoWheeler) ...[
                      _buildCardDivider(isDark),
                      _buildListItem(Icons.electric_bolt_rounded, 'Engine Type',
                        agent.engineType == EngineType.electric ? 'Electric' : 'Petrol/Diesel',
                        isDark,
                      ),
                    ],
                  ], isDark),
                  const SizedBox(height: 10),
                  // Update Vehicle Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showVehicleEditor(agent),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Update Vehicle Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.emeraldGreen,
                        side: const BorderSide(color: AppColors.emeraldGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppConstants.borderRadiusLarge,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Documents ──
          _buildSectionSliver('Documents & Verification', isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.responsivePadding(context),
              ),
              child: _buildInfoCard([
                _buildListItem(Icons.credit_card_rounded, 'Aadhaar',
                  agent.isKycVerified ? 'Verified' : 'Pending', isDark,
                  trailing: agent.isKycVerified ? _buildVerifiedBadge() : _buildPendingBadge(),
                ),
                _buildCardDivider(isDark),
                _buildListItem(Icons.badge_rounded, 'Driving License',
                  agent.drivingLicensePath != null ? 'Uploaded' : 'Not uploaded', isDark,
                  trailing: agent.drivingLicensePath != null ? _buildVerifiedBadge() : _buildPendingBadge(),
                ),
                _buildCardDivider(isDark),
                _buildListItem(Icons.verified_user_rounded, 'Account Status',
                  agent.statusLabel, isDark,
                  trailing: _buildStatusChip(agent.verificationStatus),
                ),
              ], isDark),
            ),
          ),

          // ── Financial Settings ──
          _buildSectionSliver('Financial Settings', isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.responsivePadding(context),
              ),
              child: _buildInfoCard([
                _buildActionItem(Icons.account_balance_rounded, 'Withdrawal Methods',
                  'Setup bank account or UPI for payouts', isDark, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WithdrawalSettingsScreen(),
                      ),
                    );
                  }),
              ], isDark),
            ),
          ),

          // ── Quick Actions ──
          _buildSectionSliver('Quick Actions', isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.responsivePadding(context),
              ),
              child: _buildInfoCard([
                _buildActionItem(Icons.support_agent_rounded, 'Help & Support',
                  'Get help with deliveries', isDark, () {}),
                _buildCardDivider(isDark),
                _buildActionItem(Icons.description_rounded, 'Terms & Conditions',
                  'View delivery partner agreement', isDark, () {}),
                _buildCardDivider(isDark),
                _buildActionItem(Icons.privacy_tip_rounded, 'Privacy Policy',
                  'How we handle your data', isDark, () {}),
                _buildCardDivider(isDark),
                _buildActionItem(Icons.info_rounded, 'App Version',
                  'v1.0.0 (com.gharkakhana.delivery)', isDark, null),
              ], isDark),
            ),
          ),

          // ── Danger Zone ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.responsivePadding(context),
                24,
                AppConstants.responsivePadding(context),
                0,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text('Danger Zone',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.red.shade700,
                          )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Delete every delivery_orders row assigned to you. Cannot be undone.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _clearAllMyDeliveries,
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Clear All My Deliveries'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // SECTION TITLE
  // ══════════════════════════════════════════

  SliverToBoxAdapter _buildSectionSliver(String title, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppConstants.responsivePadding(context), 20,
          AppConstants.responsivePadding(context), 8,
        ),
        child: Text(title,
          style: AppTypography.bodyStyle(
            color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
            weight: FontWeight.w600, size: 13,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // PROFILE HEADER
  // ══════════════════════════════════════════

  Widget _buildProfileHeader(DeliveryAgent agent, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        children: [
          // Profile Photo
          GestureDetector(
            onTap: _pickAndUpdatePhoto,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.emeraldGreen.withValues(alpha: 0.3), width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.emeraldGreen.withValues(alpha: 0.08),
                    backgroundImage: agent.profilePhotoPath != null
                        ? NetworkImage(agent.profilePhotoPath!) : null,
                    child: agent.profilePhotoPath == null
                        ? const Icon(Icons.person_rounded, size: 44, color: AppColors.emeraldGreen)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldGreen, shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkCard : Colors.white, width: 2.5,
                      ),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(agent.name,
            style: AppTypography.headingStyle(
              color: isDark ? AppColors.textLight : AppColors.textPrimary, size: 20,
            ),
            textAlign: TextAlign.center,
          ),
          if (agent.city != null) ...[
            const SizedBox(height: 4),
            Text('📍 ${agent.city}',
              style: AppTypography.captionStyle(
                color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Rating badge — REAL
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.goldenMustard.withValues(alpha: 0.1),
              borderRadius: AppConstants.borderRadiusCircular,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.goldenMustard, size: 16),
                const SizedBox(width: 4),
                Text(
                  _rating > 0 ? _rating.toStringAsFixed(1) : 'New',
                  style: AppTypography.bodyStyle(
                    color: AppColors.goldenMustard, weight: FontWeight.w700, size: 14,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _statsLoaded ? '($_totalDeliveries deliveries)' : '...',
                  style: AppTypography.captionStyle(
                    color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // STATS GRID — REAL DATA FROM DB
  // ══════════════════════════════════════════

  Widget _buildStatsGrid(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            _statsLoaded ? '$_totalDeliveries' : '...',
            'Deliveries', Icons.check_circle_rounded,
            AppColors.emeraldGreen, isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            _statsLoaded ? '₹${_totalEarned.toInt()}' : '...',
            'Total Earned', Icons.currency_rupee_rounded,
            AppColors.goldenMustard, isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppConstants.borderRadiusMedium,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.titleStyle(
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          )),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.captionStyle(
            color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
          )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // CARD & LIST ITEMS
  // ══════════════════════════════════════════

  Widget _buildInfoCard(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderSubtle),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListItem(IconData icon, String label, String value, bool isDark, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.emeraldGreen.withValues(alpha: 0.08),
              borderRadius: AppConstants.borderRadiusMedium,
            ),
            child: Icon(icon, color: AppColors.emeraldGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.captionStyle(
                  color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
                )),
                const SizedBox(height: 2),
                Text(value,
                  style: AppTypography.bodyStyle(
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                    weight: FontWeight.w500, size: 14,
                  ),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  /// Editable list item — shows a pencil icon on the right
  Widget _buildEditableItem(IconData icon, String label, String value, bool isDark, {
    required VoidCallback onEdit,
  }) {
    return _buildListItem(icon, label, value, isDark,
      trailing: _buildEditButton(onEdit),
    );
  }

  Widget _buildActionItem(IconData icon, String title, String subtitle, bool isDark,
      VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppConstants.borderRadiusLarge,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.emeraldGreen.withValues(alpha: 0.08),
                borderRadius: AppConstants.borderRadiusMedium,
              ),
              child: Icon(icon, color: AppColors.emeraldGreen, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyStyle(
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                    weight: FontWeight.w500, size: 14,
                  )),
                  Text(subtitle, style: AppTypography.captionStyle(
                    color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
                  )),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                color: isDark ? AppColors.textLightSecondary : AppColors.mediumGrey,
              ),
          ],
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

  // ══════════════════════════════════════════
  // BADGES
  // ══════════════════════════════════════════

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.emeraldGreen.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, color: AppColors.emeraldGreen, size: 16),
    );
  }

  Widget _buildPendingBadge() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.goldenMustard.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.schedule_rounded, color: AppColors.goldenMustard, size: 16),
    );
  }

  Widget _buildEditButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.emeraldGreen.withValues(alpha: 0.08),
          borderRadius: AppConstants.borderRadiusSmall,
        ),
        child: const Icon(Icons.edit_rounded, color: AppColors.emeraldGreen, size: 15),
      ),
    );
  }

  Widget _buildStatusChip(VerificationStatus status) {
    Color color;
    switch (status) {
      case VerificationStatus.verified:
        color = AppColors.emeraldGreen;
      case VerificationStatus.underReview:
        color = AppColors.goldenMustard;
      case VerificationStatus.rejected:
        color = AppColors.error;
      case VerificationStatus.pending:
        color = AppColors.mediumGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppConstants.borderRadiusCircular,
      ),
      child: Text(
        status.name.toUpperCase(),
        style: AppTypography.captionStyle(color: color),
      ),
    );
  }

  // ══════════════════════════════════════════
  // EDIT DIALOGS
  // ══════════════════════════════════════════

  /// Generic field editor dialog
  void _editField(String fieldName, String currentValue, Future<void> Function(String) onSave) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: currentValue == '--' ? '' : currentValue);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mediumGrey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Update $fieldName',
              style: AppTypography.headingStyle(
                color: isDark ? AppColors.textLight : AppColors.textPrimary,
                size: 18,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: fieldName,
                border: OutlineInputBorder(borderRadius: AppConstants.borderRadiusMedium),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppConstants.borderRadiusMedium,
                  borderSide: const BorderSide(color: AppColors.emeraldGreen, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final value = controller.text.trim();
                  if (value.isEmpty) return;
                  Navigator.pop(ctx);
                  setState(() => _isUpdating = true);
                  try {
                    await onSave(value);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$fieldName updated!'),
                          backgroundColor: AppColors.emeraldGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isUpdating = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadiusLarge),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Full vehicle editor bottom sheet
  void _showVehicleEditor(DeliveryAgent agent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    VehicleType selectedType = agent.vehicleType;
    EngineType? selectedEngine = agent.engineType;
    final numberController = TextEditingController(text: agent.vehicleNumber ?? '');
    final makeController = TextEditingController(text: agent.vehicleMake ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.mediumGrey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Update Vehicle',
                  style: AppTypography.headingStyle(
                    color: isDark ? AppColors.textLight : AppColors.textPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 20),

                // Vehicle Type Selector
                Text('Vehicle Type', style: AppTypography.captionStyle(
                  color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
                )),
                const SizedBox(height: 8),
                Row(
                  children: VehicleType.values.map((type) {
                    final isSelected = selectedType == type;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setSheetState(() => selectedType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.emeraldGreen.withValues(alpha: 0.12)
                                  : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                              borderRadius: AppConstants.borderRadiusMedium,
                              border: Border.all(
                                color: isSelected ? AppColors.emeraldGreen : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  type == VehicleType.cycle ? Icons.pedal_bike_rounded
                                      : type == VehicleType.twoWheeler ? Icons.two_wheeler_rounded
                                      : Icons.local_shipping_rounded,
                                  color: isSelected ? AppColors.emeraldGreen : AppColors.mediumGrey,
                                ),
                                const SizedBox(height: 4),
                                Text(_getVehicleTypeLabel(type),
                                  style: AppTypography.captionStyle(
                                    color: isSelected ? AppColors.emeraldGreen
                                        : (isDark ? AppColors.textLightSecondary : AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Engine type for two-wheelers
                if (selectedType == VehicleType.twoWheeler) ...[
                  const SizedBox(height: 16),
                  Text('Engine Type', style: AppTypography.captionStyle(
                    color: isDark ? AppColors.textLightSecondary : AppColors.textSecondary,
                  )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildEngineChip('Electric', EngineType.electric,
                        selectedEngine, isDark, (e) => setSheetState(() => selectedEngine = e)),
                      const SizedBox(width: 10),
                      _buildEngineChip('Petrol/Diesel', EngineType.nonElectric,
                        selectedEngine, isDark, (e) => setSheetState(() => selectedEngine = e)),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                TextField(
                  controller: numberController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Number',
                    hintText: 'e.g. WB 26 AB 1234',
                    border: OutlineInputBorder(borderRadius: AppConstants.borderRadiusMedium),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppConstants.borderRadiusMedium,
                      borderSide: const BorderSide(color: AppColors.emeraldGreen, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: makeController,
                  decoration: InputDecoration(
                    labelText: 'Make / Model',
                    hintText: 'e.g. Honda Activa 6G',
                    border: OutlineInputBorder(borderRadius: AppConstants.borderRadiusMedium),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppConstants.borderRadiusMedium,
                      borderSide: const BorderSide(color: AppColors.emeraldGreen, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => _isUpdating = true);
                      try {
                        await DeliveryAgentService.updateVehicleDetails(
                          vehicleType: selectedType,
                          engineType: selectedEngine,
                          vehicleNumber: numberController.text.trim(),
                          vehicleMake: makeController.text.trim(),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Vehicle details updated!'),
                              backgroundColor: AppColors.emeraldGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isUpdating = false);
                      }
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Vehicle Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: AppConstants.borderRadiusLarge),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEngineChip(String label, EngineType type, EngineType? selected,
      bool isDark, ValueChanged<EngineType> onSelect) {
    final isSelected = selected == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.emeraldGreen.withValues(alpha: 0.12)
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: AppConstants.borderRadiusMedium,
            border: Border.all(
              color: isSelected ? AppColors.emeraldGreen : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(label,
            textAlign: TextAlign.center,
            style: AppTypography.bodyStyle(
              color: isSelected ? AppColors.emeraldGreen
                  : (isDark ? AppColors.textLightSecondary : AppColors.textSecondary),
              weight: isSelected ? FontWeight.w600 : FontWeight.w400,
              size: 13,
            ),
          ),
        ),
      ),
    );
  }

  String _getVehicleTypeLabel(VehicleType type) {
    switch (type) {
      case VehicleType.cycle:
        return 'Bicycle';
      case VehicleType.twoWheeler:
        return 'Motorcycle';
      case VehicleType.others:
        return 'Other';
    }
  }
}
