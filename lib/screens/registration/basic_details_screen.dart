import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/typography.dart';
import '../../models/delivery_agent.dart';
import '../../services/delivery_agent_service.dart';
import '../../services/auth_service.dart';
import 'kyc_screen.dart';
import '../../widgets/image_editor_dialog.dart';
import '../../constants/locations.dart';

/// Step 1: Basic Details Registration
class BasicDetailsScreen extends StatefulWidget {
  final AppUser? googleUser;

  const BasicDetailsScreen({super.key, this.googleUser});

  @override
  State<BasicDetailsScreen> createState() => _BasicDetailsScreenState();
}

class _BasicDetailsScreenState extends State<BasicDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();

  Gender _selectedGender = Gender.male;
  String? _selectedState;
  String? _selectedCity;
  Uint8List? _profilePhotoBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.googleUser != null) {
      _nameController.text = widget.googleUser!.displayName ?? '';
      _emailController.text = widget.googleUser!.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (image != null) {
      final imageBytes = await image.readAsBytes();

      if (mounted) {
        final croppedBytes = await showDialog<Uint8List>(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              ImageEditorDialog(imageData: imageBytes, imageName: image.name),
        );

        if (croppedBytes != null) {
          setState(() => _profilePhotoBytes = croppedBytes);
        }
      }
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 18, now.month, now.day);
    final firstDate = DateTime(now.year - 100);
    final lastDate = DateTime(now.year - 18, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.emeraldGreen,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final age = _calculateAge(pickedDate);
      setState(() {
        _dobController.text =
            "${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}";
        _ageController.text = age.toString();
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _proceedToKyc() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await DeliveryAgentService.saveBasicDetails(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        age: int.tryParse(_ageController.text.trim()) ?? 18,
        gender: _selectedGender,
        address: _addressController.text.trim(),
        state: _selectedState!,
        city: _selectedCity!,
        profilePhotoPath: _profilePhotoBytes != null
            ? 'profile_photo.jpg'
            : null,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const KycScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving details: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
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
                    'Create Profile',
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

            // Progress indicator
            _buildProgressIndicator(1, 3, isDark),

            // Form
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
                        'Basic Details',
                        style: AppTypography.headingStyle(
                          color: AppColors.emeraldGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tell us about yourself',
                        style: AppTypography.bodyStyle(
                          color: isDark
                              ? AppColors.textLightSecondary
                              : AppColors.textSecondary,
                          size: 14,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Profile Photo
                      Center(
                        child: GestureDetector(
                          onTap: _pickProfilePhoto,
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.emeraldGreen
                                        .withValues(alpha: 0.3),
                                    width: 3,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: isDark
                                      ? AppColors.darkCard
                                      : AppColors.lightSurface,
                                  backgroundImage: _profilePhotoBytes != null
                                      ? MemoryImage(_profilePhotoBytes!)
                                      : (widget.googleUser?.photoUrl != null
                                            ? NetworkImage(
                                                    widget.googleUser!.photoUrl!,
                                                  )
                                                as ImageProvider
                                            : null),
                                  child: _profilePhotoBytes == null
                                      ? Icon(
                                          Icons.person_rounded,
                                          size: 48,
                                          color: AppColors.emeraldGreen
                                              .withValues(alpha: 0.4),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.emeraldGreen,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.deepNavy
                                          : AppColors.backgroundOffWhite,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Tap to add photo',
                          style: AppTypography.captionStyle(
                            color: isDark
                                ? AppColors.textLightSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Name
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                        isDark: isDark,
                        validator: (v) => v!.isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Email
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        isDark: isDark,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v!.isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Phone
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Mobile Number',
                        icon: Icons.phone_outlined,
                        isDark: isDark,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v!.isEmpty) return 'Mobile number is required';
                          if (v.length < 10) {
                            return 'Enter a valid 10-digit number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Date of Birth
                      _buildTextField(
                        controller: _dobController,
                        label: 'Date of Birth',
                        icon: Icons.calendar_month_rounded,
                        isDark: isDark,
                        readOnly: true,
                        onTap: _pickDateOfBirth,
                        validator: (v) =>
                            v!.isEmpty ? 'Date of Birth is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Age and Gender row
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _ageController,
                              label: 'Age',
                              icon: Icons.cake_outlined,
                              isDark: isDark,
                              readOnly: true,
                              validator: (v) {
                                if (v!.isEmpty) return 'Select DOB';
                                final age = int.tryParse(v);
                                if (age == null || age < 18) return 'Min 18';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildDropdown<Gender>(
                              label: 'Gender',
                              icon: Icons.wc_outlined,
                              isDark: isDark,
                              value: _selectedGender,
                              items: Gender.values
                                  .map(
                                    (g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(_genderLabel(g)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedGender = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // State and City
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown<String>(
                              label: 'State',
                              icon: Icons.map_rounded,
                              isDark: isDark,
                              value: _selectedState,
                              items: AppLocations.states
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                        s,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedState = v;
                                  _selectedCity = null;
                                });
                              },
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown<String>(
                              label: 'City',
                              icon: Icons.location_city_rounded,
                              isDark: isDark,
                              value: _selectedCity,
                              items: _selectedState != null
                                  ? AppLocations.getCities(_selectedState!)
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(
                                              c,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList()
                                  : [],
                              onChanged: (v) => setState(() => _selectedCity = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Address
                      _buildTextField(
                        controller: _addressController,
                        label: 'Full Address',
                        icon: Icons.location_on_outlined,
                        isDark: isDark,
                        maxLines: 3,
                        validator: (v) =>
                            v!.isEmpty ? 'Address is required' : null,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // Continue button
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
                      onPressed: _isLoading ? null : _proceedToKyc,
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
                                  'Continue to KYC',
                                  style: AppTypography.bodyStyle(
                                    color: Colors.white,
                                    weight: FontWeight.w600,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      style: AppTypography.bodyStyle(
        color: isDark ? AppColors.textLight : AppColors.textPrimary,
        size: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.bodyStyle(
          color: isDark
              ? AppColors.textLightSecondary
              : AppColors.textSecondary,
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

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required bool isDark,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      key: ValueKey('${label}_$value'),
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      style: AppTypography.bodyStyle(
        color: isDark ? AppColors.textLight : AppColors.textPrimary,
        size: 15,
      ),
      dropdownColor: isDark ? AppColors.darkCard : Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.bodyStyle(
          color: isDark
              ? AppColors.textLightSecondary
              : AppColors.textSecondary,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  String _genderLabel(Gender g) {
    switch (g) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
    }
  }
}
