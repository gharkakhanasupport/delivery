import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import '../../constants/colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/typography.dart';
import '../../models/delivery_agent.dart';
import '../../services/delivery_agent_service.dart';
import '../../widgets/image_editor_dialog.dart';
import 'vehicle_details_screen.dart';

/// Step 2: KYC Verification
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  IdType _selectedIdType = IdType.aadhar;
  String? _documentPath;
  String? _documentName;

  // OCR Extracted Data
  String? _extractedIdNumber;
  String? _extractedName;
  String? _extractedDob;
  String? _extractedAddress;

  bool _isScanning = false;

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final isImage = [
          'jpg',
          'jpeg',
          'png',
        ].contains(file.extension?.toLowerCase());

        String? finalPath = kIsWeb ? null : file.path;
        String? finalName = file.name;
        bool proceedToOcr = true;

        if (isImage) {
          Uint8List? imageBytes;

          if (kIsWeb) {
            imageBytes = file.bytes;
          } else if (file.path != null) {
            imageBytes = await File(file.path!).readAsBytes();
          }

          if (imageBytes != null && mounted) {
            final croppedBytes = await showDialog<Uint8List>(
              context: context,
              barrierDismissible: false,
              builder: (context) => ImageEditorDialog(
                imageData: imageBytes!,
                imageName: file.name,
              ),
            );

            if (croppedBytes != null) {
              imageBytes = croppedBytes;

              if (!kIsWeb) {
                final tempDir = await getTemporaryDirectory();
                final tempFile = File(
                  '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
                );
                await tempFile.writeAsBytes(croppedBytes);
                finalPath = tempFile.path;
              }
            } else {
              proceedToOcr = false;
            }
          }
        }

        if (proceedToOcr) {
          setState(() {
            _documentPath = finalPath;
            _documentName = finalName;
            _isScanning = true;
            _extractedIdNumber = null;
            _extractedName = null;
            _extractedDob = null;
            _extractedAddress = null;
          });

          if (kIsWeb) {
            await _simulateOcrExtraction();
          } else if (finalPath != null) {
            await _performOcr(finalPath);
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _performOcr(String path) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      String text = recognizedText.text;
      String? idNumber;
      String? dob;
      String? name;

      if (_selectedIdType == IdType.aadhar) {
        final aadharRegex = RegExp(r'\d{4}\s\d{4}\s\d{4}');
        final match = aadharRegex.firstMatch(text);
        if (match != null) idNumber = match.group(0);
      } else {
        final panRegex = RegExp(r'[A-Z]{5}[0-9]{4}[A-Z]{1}');
        final match = panRegex.firstMatch(text);
        if (match != null) idNumber = match.group(0);
      }

      final dobRegex = RegExp(r'\d{2}[/-]\d{2}[/-]\d{4}');
      final dobMatch = dobRegex.firstMatch(text);
      if (dobMatch != null) dob = dobMatch.group(0);

      if (idNumber != null) {
        for (var block in recognizedText.blocks) {
          for (var line in block.lines) {
            final t = line.text.trim();
            if (t.isNotEmpty &&
                !t.contains(idNumber) &&
                !t.contains('DOB') &&
                !t.contains('Government') &&
                !t.contains('India') &&
                t.length > 3 &&
                !RegExp(r'\d').hasMatch(t)) {
              name = t;
              break;
            }
          }
          if (name != null) break;
        }
      }

      await textRecognizer.close();

      if (mounted) {
        setState(() {
          _extractedIdNumber = idNumber;
          _extractedDob = dob;
          _extractedName = name;
          _extractedAddress = null;
          _isScanning = false;
        });

        if (idNumber != null || name != null || dob != null) {
          _showSuccessSnackBar();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not extract details. Please try a clearer image.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('OCR Failed: $e');
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR Failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _simulateOcrExtraction() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        if (_selectedIdType == IdType.aadhar) {
          _extractedIdNumber = 'XXXX XXXX XXXX (Simulated)';
          _extractedName = "Simulated User (Web)";
          _extractedDob = "01/01/2000";
        } else {
          _extractedIdNumber = 'ABCDE1234F (Simulated)';
          _extractedName = "Simulated User (Web)";
          _extractedDob = "01/01/2000";
        }
        _extractedAddress = "Simulated Address for Web Testing";
        _isScanning = false;
      });
      _showSuccessSnackBar();
    }
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Document scanned successfully!'),
          ],
        ),
        backgroundColor: AppColors.emeraldGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  final bool _isLoading = false;

  Future<void> _proceedToVehicle() async {
    if (_documentPath == null && !kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your ID document'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (kIsWeb && _documentName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your ID document'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isScanning = true);

    try {
      await DeliveryAgentService.saveKycDetails(
        idType: _selectedIdType,
        idDocumentPath: _documentPath ?? 'web_upload_$_documentName',
        idNumber: _extractedIdNumber,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VehicleDetailsScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving KYC details: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
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
                    'KYC Verification',
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
            _buildProgressIndicator(2, 3, isDark),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  AppConstants.responsivePadding(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID Verification',
                      style: AppTypography.headingStyle(
                        color: AppColors.goldenMustard,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload your government ID for verification',
                      style: AppTypography.bodyStyle(
                        color: isDark
                            ? AppColors.textLightSecondary
                            : AppColors.textSecondary,
                        size: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ID Type Selection
                    Text(
                      'Select ID Type',
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
                          child: _buildIdTypeCard(
                            type: IdType.aadhar,
                            label: 'Aadhar Card',
                            icon: Icons.badge_outlined,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildIdTypeCard(
                            type: IdType.pan,
                            label: 'PAN Card',
                            icon: Icons.credit_card_outlined,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Document Upload
                    Text(
                      'Upload Document',
                      style: AppTypography.titleStyle(
                        color: isDark
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Supported formats: JPG, PNG, PDF',
                      style: AppTypography.captionStyle(
                        color: isDark
                            ? AppColors.textLightSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildUploadArea(isDark),

                    const SizedBox(height: 24),

                    if (_isScanning)
                      Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                              color: AppColors.goldenMustard,
                              strokeWidth: 2.5,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              "Scanning document...",
                              style: AppTypography.bodyStyle(
                                color: isDark
                                    ? AppColors.textLightSecondary
                                    : AppColors.textSecondary,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_extractedIdNumber != null ||
                        _extractedName != null) ...[
                      Text(
                        'Extracted Details',
                        style: AppTypography.titleStyle(
                          color: AppColors.emeraldGreen,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              AppColors.emeraldGreen.withValues(alpha: 0.06),
                          borderRadius: AppConstants.borderRadiusLarge,
                          border: Border.all(
                            color: AppColors.emeraldGreen.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                              'ID Number',
                              _extractedIdNumber ?? 'Not found',
                              isDark,
                            ),
                            if (_extractedName != null)
                              _buildDetailRow(
                                'Name',
                                _extractedName!,
                                isDark,
                              ),
                            if (_extractedDob != null)
                              _buildDetailRow(
                                'DOB',
                                _extractedDob!,
                                isDark,
                              ),
                            if (_extractedAddress != null)
                              _buildDetailRow(
                                'Address',
                                _extractedAddress!,
                                isDark,
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
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
                              colors: AppColors.goldGradient,
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
                                color: AppColors.goldenMustard
                                    .withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _proceedToVehicle,
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
                                color: AppColors.goldenMustard,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue to Vehicle Details',
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
                        colors: AppColors.goldGradient,
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

  Widget _buildIdTypeCard({
    required IdType type,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedIdType == type;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedIdType = type;
        _extractedIdNumber = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.goldenMustard.withValues(alpha: 0.08)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: AppConstants.borderRadiusLarge,
          border: Border.all(
            color: isSelected
                ? AppColors.goldenMustard
                : (isDark ? AppColors.borderDark : AppColors.borderSubtle),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 30,
              color: isSelected
                  ? AppColors.goldenMustard
                  : (isDark
                      ? AppColors.textLightSecondary
                      : AppColors.mediumGrey),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.bodyStyle(
                color: isSelected
                    ? AppColors.goldenMustard
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

  Widget _buildUploadArea(bool isDark) {
    if (_documentPath != null || (kIsWeb && _documentName != null)) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.emeraldGreen.withValues(alpha: 0.06),
          borderRadius: AppConstants.borderRadiusLarge,
          border: Border.all(
            color: AppColors.emeraldGreen.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.emeraldGreen,
                borderRadius: AppConstants.borderRadiusMedium,
              ),
              child: Icon(
                _getFileIcon(_documentName ?? ''),
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _documentName ?? 'Document',
                    style: AppTypography.bodyStyle(
                      color: isDark
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                      weight: FontWeight.w600,
                      size: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Uploaded successfully',
                    style: AppTypography.captionStyle(
                      color: AppColors.emeraldGreen,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() {
                _documentPath = null;
                _documentName = null;
                _extractedIdNumber = null;
              }),
              icon: const Icon(Icons.close_rounded, color: AppColors.error),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _pickDocument,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: AppConstants.borderRadiusLarge,
          border: Border.all(
            color: isDark
                ? AppColors.borderDark
                : AppColors.borderSubtle,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.goldenMustard.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_rounded,
                size: 36,
                color: AppColors.goldenMustard,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Tap to upload document',
              style: AppTypography.bodyStyle(
                color: isDark
                    ? AppColors.textLight
                    : AppColors.textPrimary,
                weight: FontWeight.w600,
                size: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'JPG, PNG or PDF',
              style: AppTypography.captionStyle(
                color: isDark
                    ? AppColors.textLightSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.captionStyle(
                color: AppColors.emeraldGreen,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyStyle(
                color: isDark
                    ? AppColors.textLight
                    : AppColors.textPrimary,
                weight: FontWeight.w500,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
