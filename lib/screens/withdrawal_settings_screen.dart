import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/app_constants.dart';
import '../services/delivery_agent_service.dart';

class WithdrawalSettingsScreen extends StatefulWidget {
  const WithdrawalSettingsScreen({super.key});

  @override
  State<WithdrawalSettingsScreen> createState() => _WithdrawalSettingsScreenState();
}

class _WithdrawalSettingsScreenState extends State<WithdrawalSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscController;
  late TextEditingController _upiController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final agent = DeliveryAgentService.currentAgent.value;
    _bankNameController = TextEditingController(text: agent?.bankName ?? '');
    _accountNumberController = TextEditingController(text: agent?.accountNumber ?? '');
    _ifscController = TextEditingController(text: agent?.ifscCode ?? '');
    _upiController = TextEditingController(text: agent?.upiId ?? '');
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await DeliveryAgentService.updateBankDetails(
        bankName: _bankNameController.text,
        accountNumber: _accountNumberController.text,
        ifscCode: _ifscController.text,
        upiId: _upiController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Financial details updated successfully!'),
            backgroundColor: AppColors.emeraldGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusBadge({required bool isValid, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isValid 
            ? AppColors.emeraldGreen.withValues(alpha: 0.1) 
            : (isDark ? Colors.white10 : Colors.grey[100]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? AppColors.emeraldGreen : (isDark ? Colors.white24 : Colors.grey[300]!),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 14,
            color: isValid ? AppColors.emeraldGreen : (isDark ? Colors.white38 : Colors.grey[400]),
          ),
          const SizedBox(width: 4),
          Text(
            isValid ? 'VERIFIED' : 'PENDING',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isValid ? AppColors.emeraldGreen : (isDark ? Colors.white38 : Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : AppColors.backgroundOffWhite,
      appBar: AppBar(
        title: const Text('Withdrawal Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoSection(isDark),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bank Account Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _buildStatusBadge(
                    isValid: _accountNumberController.text.isNotEmpty && _ifscController.text.isNotEmpty,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Bank Name',
                controller: _bankNameController,
                icon: Icons.account_balance_rounded,
                isDark: isDark,
                placeholder: 'e.g. HDFC Bank',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Account Number',
                controller: _accountNumberController,
                icon: Icons.numbers_rounded,
                isDark: isDark,
                placeholder: 'e.g. 501000...',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Account number is required';
                  if (value.length < 9 || value.length > 18) return 'Invalid account number length';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'IFSC Code',
                controller: _ifscController,
                icon: Icons.code_rounded,
                isDark: isDark,
                placeholder: 'e.g. HDFC0001234',
                validator: (value) {
                  if (value == null || value.isEmpty) return 'IFSC code is required';
                  final regExp = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
                  if (!regExp.hasMatch(value.toUpperCase())) return 'Invalid IFSC format (e.g. HDFC0001234)';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'UPI Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _buildStatusBadge(
                    isValid: _upiController.text.contains('@'),
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'UPI ID',
                controller: _upiController,
                icon: Icons.alternate_email_rounded,
                isDark: isDark,
                placeholder: 'e.g. mobile@upi or name@bank',
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!value.contains('@')) return 'Invalid UPI ID format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppConstants.borderRadiusLarge,
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Financial Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.emeraldGreen.withValues(alpha: 0.1),
        borderRadius: AppConstants.borderRadiusLarge,
        border: Border.all(color: AppColors.emeraldGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.emeraldGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'These details will be used for your weekly earnings payout. Please ensure accuracy.',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator ?? (value) {
            if (value == null || value.isEmpty) return 'This field is required';
            return null;
          },
          style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey[400]),
            prefixIcon: Icon(icon, color: AppColors.emeraldGreen, size: 20),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : Colors.white,
            border: OutlineInputBorder(
              borderRadius: AppConstants.borderRadiusMedium,
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppConstants.borderRadiusMedium,
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppConstants.borderRadiusMedium,
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppConstants.borderRadiusMedium,
              borderSide: const BorderSide(color: AppColors.emeraldGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
