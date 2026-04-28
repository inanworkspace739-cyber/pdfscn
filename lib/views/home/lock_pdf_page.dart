import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/constants/constants.dart';

class LockPdfPage extends StatefulWidget {
  final File file;

  const LockPdfPage({super.key, required this.file});

  @override
  State<LockPdfPage> createState() => _LockPdfPageState();
}

class _LockPdfPageState extends State<LockPdfPage> {
  bool _isLocking = false;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;

  Future<void> _lockAndSave() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both password fields.')),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    setState(() => _isLocking = true);

    try {
      // Extract base name and append _locked
      final originalFileName = widget.file.path.split('/').last;
      final baseName = originalFileName.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      final lockedFileName = '${baseName}_locked.pdf';

      final bytes = await widget.file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      // Apply password encryption
      document.security.userPassword = password;
      document.security.ownerPassword = password;
      document.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

      final List<int> savedBytes = document.saveSync();
      document.dispose();

      // Save to temp with the EXACT same filename
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$lockedFileName';
      final file = File(filePath);
      await file.writeAsBytes(savedBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF Locked Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // iOS will prompt "Replace" if user saves to same directory
      // Get share position for iPad
      final box = context.findRenderObject() as RenderBox?;
      final sharePosition = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: 'Here is your password-protected PDF.',
          sharePositionOrigin: sharePosition,
        ),
      );

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  color: Colors.green,
                  size: 28,
                ),
                const SizedBox(width: 10),
                const Text("Lock Successful"),
              ],
            ),
            content: const Text(
              "Your PDF has been successfully protected with a password.\n\n"
              "⚠️ Important Security Note: To ensure complete privacy, "
              "please remember to manually delete the original unlocked "
              "file from your device's Files app.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                },
                child: const Text(
                  "Got it",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context); // Return to main menu
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to lock PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.path.split('/').last;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Lock PDF",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppConstants.backgroundColor,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        CupertinoIcons.lock_shield_fill,
                        color: Colors.indigo,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                "Set Password",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "This password will be required to open the PDF.",
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: "Enter Password",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword
                          ? CupertinoIcons.eye_slash
                          : CupertinoIcons.eye,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Password Field
              TextField(
                controller: _confirmController,
                obscureText: !_showConfirm,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirm
                          ? CupertinoIcons.eye_slash
                          : CupertinoIcons.eye,
                    ),
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
              ),

              const Spacer(),

              // Lock Button
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLocking ? null : _lockAndSave,
                    icon: _isLocking
                        ? const SizedBox.shrink()
                        : const Icon(CupertinoIcons.lock_fill, size: 22),
                    label: _isLocking
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Lock & Save PDF",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppConstants.primaryColor
                          .withValues(alpha: 0.6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
}
