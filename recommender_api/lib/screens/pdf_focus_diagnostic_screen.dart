import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../models/resource_item.dart';
import '../services/bundler_state.dart';
import '../pdf_chat_screen.dart';
import 'study_session_screen.dart';
import '../main.dart';

class SubchapterFocusModel {
  final String subchapterId;
  final String title;
  final int pageStart;
  final int pageEnd;
  final int estimatedMinutes;
  final List<String> keypoints;
  final String? examWarning;

  SubchapterFocusModel({
    required this.subchapterId,
    required this.title,
    required this.pageStart,
    required this.pageEnd,
    required this.estimatedMinutes,
    required this.keypoints,
    this.examWarning,
  });

  factory SubchapterFocusModel.fromJson(Map<String, dynamic> json) {
    return SubchapterFocusModel(
      subchapterId: (json['subchapter_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      pageStart: json['page_start'] is int
          ? json['page_start']
          : int.tryParse(json['page_start'].toString()) ?? 1,
      pageEnd: json['page_end'] is int
          ? json['page_end']
          : int.tryParse(json['page_end'].toString()) ?? 1,
      estimatedMinutes: json['estimated_minutes'] is int
          ? json['estimated_minutes']
          : int.tryParse(json['estimated_minutes'].toString()) ?? 25,
      keypoints: (json['keypoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      examWarning: json['exam_warning']?.toString(),
    );
  }
}

class ChapterFocusModel {
  final int chapterNumber;
  final String chapterTitle;
  final String pageRange;
  final String priority; // "CRITICAL", "HIGH_YIELD", "FOUNDATIONAL"
  final String relevanceRationale;
  final List<SubchapterFocusModel> subchapters;

  ChapterFocusModel({
    required this.chapterNumber,
    required this.chapterTitle,
    required this.pageRange,
    required this.priority,
    required this.relevanceRationale,
    required this.subchapters,
  });

  factory ChapterFocusModel.fromJson(Map<String, dynamic> json) {
    return ChapterFocusModel(
      chapterNumber: json['chapter_number'] is int
          ? json['chapter_number']
          : int.tryParse(json['chapter_number'].toString()) ?? 1,
      chapterTitle: (json['chapter_title'] ?? '').toString(),
      pageRange: (json['page_range'] ?? '').toString(),
      priority: (json['priority'] ?? 'HIGH_YIELD').toString().toUpperCase(),
      relevanceRationale: (json['relevance_rationale'] ?? '').toString(),
      subchapters: (json['subchapters'] as List<dynamic>?)
              ?.map((e) => SubchapterFocusModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class FocusAnalysisResult {
  final String courseCode;
  final String courseName;
  final String filename;
  final double totalEstimatedStudyHours;
  final List<ChapterFocusModel> recommendedChapters;

  FocusAnalysisResult({
    required this.courseCode,
    required this.courseName,
    required this.filename,
    required this.totalEstimatedStudyHours,
    required this.recommendedChapters,
  });

  factory FocusAnalysisResult.fromJson(Map<String, dynamic> json) {
    return FocusAnalysisResult(
      courseCode: (json['course_code'] ?? '').toString(),
      courseName: (json['course_name'] ?? '').toString(),
      filename: (json['filename'] ?? '').toString(),
      totalEstimatedStudyHours: (json['total_estimated_study_hours'] is num)
          ? (json['total_estimated_study_hours'] as num).toDouble()
          : 2.0,
      recommendedChapters: (json['recommended_chapters'] as List<dynamic>?)
              ?.map((e) => ChapterFocusModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PdfFocusDiagnosticScreen extends StatefulWidget {
  final String? initialCourseCode;
  final double? initialGrade;
  final String? initialPdfName;

  const PdfFocusDiagnosticScreen({
    super.key,
    this.initialCourseCode,
    this.initialGrade,
    this.initialPdfName,
  });

  @override
  State<PdfFocusDiagnosticScreen> createState() => _PdfFocusDiagnosticScreenState();
}

class _PdfFocusDiagnosticScreenState extends State<PdfFocusDiagnosticScreen> {
  final String _baseUrl = "http://localhost:8000";

  late String _selectedCourseCode;
  late TextEditingController _gradeController;
  String? _selectedPdf;
  List<String> _libraryPdfs = [];

  bool _isLoadingLibrary = false;
  bool _isUploadingPdf = false;
  bool _isResolvingPdf = false;
  String? _generatingFlashcardSubId;
  final Map<String, double> _bktMasteryMap = {};
  final Map<String, double> _bktPredNextMap = {};
  bool _isAnalyzing = false;
  String? _errorMessage;

  FocusAnalysisResult? _analysisResult;

  @override
  void initState() {
    super.initState();
    _selectedCourseCode = (widget.initialCourseCode != null &&
            kAvailableCourses.containsKey(widget.initialCourseCode))
        ? widget.initialCourseCode!
        : (kAvailableCourses.containsKey('WIA1006')
            ? 'WIA1006'
            : kAvailableCourses.keys.first);

    _gradeController = TextEditingController(
      text: widget.initialGrade != null ? widget.initialGrade.toString() : '2.0',
    );

    _selectedPdf = widget.initialPdfName;
    _fetchLibrary().then((_) {
      if (_selectedPdf == null) {
        _resolveCoursePdf(_selectedCourseCode);
      }
    });
  }

  @override
  void dispose() {
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _fetchLibrary() async {
    setState(() => _isLoadingLibrary = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/library'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final list = List<String>.from(data);
        setState(() {
          _libraryPdfs = list;
          if (_selectedPdf == null && list.isNotEmpty) {
            _selectedPdf = list.first;
          } else if (_selectedPdf != null && !list.contains(_selectedPdf)) {
            _selectedPdf = list.isNotEmpty ? list.first : null;
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch library: $e");
    } finally {
      setState(() => _isLoadingLibrary = false);
    }
  }

  Future<void> _resolveCoursePdf(String courseCode) async {
    setState(() => _isResolvingPdf = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/resolve-course-pdf'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'course_code': courseCode}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String resolvedFile = data['filename'] ?? '';
        if (resolvedFile.isNotEmpty) {
          await _fetchLibrary();
          setState(() {
            _selectedPdf = resolvedFile;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Resolved curriculum textbook: "$resolvedFile" (${data['source']})'),
                backgroundColor: DarkAcademiaPalette.forestMoss,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error resolving course PDF: $e");
    } finally {
      if (mounted) {
        setState(() => _isResolvingPdf = false);
      }
    }
  }

  Future<void> _uploadPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        if (file.bytes == null) return;

        setState(() => _isUploadingPdf = true);

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/upload-pdf'),
        );
        request.files.add(
          http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
        );

        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final uploadedName = data['filename'] ?? file.name;
          await _fetchLibrary();
          setState(() {
            _selectedPdf = uploadedName;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Document "$uploadedName" uploaded and selected.'),
                backgroundColor: DarkAcademiaPalette.forestMoss,
              ),
            );
          }
        } else {
          throw Exception("Upload failed with status ${response.statusCode}");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: DarkAcademiaPalette.caputMortuum,
          ),
        );
      }
    } finally {
      setState(() => _isUploadingPdf = false);
    }
  }

  Future<void> _runDiagnosticAnalysis() async {
    if (_selectedPdf == null || _selectedPdf!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or upload a syllabus/textbook PDF first.'),
          backgroundColor: DarkAcademiaPalette.caputMortuum,
        ),
      );
      return;
    }

    final grade = double.tryParse(_gradeController.text.trim()) ?? 2.0;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _analysisResult = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/analyze-pdf-focus'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'course_code': _selectedCourseCode,
          'course_grade': grade,
          'filename': _selectedPdf,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _analysisResult = FocusAnalysisResult.fromJson(data);
        });
      } else {
        setState(() {
          _errorMessage = "Analysis error (${response.statusCode}): ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error: $e";
      });
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _deepDiveInChat(SubchapterFocusModel sub) {
    if (_selectedPdf == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfChatScreen(
          isFullScreen: true,
          initialPdfName: _selectedPdf!,
          initialPage: sub.pageStart,
          initialPrompt:
              "Please explain the core concepts of '${sub.title}' (pages ${sub.pageStart}-${sub.pageEnd}) in detail. Highlight formulas, principles, and common university exam questions.",
        ),
      ),
    );
  }

  void _openBktMasterySheet(SubchapterFocusModel sub) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double currentMastery = _bktMasteryMap[sub.subchapterId] ?? 0.35;
    double currentPred = _bktPredNextMap[sub.subchapterId] ?? 0.42;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isMastered = currentMastery >= 0.85;
            final badgeLabel = isMastered
                ? "MASTERED (>= 85%)"
                : (currentMastery >= 0.60 ? "DEVELOPING / PROFICIENT" : "NOVICE / LEARNING");
            final badgeColor = isMastered
                ? DarkAcademiaPalette.forestMoss
                : (currentMastery >= 0.60 ? Colors.blue : DarkAcademiaPalette.caputMortuum);

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(
                  color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.4) : DarkAcademiaPalette.tan,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          sub.title,
                          style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor),
                        ),
                        child: Text(
                          badgeLabel,
                          style: GoogleFonts.shareTechMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Bayesian Knowledge Tracing (BKT) dynamically tracks your latent concept mastery P(L) using transition, guess, and slip probabilities.",
                    style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  // Animated Mastery Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Concept Mastery: ${(currentMastery * 100).toStringAsFixed(1)}%",
                        style: GoogleFonts.shareTechMono(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "P(Correct Next): ${(currentPred * 100).toStringAsFixed(1)}%",
                        style: GoogleFonts.shareTechMono(fontSize: 12, color: Colors.blueAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: currentMastery.clamp(0.0, 1.0),
                      minHeight: 12,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text(
                    "Interactive Self-Assessment:",
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Did you understand and correctly recall the key formulas and principles for this chapter?",
                    style: GoogleFonts.inter(fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final resp = await http.post(
                                Uri.parse("$_baseUrl/api/bkt/update"),
                                headers: {"Content-Type": "application/json"},
                                body: jsonEncode({
                                  "prior_mastery": currentMastery,
                                  "is_correct": true,
                                  "p_transit": 0.15,
                                  "p_guess": 0.20,
                                  "p_slip": 0.10,
                                }),
                              );
                              if (resp.statusCode == 200) {
                                final data = jsonDecode(resp.body);
                                final newM = (data['updated_mastery'] as num).toDouble();
                                final newP = (data['predicted_next_correct'] as num).toDouble();
                                _bktMasteryMap[sub.subchapterId] = newM;
                                _bktPredNextMap[sub.subchapterId] = newP;
                                setModalState(() {
                                  currentMastery = newM;
                                  currentPred = newP;
                                });
                                setState(() {});
                              }
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: Text("I Mastered This (Correct)", style: GoogleFonts.shareTechMono(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DarkAcademiaPalette.forestMoss,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final resp = await http.post(
                                Uri.parse("$_baseUrl/api/bkt/update"),
                                headers: {"Content-Type": "application/json"},
                                body: jsonEncode({
                                  "prior_mastery": currentMastery,
                                  "is_correct": false,
                                  "p_transit": 0.15,
                                  "p_guess": 0.20,
                                  "p_slip": 0.10,
                                }),
                              );
                              if (resp.statusCode == 200) {
                                final data = jsonDecode(resp.body);
                                final newM = (data['updated_mastery'] as num).toDouble();
                                final newP = (data['predicted_next_correct'] as num).toDouble();
                                _bktMasteryMap[sub.subchapterId] = newM;
                                _bktPredNextMap[sub.subchapterId] = newP;
                                setModalState(() {
                                  currentMastery = newM;
                                  currentPred = newP;
                                });
                                setState(() {});
                              }
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text("Need Practice (Review)", style: GoogleFonts.shareTechMono(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DarkAcademiaPalette.caputMortuum,
                            side: const BorderSide(color: DarkAcademiaPalette.caputMortuum),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _makeFlashcards(SubchapterFocusModel sub) async {
    setState(() {
      _generatingFlashcardSubId = sub.subchapterId;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/generate-subchapter-flashcards'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'course_code': _selectedCourseCode,
          'subchapter_title': sub.title,
          'page_start': sub.pageStart,
          'page_end': sub.pageEnd,
          'filename': _selectedPdf ?? '',
          'keypoints': sub.keypoints,
          'exam_warning': sub.examWarning,
        }),
      );
      
      final List<ResourceItem> newCards = [];
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (var item in data) {
          newCards.add(ResourceItem(
            resourceId: item['resource_id'] ?? 'fc_${sub.subchapterId}_${DateTime.now().millisecondsSinceEpoch}',
            topic: item['topic'] ?? sub.title,
            durationMin: item['duration_min'] ?? 5,
            type: 'flashcard',
            content: item['content'] ?? '',
          ));
        }
      }

      // Query targeted video lecture strictly relevant to this course and subchapter
      try {
        final vidResp = await http.post(
          Uri.parse('$_baseUrl/api/resolve-subchapter-video'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'course_code': _selectedCourseCode,
            'subchapter_title': sub.title,
          }),
        );
        if (vidResp.statusCode == 200 && vidResp.body.isNotEmpty && vidResp.body != 'null') {
          final dynamic vidData = jsonDecode(vidResp.body);
          if (vidData != null && vidData is Map && vidData['url'] != null) {
            newCards.add(ResourceItem(
              resourceId: vidData['video_id'] ?? 'vid_${DateTime.now().millisecondsSinceEpoch}',
              topic: vidData['title'] ?? sub.title,
              durationMin: vidData['duration_min'] ?? 15,
              type: 'video',
              content: vidData['url'],
            ));
          }
        }
      } catch (vidErr) {
        debugPrint('Error fetching relevant video for subchapter: $vidErr');
      }

      if (newCards.isNotEmpty && mounted) {
        // Set clean, dedicated bundle for this subchapter to avoid carrying over stale videos from other courses
        context.read<BundlerState>().setDirectBundle(newCards);
        final cardCount = newCards.where((c) => c.type == 'flashcard').length;
        final hasVideo = newCards.any((c) => c.type == 'video');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasVideo
                  ? 'Synthesized $cardCount exam flashcards + 1 verified video lecture for "${sub.title}"!'
                  : 'Synthesized $cardCount deep exam flashcards for "${sub.title}"!',
            ),
            backgroundColor: DarkAcademiaPalette.forestMoss,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Open Deck',
              textColor: DarkAcademiaPalette.fadedGold,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudySessionScreen()),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate flashcards: $e'),
            backgroundColor: DarkAcademiaPalette.caputMortuum,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _generatingFlashcardSubId = null;
        });
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return DarkAcademiaPalette.caputMortuum;
      case 'HIGH_YIELD':
        return DarkAcademiaPalette.burntUmber;
      case 'FOUNDATIONAL':
      default:
        return DarkAcademiaPalette.forestMoss;
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return 'CRITICAL GAP';
      case 'HIGH_YIELD':
        return 'HIGH-YIELD EXAM';
      case 'FOUNDATIONAL':
      default:
        return 'FOUNDATIONAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory;
    final cardBg = isDark ? const Color(0xFF1E2024) : Colors.white;
    final textColor = isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.oxfordBrown;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1D1F) : DarkAcademiaPalette.antiqueIvory,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Diagnostic Chapter Radar",
              style: GoogleFonts.cinzel(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              "Curriculum & Prerequisite Syllabus Navigator",
              style: GoogleFonts.shareTechMono(
                fontSize: 11,
                color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.slateGray,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
            ),
            tooltip: isDark ? "Switch to Daylight Folio" : "Switch to Midnight Archive",
            onPressed: () => MyApp.toggleTheme(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildConfigurationPanel(isDark, cardBg, textColor),
            const SizedBox(height: 24),
            if (_isAnalyzing) _buildLoadingRadar(isDark),
            if (_errorMessage != null) _buildErrorCard(isDark),
            if (_analysisResult != null && !_isAnalyzing)
              _buildAnalysisResults(isDark, cardBg, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationPanel(bool isDark, Color cardBg, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.3) : DarkAcademiaPalette.tan,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.radar_rounded,
                color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                "Syllabus Diagnostic Parameters",
                style: GoogleFonts.cinzel(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 0.8),
          const SizedBox(height: 16),

          // Course Code Selector
          Text(
            "Registered Course & Exam Scope",
            style: GoogleFonts.sourceSerif4(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.25) : DarkAcademiaPalette.tan,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCourseCode,
                isExpanded: true,
                dropdownColor: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
                items: kAvailableCourses.entries.map((e) {
                  return DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(
                      "${e.key} - ${e.value}",
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 14,
                        color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.oxfordBrown,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCourseCode = val);
                    _resolveCoursePdf(val);
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Grade Input & PDF Document Selector Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Grade
              SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Current Grade",
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _gradeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.shareTechMono(
                        fontSize: 14,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: "e.g. 2.0",
                        filled: true,
                        fillColor: isDark
                            ? DarkAcademiaPalette.charcoalSlate
                            : DarkAcademiaPalette.antiqueIvory.withValues(alpha: 0.4),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.25) : DarkAcademiaPalette.tan,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.25) : DarkAcademiaPalette.tan,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: DarkAcademiaPalette.fadedGold,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // PDF Document from Library
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Textbook / Syllabus PDF",
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        if (_isLoadingLibrary || _isResolvingPdf)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isResolvingPdf ? "Resolving textbook... " : "",
                                style: GoogleFonts.cinzel(
                                  fontSize: 10,
                                  color: DarkAcademiaPalette.fadedGold,
                                ),
                              ),
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: DarkAcademiaPalette.fadedGold,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? DarkAcademiaPalette.charcoalSlate
                            : DarkAcademiaPalette.antiqueIvory.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.25) : DarkAcademiaPalette.tan,
                        ),
                      ),
                      child: _libraryPdfs.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                _isLoadingLibrary ? "Loading library..." : "No PDFs found in library. Upload one below!",
                                style: GoogleFonts.sourceSerif4(
                                  fontSize: 12,
                                  color: DarkAcademiaPalette.slateGray,
                                ),
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: (_selectedPdf != null && _libraryPdfs.contains(_selectedPdf))
                                    ? _selectedPdf
                                    : (_libraryPdfs.isNotEmpty ? _libraryPdfs.first : null),
                                isExpanded: true,
                                dropdownColor: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
                                items: _libraryPdfs.map((pdf) {
                                  return DropdownMenuItem<String>(
                                    value: pdf,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.picture_as_pdf_outlined,
                                          size: 16,
                                          color: DarkAcademiaPalette.fadedGold,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            pdf,
                                            style: GoogleFonts.sourceSerif4(
                                              fontSize: 13,
                                              color: isDark
                                                  ? DarkAcademiaPalette.antiqueIvory
                                                  : DarkAcademiaPalette.oxfordBrown,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedPdf = val);
                                  }
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Upload button & Refresh Row
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isUploadingPdf ? null : _uploadPdfFile,
                icon: _isUploadingPdf
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: DarkAcademiaPalette.fadedGold,
                        ),
                      )
                    : const Icon(Icons.upload_file_outlined, size: 16),
                label: Text(
                  _isUploadingPdf ? "Uploading..." : "Upload New PDF",
                  style: GoogleFonts.shareTechMono(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.oxfordBrown,
                  side: BorderSide(
                    color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.5) : DarkAcademiaPalette.tan,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: "Refresh Document Library",
                color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.slateGray,
                onPressed: _fetchLibrary,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Main Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_isAnalyzing || _selectedPdf == null) ? null : _runDiagnosticAnalysis,
              icon: const Icon(Icons.track_changes_rounded, size: 20),
              label: Text(
                _isAnalyzing ? "Analyzing Syllabus Structure..." : "Analyze Syllabus Focus",
                style: GoogleFonts.cinzel(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: DarkAcademiaPalette.spaceCadet,
                foregroundColor: DarkAcademiaPalette.antiqueIvory,
                disabledBackgroundColor: DarkAcademiaPalette.slateGray.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(
                    color: DarkAcademiaPalette.fadedGold,
                    width: 1.5,
                  ),
                ),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingRadar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2024) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: DarkAcademiaPalette.fadedGold,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Extracting Document Structure & Table of Contents...",
            style: GoogleFonts.cinzel(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Cross-referencing prerequisite DAG bottlenecks with Groq Diagnostic Engine...",
            style: GoogleFonts.sourceSerif4(
              fontSize: 13,
              color: DarkAcademiaPalette.slateGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DarkAcademiaPalette.caputMortuum.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DarkAcademiaPalette.caputMortuum, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: DarkAcademiaPalette.caputMortuum),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? "An unexpected diagnostic failure occurred.",
              style: GoogleFonts.sourceSerif4(
                color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.caputMortuum,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResults(bool isDark, Color cardBg, Color textColor) {
    final result = _analysisResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? DarkAcademiaPalette.spaceCadet : DarkAcademiaPalette.oxfordBrown,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DarkAcademiaPalette.fadedGold,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.courseName.toUpperCase(),
                          style: GoogleFonts.cinzel(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: DarkAcademiaPalette.antiqueIvory,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          "Curriculum Code: ${result.courseCode}  •  Asset: ${result.filename}",
                          style: GoogleFonts.shareTechMono(
                            fontSize: 12,
                            color: DarkAcademiaPalette.tan,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: DarkAcademiaPalette.fadedGold),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: DarkAcademiaPalette.fadedGold),
                        const SizedBox(width: 6),
                        Text(
                          "⏱️ ${result.totalEstimatedStudyHours} Hours Total Study Time",
                          style: GoogleFonts.shareTechMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: DarkAcademiaPalette.antiqueIvory,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: DarkAcademiaPalette.tan.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_stories_outlined, size: 16, color: DarkAcademiaPalette.tan),
                        const SizedBox(width: 6),
                        Text(
                          "${result.recommendedChapters.length} Prioritized Chapters",
                          style: GoogleFonts.shareTechMono(
                            fontSize: 12,
                            color: DarkAcademiaPalette.tan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          "PRIORITIZED CHAPTER BREAKDOWN",
          style: GoogleFonts.cinzel(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
          ),
        ),
        const SizedBox(height: 12),

        ...result.recommendedChapters.map((chapter) => _buildChapterCard(chapter, isDark, cardBg, textColor)),
      ],
    );
  }

  Widget _buildChapterCard(
    ChapterFocusModel chapter,
    bool isDark,
    Color cardBg,
    Color textColor,
  ) {
    final priorityColor = _getPriorityColor(chapter.priority);
    final priorityLabel = _getPriorityLabel(chapter.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: priorityColor.withValues(alpha: isDark ? 0.7 : 0.5),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.oxfordBrown,
          collapsedIconColor: DarkAcademiaPalette.slateGray,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priorityLabel,
                  style: GoogleFonts.shareTechMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: DarkAcademiaPalette.antiqueIvory,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.3) : DarkAcademiaPalette.tan,
                  ),
                ),
                child: Text(
                  "pp. ${chapter.pageRange}",
                  style: GoogleFonts.shareTechMono(
                    fontSize: 11,
                    color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Chapter ${chapter.chapterNumber}: ${chapter.chapterTitle}",
                  style: GoogleFonts.cinzel(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.oxfordBrown,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  chapter.relevanceRationale,
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.slateGray,
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 16, thickness: 0.8),
            ...chapter.subchapters.map((sub) => _buildSubchapterItem(sub, isDark, textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubchapterItem(
    SubchapterFocusModel sub,
    bool isDark,
    Color textColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? DarkAcademiaPalette.charcoalSlate.withValues(alpha: 0.7)
            : DarkAcademiaPalette.antiqueIvory.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.15) : DarkAcademiaPalette.tan.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subchapter Header & Timing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${sub.subchapterId} ${sub.title}",
                  style: GoogleFonts.cinzel(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black38 : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  "pp. ${sub.pageStart}–${sub.pageEnd} • ${sub.estimatedMinutes}m",
                  style: GoogleFonts.shareTechMono(
                    fontSize: 11,
                    color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.oxfordBrown,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Keypoints Bullets
          ...sub.keypoints.map(
            (kp) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "• ",
                    style: TextStyle(
                      color: DarkAcademiaPalette.fadedGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      kp,
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 13,
                        color: textColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Exam Pitfall Warning Callout
          if (sub.examWarning != null && sub.examWarning!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: DarkAcademiaPalette.burntUmber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: DarkAcademiaPalette.burntUmber.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: DarkAcademiaPalette.burntUmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sub.examWarning!,
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.burntUmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action Buttons: Deep Dive in Chat & Make Flashcards
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openBktMasterySheet(sub),
              icon: const Icon(Icons.psychology_outlined, size: 16),
              label: Text(
                "Adaptive Mastery Check (BKT) - ${((_bktMasteryMap[sub.subchapterId] ?? 0.35) * 100).toStringAsFixed(0)}% Mastered",
                style: GoogleFonts.shareTechMono(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? DarkAcademiaPalette.spaceCadet : DarkAcademiaPalette.vintageMaroon,
                foregroundColor: Colors.white,
                side: const BorderSide(color: DarkAcademiaPalette.fadedGold, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deepDiveInChat(sub),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                  label: Text(
                    "Deep Dive in Chat",
                    style: GoogleFonts.shareTechMono(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.oxfordBrown,
                    side: BorderSide(
                      color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.5) : DarkAcademiaPalette.tan,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Builder(
                builder: (context) {
                  final isGenerating = _generatingFlashcardSubId == sub.subchapterId;
                  return Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isGenerating ? null : () => _makeFlashcards(sub),
                      icon: isGenerating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DarkAcademiaPalette.antiqueIvory,
                              ),
                            )
                          : const Icon(Icons.style_outlined, size: 15),
                      label: Text(
                        isGenerating ? "Synthesizing..." : "Make Flashcards",
                        style: GoogleFonts.shareTechMono(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DarkAcademiaPalette.forestMoss,
                        foregroundColor: DarkAcademiaPalette.antiqueIvory,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
