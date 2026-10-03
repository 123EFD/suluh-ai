import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/grid_painter.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onNavigate;
  
  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomPaint(
        painter: GridPainter(isDark: isDark),
        child: SizedBox.expand(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header Section
                    Text(
                      "AI STUDY SUITE",
                      style: GoogleFonts.cinzel(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.spaceCadet,
                        letterSpacing: 3.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Your collegiate edutech workspace. Analyze your academic trajectory, diagnose prerequisite bottlenecks, interrogate lecture archives, and assemble time-budgeted study bundles.",
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: isDark ? DarkAcademiaPalette.antiqueIvory.withValues(alpha: 0.8) : DarkAcademiaPalette.oxfordBrown,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Section Tag
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.12) 
                                : DarkAcademiaPalette.caputMortuum.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark 
                                  ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.35) 
                                  : DarkAcademiaPalette.caputMortuum.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            "// EXPLORE WORKFLOWS & MODES",
                            style: GoogleFonts.shareTechMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Asymmetrical Bento Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 760;

                        if (isWide) {
                          // Desktop / Tablet Bento arrangement
                          return Column(
                            children: [
                              // Hero Bento Card (Spans full top row)
                              _buildHeroBentoCard(
                                context: context,
                                isDark: isDark,
                                onNavigate: () => onNavigate(1),
                              ),
                              const SizedBox(height: 20),
                              // Bottom Row: 2 Parallel Bento Cards (50/50 split)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildBundleBentoCard(
                                      context: context,
                                      isDark: isDark,
                                      onNavigate: () => onNavigate(2),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _buildPdfChatBentoCard(
                                      context: context,
                                      isDark: isDark,
                                      onNavigate: () => onNavigate(3),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildDiagnosticRadarBentoCard(
                                context: context,
                                isDark: isDark,
                                onNavigate: () => onNavigate(4),
                              ),
                            ],
                          );
                        } else {
                          // Mobile Stacked Bento cards
                          return Column(
                            children: [
                              _buildHeroBentoCard(
                                context: context,
                                isDark: isDark,
                                onNavigate: () => onNavigate(1),
                              ),
                              const SizedBox(height: 16),
                              _buildBundleBentoCard(
                                context: context,
                                isDark: isDark,
                                onNavigate: () => onNavigate(2),
                              ),
                              const SizedBox(height: 16),
                              _buildPdfChatBentoCard(
                                context: context,
                                isDark: isDark,
                                onNavigate: () => onNavigate(3),
                              ),
                              const SizedBox(height: 16),
                              _buildDiagnosticRadarBentoCard(
                                context: context,
                                isDark: isDark,
                                onNavigate: () => onNavigate(4),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 1. HERO BENTO CARD: Academic Recommender
  Widget _buildHeroBentoCard({
    required BuildContext context,
    required bool isDark,
    required VoidCallback onNavigate,
  }) {
    return InkWell(
      onTap: onNavigate,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark 
              ? const Color(0xFF1E2024).withValues(alpha: 0.85) 
              : const Color(0xFFF9F7F2).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark 
                ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.35) 
                : DarkAcademiaPalette.tan.withValues(alpha: 0.70),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.4) 
                  : DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? DarkAcademiaPalette.spaceCadet.withValues(alpha: 0.6) 
                            : DarkAcademiaPalette.spaceCadet.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark 
                              ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.3) 
                              : DarkAcademiaPalette.spaceCadet.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.psychology_outlined,
                        size: 32,
                        color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.spaceCadet,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "01 // ADAPTIVE DIAGNOSTICS",
                          style: GoogleFonts.shareTechMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          "Academic Recommender Engine",
                          style: GoogleFonts.cinzel(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.spaceCadet,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: DarkAcademiaPalette.forestMoss.withValues(alpha: isDark ? 0.35 : 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DarkAcademiaPalette.forestMoss.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4E7A4A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "NEURAL MODEL READY",
                        style: GoogleFonts.shareTechMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFA3D99B) : DarkAcademiaPalette.forestMoss,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Predict your academic trajectory from attendance, prep hours, and GPA records. Our PyTorch MLP predicts performance risks while the DAG Engine traces upstream root-cause prerequisite gaps.",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? DarkAcademiaPalette.antiqueIvory.withValues(alpha: 0.8) : DarkAcademiaPalette.oxfordBrown,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildMiniPill(isDark, Icons.timeline, "GPA Trajectory"),
                const SizedBox(width: 8),
                _buildMiniPill(isDark, Icons.account_tree_outlined, "DAG Prerequisite Tracing"),
                const SizedBox(width: 8),
                _buildMiniPill(isDark, Icons.local_fire_department, "Wilson Heatmap"),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      "Launch Profile",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2. BENTO CARD: Survival Study Bundle
  Widget _buildBundleBentoCard({
    required BuildContext context,
    required bool isDark,
    required VoidCallback onNavigate,
  }) {
    return InkWell(
      onTap: onNavigate,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 270,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark 
              ? const Color(0xFF1E2024).withValues(alpha: 0.85) 
              : const Color(0xFFF9F7F2).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark 
                ? DarkAcademiaPalette.burntUmber.withValues(alpha: 0.45) 
                : DarkAcademiaPalette.tan.withValues(alpha: 0.70),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.35) 
                  : DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DarkAcademiaPalette.burntUmber.withValues(alpha: isDark ? 0.3 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 26,
                        color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.burntUmber,
                      ),
                    ),
                    Text(
                      "02 // TIME-BUDGETED",
                      style: GoogleFonts.shareTechMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.burntUmber,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  "Survival Study Bundler",
                  style: GoogleFonts.cinzel(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.spaceCadet,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Have 15 minutes before class? Knapsack AI packs flashcards, exam questions, and YouTube crash courses into your exact schedule.",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? DarkAcademiaPalette.antiqueIvory.withValues(alpha: 0.75) : DarkAcademiaPalette.oxfordBrown,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildTimeBadge("15m", isDark),
                    const SizedBox(width: 6),
                    _buildTimeBadge("30m", isDark),
                    const SizedBox(width: 6),
                    _buildTimeBadge("60m", isDark),
                  ],
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.burntUmber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 3. BENTO CARD: PDF Knowledge Chat
  Widget _buildPdfChatBentoCard({
    required BuildContext context,
    required bool isDark,
    required VoidCallback onNavigate,
  }) {
    return InkWell(
      onTap: onNavigate,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 270,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark 
              ? const Color(0xFF1E2024).withValues(alpha: 0.85) 
              : const Color(0xFFF9F7F2).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark 
                ? DarkAcademiaPalette.vintageMaroon.withValues(alpha: 0.45) 
                : DarkAcademiaPalette.caputMortuum.withValues(alpha: 0.30),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.35) 
                  : DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DarkAcademiaPalette.caputMortuum.withValues(alpha: isDark ? 0.35 : 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        size: 26,
                        color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                      ),
                    ),
                    Text(
                      "03 // MULTI-PERSPECTIVE",
                      style: GoogleFonts.shareTechMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  "Interactive PDF Chat",
                  style: GoogleFonts.cinzel(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.spaceCadet,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Interrogate course slides with RAG search. Switch lenses between intuitive Real-World Analogies, Visual Flowcharts, or Exam Mark Schemes.",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? DarkAcademiaPalette.antiqueIvory.withValues(alpha: 0.75) : DarkAcademiaPalette.oxfordBrown,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildMiniPill(isDark, Icons.auto_awesome, "3 Lenses"),
                    const SizedBox(width: 6),
                    _buildMiniPill(isDark, Icons.picture_as_pdf_outlined, "PyMuPDF"),
                  ],
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPill(bool isDark, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark 
            ? DarkAcademiaPalette.charcoalSlate.withValues(alpha: 0.8) 
            : DarkAcademiaPalette.tan.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark 
              ? DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.6) 
              : DarkAcademiaPalette.tan.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.oxfordBrown),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.oxfordBrown,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBadge(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark 
            ? DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.5) 
            : DarkAcademiaPalette.tan.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark 
              ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.4) 
              : DarkAcademiaPalette.burntUmber.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.shareTechMono(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.burntUmber,
        ),
      ),
    );
  }

  Widget _buildDiagnosticRadarBentoCard({
    required BuildContext context,
    required bool isDark,
    required VoidCallback onNavigate,
  }) {
    return InkWell(
      onTap: onNavigate,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark 
              ? const Color(0xFF1E2024).withValues(alpha: 0.85) 
              : const Color(0xFFF9F7F2).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark 
                ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.35) 
                : DarkAcademiaPalette.tan.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.35) 
                  : DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DarkAcademiaPalette.forestMoss.withValues(alpha: isDark ? 0.3 : 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DarkAcademiaPalette.forestMoss.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.radar_rounded,
                size: 32,
                color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.forestMoss,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "04 // EXAM RADAR & DIAGNOSTICS",
                        style: GoogleFonts.shareTechMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      _buildMiniPill(isDark, Icons.psychology_outlined, "BKT Mastery"),
                      const SizedBox(width: 6),
                      _buildMiniPill(isDark, Icons.filter_center_focus, "Cognitive Lenses"),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Chapter Diagnostic Radar & Adaptive Focus",
                    style: GoogleFonts.cinzel(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.spaceCadet,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Analyze PDF chapters with the Diagnostic Radar. Switch between 4 Cognitive Lenses, practice with Bayesian Knowledge Tracing (BKT), and generate deep-dive flashcards.",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? DarkAcademiaPalette.antiqueIvory.withValues(alpha: 0.75) : DarkAcademiaPalette.oxfordBrown,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
            ),
          ],
        ),
      ),
    );
  }
}
