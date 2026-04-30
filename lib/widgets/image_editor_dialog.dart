import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:crop_image/crop_image.dart';
import '../constants/colors.dart';

/// Image editor with crop functionality using crop_image package
class ImageEditorDialog extends StatefulWidget {
  final Uint8List imageData;
  final String imageName;

  const ImageEditorDialog({
    super.key,
    required this.imageData,
    required this.imageName,
  });

  @override
  State<ImageEditorDialog> createState() => _ImageEditorDialogState();
}

class _ImageEditorDialogState extends State<ImageEditorDialog> {
  late final CropController _cropController;
  double _rotation = 0;

  @override
  void initState() {
    super.initState();
    _cropController = CropController(
      aspectRatio: null, // Freeform crop
      defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
    );
  }

  @override
  void dispose() {
    _cropController.dispose();
    super.dispose();
  }

  void _rotate() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
    });
    // Update crop controller rotation
    if (_rotation == 90) {
      _cropController.rotation = CropRotation.right;
    } else if (_rotation == 180) {
      _cropController.rotation = CropRotation.down;
    } else if (_rotation == 270) {
      _cropController.rotation = CropRotation.left;
    } else {
      _cropController.rotation = CropRotation.up;
    }
  }

  Future<void> _cropImage() async {
    try {
      final croppedImage = await _cropController.croppedBitmap();
      if (mounted) {
        // Convert bitmap to Uint8List
        final byteData = await croppedImage.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (!mounted) return;

        if (byteData != null) {
          final bytes = byteData.buffer.asUint8List();
          Navigator.pop(context, bytes);
        }
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.emeraldGreen,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.crop, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Crop Image',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Crop Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CropImage(
                  controller: _cropController,
                  image: Image.memory(widget.imageData),
                  gridColor: AppColors.emeraldGreen,
                  gridCornerSize: 30,
                  gridThinWidth: 1,
                  gridThickWidth: 3,
                  scrimColor: Colors.black.withValues(alpha: 0.7),
                ),
              ),
            ),

            // Info text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Drag to adjust • Pinch to zoom',
                style: TextStyle(color: AppColors.mediumGrey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // Controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.deepNavy : AppColors.lightGrey,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Rotate button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _rotate,
                      icon: const Icon(Icons.rotate_right, size: 20),
                      label: Text('${_rotation.toInt()}°'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.emeraldGreen,
                        side: BorderSide(color: AppColors.emeraldGreen),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Save button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _cropImage,
                      icon: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
