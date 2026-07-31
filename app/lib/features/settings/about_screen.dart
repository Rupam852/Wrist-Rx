import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';

class ContributorInfo {
  final String name;
  final String role;
  final String imagePath;
  final String instagramUrl;

  const ContributorInfo({
    required this.name,
    required this.role,
    required this.imagePath,
    required this.instagramUrl,
  });
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const List<ContributorInfo> _contributors = [
    ContributorInfo(
      name: 'Agnik Banerjee',
      role: 'Project Contributor',
      imagePath: 'assets/images/contributors/agnik.jpg',
      instagramUrl: 'https://www.instagram.com/agnik._.banerjee?igsh=dzNxczk5dTdlZHJl',
    ),
    ContributorInfo(
      name: 'Sk Soyel',
      role: 'Project Contributor',
      imagePath: 'assets/images/contributors/soyel.jpg',
      instagramUrl: 'https://www.instagram.com/soyel__27?igsh=OHdzaWJwZXFzNHN3',
    ),
    ContributorInfo(
      name: 'Sanjana Singha',
      role: 'Project Contributor',
      imagePath: 'assets/images/contributors/sanjana.jpg',
      instagramUrl: 'https://www.instagram.com/sanjana_singh_2406?igsh=YWVyZHYyeDBiN2lj',
    ),
    ContributorInfo(
      name: 'Shreyansh Roy',
      role: 'Project Contributor',
      imagePath: 'assets/images/contributors/shreyansh.jpg',
      instagramUrl: 'https://www.instagram.com/shreyansh.raw?igsh=dGlpczliM3l1aHcw',
    ),
    ContributorInfo(
      name: 'Suchandra Jana',
      role: 'Project Contributor',
      imagePath: 'assets/images/contributors/suchandra.jpg',
      instagramUrl: 'https://www.instagram.com/suchandra______?igsh=MWd2ZTR6cHU4YzBlZA==',
    ),
  ];

  Future<void> _launchUrl(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('About Wrist Rx', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const SizedBox(height: 12),
          // ── App Header Section ─────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(54, 54),
                      painter: _LogoPainter(),
                    ),
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 16),
                const Text(
                  'Wrist Rx',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Version 1.0.0+1',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 10),
                Text(
                  'Your Personal Health Companion Smartwatch App',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.onSurfaceDark,
                    fontSize: 13,
                  ),
                ).animate().fadeIn(delay: 250.ms),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Contributors Section ──────────────────────────────────
          _SectionTitle(title: 'Contributors'),
          const SizedBox(height: 10),
          ..._contributors.map((c) => _ContributorCard(
            info: c,
            onTapInstagram: () => _launchUrl(c.instagramUrl),
          )).toList().animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 28),

          // ── Developer Section ──────────────────────────────────────
          _SectionTitle(title: 'Developer'),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.cardDark,
                  AppColors.cardDark.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Round Circular Profile Photo with Accent Border & Glow
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: 'https://github.com/Rupam852.png',
                          width: 66,
                          height: 66,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.white10,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.primary.withOpacity(0.2),
                            child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 36),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rupam Bairagya',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '@Rupam852',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lead Mobile & Backend Developer',
                            style: TextStyle(
                              color: AppColors.onSurfaceDark,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _SocialButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Instagram',
                        gradientColors: const [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF77737)],
                        onTap: () => _launchUrl('https://www.instagram.com/_rupambairagya_?igsh=MWNsNHFiZzE4bnQ5OQ=='),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SocialButton(
                        icon: Icons.link_rounded,
                        label: 'LinkFlow',
                        gradientColors: const [Color(0xFF0072FF), Color(0xFF00C6FF)],
                        onTap: () => _launchUrl('https://link-flow-program.vercel.app/rupam-bairagya'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SocialButton(
                        icon: Icons.code_rounded,
                        label: 'GitHub',
                        gradientColors: const [Color(0xFF24292E), Color(0xFF404448)],
                        onTap: () => _launchUrl('https://github.com/Rupam852'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 350.ms),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ContributorCard extends StatelessWidget {
  final ContributorInfo info;
  final VoidCallback onTapInstagram;

  const _ContributorCard({
    required this.info,
    required this.onTapInstagram,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          // Round Profile Photo
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 2),
            ),
            child: ClipOval(
              child: Image.asset(
                info.imagePath,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 52,
                  height: 52,
                  color: Colors.white10,
                  child: const Icon(Icons.person_rounded, color: Colors.white54),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name, Role & Instagram Contact Button
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.role,
                  style: TextStyle(
                    color: AppColors.onSurfaceDark,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),

                // Instagram Profile Link Button
                InkWell(
                  onTap: onTapInstagram,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF77737)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 5),
                        Text(
                          'Contact on Instagram',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color>? gradientColors;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          gradient: gradientColors != null
              ? LinearGradient(colors: gradientColors!)
              : null,
          color: gradientColors == null ? Colors.white.withOpacity(0.06) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.08;

    final heartPath = Path();
    heartPath.moveTo(size.width * 0.5, size.height * 0.85);
    heartPath.cubicTo(
      size.width * 0.1, size.height * 0.55,
      size.width * 0.05, size.height * 0.25,
      size.width * 0.3, size.height * 0.2,
    );
    heartPath.cubicTo(
      size.width * 0.42, size.height * 0.18,
      size.width * 0.48, size.height * 0.3,
      size.width * 0.5, size.height * 0.35,
    );
    heartPath.cubicTo(
      size.width * 0.52, size.height * 0.3,
      size.width * 0.58, size.height * 0.18,
      size.width * 0.7, size.height * 0.2,
    );
    heartPath.cubicTo(
      size.width * 0.95, size.height * 0.25,
      size.width * 0.9, size.height * 0.55,
      size.width * 0.5, size.height * 0.85,
    );
    heartPath.close();

    final fillPaint = Paint()
      ..color = const Color(0xFF00C853)
      ..style = PaintingStyle.fill;
    canvas.drawPath(heartPath, fillPaint);

    final ecgPath = Path();
    ecgPath.moveTo(size.width * 0.12, size.height * 0.52);
    ecgPath.lineTo(size.width * 0.32, size.height * 0.52);
    ecgPath.lineTo(size.width * 0.40, size.height * 0.26);
    ecgPath.lineTo(size.width * 0.48, size.height * 0.74);
    ecgPath.lineTo(size.width * 0.56, size.height * 0.38);
    ecgPath.lineTo(size.width * 0.62, size.height * 0.56);
    ecgPath.lineTo(size.width * 0.68, size.height * 0.52);
    ecgPath.lineTo(size.width * 0.88, size.height * 0.52);

    final ecgPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(ecgPath, ecgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
