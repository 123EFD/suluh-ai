import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../models/resource_item.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';

import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../export/file_saver.dart';

class PyqSolutionWidget extends StatefulWidget {
  final ResourceItem item;
  const PyqSolutionWidget({super.key, required this.item});

  @override
  State<PyqSolutionWidget> createState() => _PyqSolutionWidgetState();
}

class _PyqSolutionWidgetState extends State<PyqSolutionWidget> {
  String? _lensResult;
  bool _isLoadingLens = false;
  bool _isExportingPdf = false;
  String _activeLens = "None";

  // Function to call the Lens Switcher API
  Future<void> _applyLens(String lensType) async {
    setState(() {
      _isLoadingLens = true;
      _activeLens = lensType;
    });

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/lens/transform');
      final body = jsonEncode({
        "source_text": widget.item.content,
        "lens": lensType
      });

      final response = await http.post(url, headers: {'Content-Type' : 'application/json'},
      body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _lensResult = data['transformed'];
      } else {
        _lensResult = "Error applying lens: ${response.body}";
      }
    } catch (e) {
      _lensResult = "Error applying lens: $e";
    }

    setState(() => _isLoadingLens = false);
  }

  Future<void> _exportToPdf() async {
    setState(() => _isExportingPdf = true);

    try {
      final PdfDocument document = PdfDocument();
      document.pageSettings.margins.all = 36;
      final PdfPage page = document.pages.add();
      final Size pageSize = page.getClientSize();

      // Fonts
      final PdfStandardFont headerFont = PdfStandardFont(
        PdfFontFamily.timesRoman,
        17,
        style: PdfFontStyle.bold,
      );
      final PdfStandardFont subHeaderFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        9,
        style: PdfFontStyle.bold,
      );
      final PdfStandardFont sectionFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        11,
        style: PdfFontStyle.bold,
      );
      final PdfStandardFont bodyFont = PdfStandardFont(
        PdfFontFamily.timesRoman,
        10.5,
      );

      // Colors
      final PdfColor primaryColor = PdfColor(99, 32, 36); // Caput Mortuum #632024
      final PdfColor goldColor = PdfColor(191, 167, 111); // Faded Gold #BFA76F
      final PdfColor darkColor = PdfColor(44, 46, 48); // Charcoal Slate
      final PdfColor lightBg = PdfColor(250, 247, 240); // Antique Ivory

      double y = 0;

      // Top Decorative Header Box
      page.graphics.drawRectangle(
        pen: PdfPen(goldColor, width: 1.5),
        brush: PdfSolidBrush(lightBg),
        bounds: Rect.fromLTWH(0, y, pageSize.width, 48),
      );

      // Title
      page.graphics.drawString(
        "ACADEMIC ARCHIVAL RECORD // PROBLEM FOLIO",
        headerFont,
        brush: PdfSolidBrush(primaryColor),
        bounds: Rect.fromLTWH(12, y + 8, pageSize.width - 24, 22),
      );

      // Meta info
      page.graphics.drawString(
        "SUBJECT: ${widget.item.topic.toUpperCase()}  |  DURATION: ${widget.item.durationMin} MIN  |  LENS: ${_activeLens.toUpperCase()}",
        subHeaderFont,
        brush: PdfSolidBrush(darkColor),
        bounds: Rect.fromLTWH(12, y + 30, pageSize.width - 24, 14),
      );

      y += 62;

      // Section 1: Problem Statement
      page.graphics.drawString(
        "I. ARCHIVAL PROBLEM STATEMENT",
        sectionFont,
        brush: PdfSolidBrush(primaryColor),
        bounds: Rect.fromLTWH(0, y, pageSize.width, 18),
      );
      y += 20;

      page.graphics.drawLine(
        PdfPen(goldColor, width: 1),
        Offset(0, y),
        Offset(pageSize.width, y),
      );
      y += 8;

      final PdfTextElement problemElement = PdfTextElement(
        text: widget.item.content,
        font: bodyFont,
        brush: PdfSolidBrush(darkColor),
      );
      final PdfLayoutResult problemResult = problemElement.draw(
        page: page,
        bounds: Rect.fromLTWH(0, y, pageSize.width, pageSize.height - y),
      )!;

      PdfPage activePage = problemResult.page;
      y = problemResult.bounds.bottom + 25;

      // Check if we need a new page for Section 2
      if (y > activePage.getClientSize().height - 100) {
        activePage = document.pages.add();
        y = 20;
      }

      final lensTitle = (_lensResult != null && _lensResult!.isNotEmpty)
          ? "II. PEDAGOGICAL LENS ANALYSIS [$_activeLens]"
          : "II. SYNTHESIZED SOLUTION & ARCHIVAL NOTES";

      activePage.graphics.drawString(
        lensTitle,
        sectionFont,
        brush: PdfSolidBrush(primaryColor),
        bounds: Rect.fromLTWH(0, y, pageSize.width, 18),
      );
      y += 20;

      activePage.graphics.drawLine(
        PdfPen(goldColor, width: 1),
        Offset(0, y),
        Offset(pageSize.width, y),
      );
      y += 8;

      final String solutionText = (_lensResult != null && _lensResult!.isNotEmpty)
          ? _lensResult!
          : "Standard Archival Solution: Review foundational theory and apply the pedagogical transformation lenses (Analogy, Feynman, First Principles, or Exam Cheat Sheet) to generate alternative problem-solving perspectives.";

      final PdfTextElement solutionElement = PdfTextElement(
        text: solutionText,
        font: bodyFont,
        brush: PdfSolidBrush(darkColor),
      );
      solutionElement.draw(
        page: activePage,
        bounds: Rect.fromLTWH(0, y, pageSize.width, activePage.getClientSize().height - y),
      );

      final List<int> bytes = await document.save();
      document.dispose();

      final cleanTopic = widget.item.topic.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final fileName = 'Archival_Problem_${cleanTopic}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await saveFile(
        bytes: Uint8List.fromList(bytes),
        fileName: fileName,
        mimeType: 'application/pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Archival PDF folio exported successfully!",
              style: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
            ),
            backgroundColor: DarkAcademiaPalette.forestMoss,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to export PDF: $e"),
            backgroundColor: DarkAcademiaPalette.caputMortuum,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PDF Export Button
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf, size: 16),
              label: Text(
                _isExportingPdf ? "Exporting PDF..." : "Export Archival Folio",
                style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                side: BorderSide(
                  color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.5) : DarkAcademiaPalette.tan,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isExportingPdf ? null : _exportToPdf,
            ),
          ),
          const SizedBox(height: 14),

          // The original PYQ Content
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF23252A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.25)
                    : DarkAcademiaPalette.tan,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: DarkAcademiaPalette.caputMortuum,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: DarkAcademiaPalette.fadedGold, width: 1),
                      ),
                      child: Text(
                        "ARCHIVAL PROBLEM RECORD",
                        style: GoogleFonts.cinzel(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.item.content, 
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16,
                    height: 1.6,
                    color: isDark ? Colors.white : DarkAcademiaPalette.oxfordBrown,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Lens Switcher Toggles
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 18, color: DarkAcademiaPalette.fadedGold),
              const SizedBox(width: 8),
              Text(
                "COGNITIVE PERSPECTIVE LENS",
                style: GoogleFonts.cinzel(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1,
                  color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.oxfordBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _lensButton("analogy", Icons.lightbulb_outline, "Analogy", isDark)),
              const SizedBox(width: 8),
              Expanded(child: _lensButton("visual", Icons.account_tree_outlined, "Visual Logic", isDark)),
              const SizedBox(width: 8),
              Expanded(child: _lensButton("exam", Icons.grading_outlined, "Exam Focus", isDark)),
            ],
          ),
          const SizedBox(height: 24),

          // Lens Result Area
          if (_isLoadingLens)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(color: DarkAcademiaPalette.fadedGold),
              ),
            )
          else if (_lensResult != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? DarkAcademiaPalette.spaceCadet.withValues(alpha: 0.35)
                    : DarkAcademiaPalette.antiqueIvory,
                border: Border.all(color: DarkAcademiaPalette.fadedGold, width: 1.5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: DarkAcademiaPalette.fadedGold, width: 1),
                        ),
                        child: Text(
                          "LENS // ${_activeLens.toUpperCase()} SYNTHESIS",
                          style: GoogleFonts.cinzel(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _lensResult!, 
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 15.5,
                      height: 1.6,
                      color: isDark ? Colors.white : DarkAcademiaPalette.oxfordBrown,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _lensButton(String id, IconData icon, String label, bool isDark) {
    final isSelected = _activeLens == id;
    return InkWell(
      onTap: () => _applyLens(id),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? DarkAcademiaPalette.caputMortuum : DarkAcademiaPalette.spaceCadet)
              : (isDark ? const Color(0xFF23252A) : const Color(0xFFFAF7F0)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? DarkAcademiaPalette.fadedGold
                : (isDark ? DarkAcademiaPalette.slateGray.withValues(alpha: 0.3) : DarkAcademiaPalette.tan.withValues(alpha: 0.6)),
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? DarkAcademiaPalette.fadedGold
                  : (isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.caputMortuum),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cinzel(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : DarkAcademiaPalette.oxfordBrown),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}