import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  final String _appId = '6762295330';
  final String _contactEmail = 'azoworkspace@gmail.com';
  final String _privacyUrl = 'https://pdfsc.blogspot.com/2026/04/psdsc.html';

  Future<void> _shareApp() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Check out PDF Scanner: Edit & Convert on the App Store! https://apps.apple.com/app/id$_appId',
      ),
    );
  }

  Future<void> _rateApp() async {
    final url = Uri.parse(
      'itms-apps://itunes.apple.com/app/id$_appId?action=write-review',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _contactUs() async {
    final url = Uri.parse(
      'mailto:$_contactEmail?subject=Support Request - PDF Scanner',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final url = Uri.parse(_privacyUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Very subtle premium off-white
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Premium App Icon Display
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(
                        alpha: 0.2,
                      ), // Matches icon vibe
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                      spreadRadius: -10,
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(4), // Simulated border
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset(
                      'lib/Assets/icon.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              const Text(
                'PDF Scanner',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1E1E),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Segmented Premium Group
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _PremiumSettingTile(
                      icon: CupertinoIcons.share,
                      iconColor: Colors.blueAccent,
                      title: 'Share App',
                      onTap: _shareApp,
                      isFirst: true,
                    ),
                    _buildDivider(),
                    _PremiumSettingTile(
                      icon: CupertinoIcons.star_fill,
                      iconColor: Colors.amber.shade500,
                      title: 'Rate Us',
                      onTap: _rateApp,
                    ),
                    _buildDivider(),
                    _PremiumSettingTile(
                      icon: CupertinoIcons.mail_solid,
                      iconColor: Colors.teal,
                      title: 'Contact Us',
                      onTap: _contactUs,
                    ),
                    _buildDivider(),
                    _PremiumSettingTile(
                      icon: CupertinoIcons.doc_text_fill,
                      iconColor: Colors.deepPurpleAccent,
                      title: 'Privacy Policy',
                      onTap: _openPrivacyPolicy,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Bottom Footer
              Text(
                'Made with ❤️ for PDF Scanning',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 64, right: 20),
      child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
    );
  }
}

class _PremiumSettingTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _PremiumSettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  State<_PremiumSettingTile> createState() => _PremiumSettingTileState();
}

class _PremiumSettingTileState extends State<_PremiumSettingTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(widget.isFirst ? 24 : 0),
      topRight: Radius.circular(widget.isFirst ? 24 : 0),
      bottomLeft: Radius.circular(widget.isLast ? 24 : 0),
      bottomRight: Radius.circular(widget.isLast ? 24 : 0),
    );

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _isPressed
              ? Colors.grey.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: borderRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Glowing Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 22),
            ),
            const SizedBox(width: 16),

            // Title
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2C),
                  letterSpacing: -0.3,
                ),
              ),
            ),

            // Chevron
            Icon(
              CupertinoIcons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
