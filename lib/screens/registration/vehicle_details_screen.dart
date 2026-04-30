import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/typography.dart';
import '../../models/delivery_agent.dart';
import '../../services/delivery_agent_service.dart';
import '../../widgets/main_navigation.dart';
import '../../services/auth_service.dart';

/// Step 3: Vehicle Details Registration
class VehicleDetailsScreen extends StatefulWidget {
  const VehicleDetailsScreen({super.key});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  VehicleType _selectedVehicleType = VehicleType.twoWheeler;
  EngineType _selectedEngineType = EngineType.nonElectric;

  String? _licensePath;
  String? _vehiclePhotoPath;
  bool _isLoading = false;

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _vehicleMakeController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(bool isLicense) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        if (isLicense) {
          _licensePath = result.files.first.path;
        } else {
          _vehiclePhotoPath = result.files.first.path;
        }
      });
    }
  }

  Future<void> _pickVehiclePhoto() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.mediumGrey.withValues(alpha: 0.3)
                    : AppColors.lightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Photo Source',
              style: AppTypography.titleStyle(
                color: isDark
                    ? AppColors.textLight
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () => _getImage(ImageSource.camera),
                  isDark: isDark,
                ),
                _buildSourceOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () => _getImage(ImageSource.gallery),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.emeraldGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppColors.emeraldGreen),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTypography.bodyStyle(
              color: isDark
                  ? AppColors.textLight
                  : AppColors.textPrimary,
              weight: FontWeight.w500,
              size: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          _vehiclePhotoPath = pickedFile.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _completeRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (_vehiclePhotoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your Vehicle Photo'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedVehicleType != VehicleType.cycle) {
      if (_licensePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload your Driving License'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      await DeliveryAgentService.saveVehicleDetailsAndComplete(
        vehicleType: _selectedVehicleType,
        engineType: _selectedVehicleType == VehicleType.cycle
            ? null
            : _selectedEngineType,
        vehicleNumber: _vehicleNumberController.text.trim().isEmpty
            ? null
            : _vehicleNumberController.text.trim(),
        vehicleMake: _vehicleMakeController.text.trim(),
        drivingLicensePath: _licensePath,
        vehiclePhotoPath: _vehiclePhotoPath,
      );

      AuthService.markProfileComplete();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.responsivePadding(context),
                8,
                AppConstants.responsivePadding(context),
                4,
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
                  Text(
                    'Vehicle Details',
                    style: AppTypography.headingStyle(
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            _buildProgressIndicator(3, 3, isDark),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  AppConstants.responsivePadding(context),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehicle Information',
                        style: AppTypography.headingStyle(
                          color: AppColors.emeraldGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tell us about your delivery vehicle',
                        style: AppTypography.bodyStyle(
                          color: isDark
                              ? AppColors.textLightSecondary
                              : AppColors.textSecondary,
                          size: 14,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Vehicle Type
                      Text(
                        'Vehicle Type',
                        style: AppTypography.titleStyle(
                          color: isDark
                              ? AppColors.textLight
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTypeCard(
                              label: 'Bicycle',
                              icon: Icons.pedal_bike_rounded,
                              isSelected:
                                  _selectedVehicleType == VehicleType.cycle,
                              onTap: () => setState(
                                () => _selectedVehicleType = VehicleType.cycle,
                              ),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTypeCard(
                              label: 'Motorcycle',
                              icon: Icons.two_wheeler_rounded,
                              isSelected:
                                  _selectedVehicleType == VehicleType.twoWheeler,
                              onTap: () => setState(
                                () =>
                                    _selectedVehicleType = VehicleType.twoWheeler,
                              ),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTypeCard(
                              label: 'Others',
                              icon: Icons.electric_rickshaw_rounded,
                              isSelected:
                                  _selectedVehicleType == VehicleType.others,
                              onTap: () => setState(
                                () => _selectedVehicleType = VehicleType.others,
                              ),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),

                      if (_selectedVehicleType != VehicleType.cycle) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Engine Type',
                          style: AppTypography.titleStyle(
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildEngineCard(
                                label: 'Non-electric',
                                icon: Icons.local_gas_station_rounded,
                                isSelected:
                                    _selectedEngineType == EngineType.nonElectric,
                                onTap: () => setState(
                                  () => _selectedEngineType =
                                      EngineType.nonElectric,
                                ),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildEngineCard(
                                label: 'Electric',
                                icon: Icons.electric_bolt_rounded,
                                isSelected:
                                    _selectedEngineType == EngineType.electric,
                                onTap: () => setState(
                                  () =>
                                      _selectedEngineType = EngineType.electric,
                                ),
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Vehicle Number
                        _buildTextField(
                          controller: _vehicleNumberController,
                          label: 'Vehicle Number',
                          icon: Icons.confirmation_number_outlined,
                          hint: 'e.g. MH 01 AB 1234',
                          isDark: isDark,
                          isOptional: _selectedEngineType == EngineType.electric,
                          validator: (v) {
                            if (_selectedEngineType == EngineType.electric) {
                              return null;
                            }
                            if (v == null || v.isEmpty) return 'Required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Driving License Number
                        _buildTextField(
                          controller: _licenseNumberController,
                          label: 'Driving License Number',
                          icon: Icons.badge_outlined,
                          hint: 'e.g. MH01 2020 1234567',
                          isDark: isDark,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Vehicle Model
                        _buildTextField(
                          controller: _vehicleMakeController,
                          label: 'Vehicle Model',
                          icon: Icons.branding_watermark_outlined,
                          hint: 'e.g. Honda Activa',
                          isDark: isDark,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Required Documents',
                          style: AppTypography.titleStyle(
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Driving License Upload
                        _buildUploadButton(
                          label: 'Driving License',
                          path: _licensePath,
                          icon: Icons.card_membership_rounded,
                          onTap: () => _pickFile(true),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_selectedVehicleType == VehicleType.cycle) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Vehicle Photo',
                          style: AppTypography.titleStyle(
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Vehicle Photo (Always Required)
                      _buildUploadButton(
                        label: 'Vehicle Photo',
                        path: _vehiclePhotoPath,
                        icon: Icons.camera_alt_outlined,
                        onTap: _pickVehiclePhoto,
                        isDark: isDark,
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // Submit Button
            Container(
              padding: EdgeInsets.fromLTRB(
                AppConstants.responsivePadding(context),
                12,
                AppConstants.responsivePadding(context),
                12,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderSubtle,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _isLoading
                          ? null
                          : const LinearGradient(
                              colors: AppColors.primaryGradient,
                            ),
                      color: _isLoading
                          ? (isDark
                              ? AppColors.darkSurface
                              : AppColors.lightGrey)
                          : null,
                      borderRadius: AppConstants.borderRadiusMedium,
                      boxShadow: _isLoading
                          ? []
                          : [
                              BoxShadow(
                                color: AppColors.emeraldGreen
                                    .withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _completeRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppConstants.borderRadiusMedium,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: AppColors.emeraldGreen,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Complete Registration',
                                  style: AppTypography.bodyStyle(
                                    color: Colors.white,
                                    weight: FontWeight.w600,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Colors.white,
                                  size: 20,
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
      ),
    );
  }

  Widget _buildProgressIndicator(int current, int total, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.responsivePadding(context),
        vertical: 12,
      ),
      child: Row(
        children: List.generate(total, (index) {
          final isCompleted = index < current;
          final isCurrent = index == current - 1;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < total - 1 ? 6 : 0),
              height: 4,
              decoration: BoxDecoration(
                gradient: isCompleted || isCurrent
                    ? const LinearGradient(
                        colors: AppColors.primaryGradient,
                      )
                    : null,
                color: isCompleted || isCurrent
                    ? null
                    : (isDark ? AppColors.darkSurface : AppColors.lightGrey),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTypeCard({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.emeraldGreen.withValues(alpha: 0.08)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: AppConstants.borderRadiusLarge,
          border: Border.all(
            color: isSelected
                ? AppColors.emeraldGreen
                : (isDark ? AppColors.borderDark : AppColors.borderSubtle),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected
                  ? AppColors.emeraldGreen
                  : (isDark
                      ? AppColors.textLightSecondary
                      : AppColors.mediumGrey),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.captionStyle(
                color: isSelected
                    ? AppColors.emeraldGreen
                    : (isDark
                        ? AppColors.textLight
                        : AppColors.textPrimary),
                weight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineCard({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.emeraldGreen.withValues(alpha: 0.08)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: AppConstants.borderRadiusLarge,
          border: Border.all(
            color: isSelected
                ? AppColors.emeraldGreen
                : (isDark ? AppColors.borderDark : AppColors.borderSubtle),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? AppColors.emeraldGreen
                  : (isDark
                      ? AppColors.textLightSecondary
                      : AppColors.mediumGrey),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.bodyStyle(
                color: isSelected
                    ? AppColors.emeraldGreen
                    : (isDark
                        ? AppColors.textLight
                        : AppColors.textPrimary),
                weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                size: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    String? hint,
    String? Function(String?)? validator,
    bool isOptional = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: AppTypography.bodyStyle(
        color: isDark ? AppColors.textLight : AppColors.textPrimary,
        size: 15,
      ),
      decoration: InputDecoration(
        labelText: isOptional ? '$label (Optional)' : label,
        hintText: hint,
        labelStyle: AppTypography.bodyStyle(
          color: isDark
              ? AppColors.textLightSecondary
              : AppColors.textSecondary,
          size: 14,
        ),
        hintStyle: AppTypography.bodyStyle(
          color: isDark
              ? AppColors.textLightSecondary.withValues(alpha: 0.4)
              : AppColors.textTertiary,
          size: 14,
        ),
        prefixIcon: Icon(icon, color: AppColors.emeraldGreen, size: 20),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : Colors.white,
        border: OutlineInputBorder(
          borderRadius: AppConstants.borderRadiusMedium,
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppConstants.borderRadiusMedium,
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppConstants.borderRadiusMedium,
          borderSide: const BorderSide(
            color: AppColors.emeraldGreen,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppConstants.borderRadiusMedium,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildUploadButton({
    required String label,
    required String? path,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final hasFile = path != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasFile
              ? AppColors.emeraldGreen.withValues(alpha: 0.06)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: AppConstants.borderRadiusLarge,
          border: Border.all(
            color: hasFile
                ? AppColors.emeraldGreen.withValues(alpha: 0.3)
                : (isDark ? AppColors.borderDark : AppColors.borderSubtle),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasFile
                    ? AppColors.emeraldGreen
                    : (isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurface),
                borderRadius: AppConstants.borderRadiusMedium,
              ),
              child: Icon(
                hasFile ? Icons.check_rounded : icon,
                size: 20,
                color: hasFile
                    ? Colors.white
                    : (isDark
                        ? AppColors.textLightSecondary
                        : AppColors.mediumGrey),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyStyle(
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                      weight: FontWeight.w600,
                      size: 14,
                    ),
                  ),
                  if (hasFile) ...[
                    const SizedBox(height: 2),
                    Text(
                      path.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.captionStyle(
                        color: AppColors.emeraldGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!hasFile)
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? AppColors.textLightSecondary
                    : AppColors.mediumGrey,
              ),
            if (hasFile)
              const Icon(
                Icons.edit_rounded,
                size: 18,
                color: AppColors.emeraldGreen,
              ),
          ],
        ),
      ),
    );
  }
}
