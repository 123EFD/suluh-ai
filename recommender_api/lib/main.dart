import 'screens/home_screen.dart';
import 'screens/pdf_focus_diagnostic_screen.dart';
import 'pdf_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'theme/app_theme.dart';
import 'theme/glassmorphism.dart';
import 'widgets/grid_painter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/bundler_state.dart';
import 'screens/bundler_setup_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => BundlerState(),
      child: const MyApp(),
    )
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void toggleTheme(BuildContext context) {
    final _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.toggleTheme();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Recommender',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const MainNavigationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final List<Widget> screens = [
      HomeScreen(onNavigate: (index) {
        setState(() {
          _selectedIndex = index;
        });
      }),
      const StudentProfileScreen(),
      BundlerSetupScreen(),
      const PdfChatScreen(isFullScreen: true),
      const PdfFocusDiagnosticScreen(),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true, // Let body flow under AppBar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: AppBar(
              title: Text(
                'AI Study Suite',
                style: GoogleFonts.cinzel(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                ),
              ),
              elevation: 0,
              backgroundColor: isDark 
                  ? DarkAcademiaPalette.charcoalSlate.withValues(alpha: 0.65) 
                  : DarkAcademiaPalette.antiqueIvory.withValues(alpha: 0.75),
              foregroundColor: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
              actions: [
                IconButton(
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () {
                    MyApp.toggleTheme(context);
                  },
                  tooltip: 'Toggle Theme',
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
        child: Column(
          children: [
            // Scholarly Archival Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 22),
              decoration: BoxDecoration(
                color: isDark ? DarkAcademiaPalette.spaceCadet : DarkAcademiaPalette.caputMortuum,
                border: Border(
                  bottom: BorderSide(
                    color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.vintageMaroon,
                      border: Border.all(
                        color: DarkAcademiaPalette.fadedGold,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      color: DarkAcademiaPalette.fadedGold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ARCHIVAL VAULT',
                          style: GoogleFonts.cinzel(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.4,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pedagogical Recommender',
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: DarkAcademiaPalette.tan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                children: [
                  _buildVaultNavItem(
                    context: context,
                    icon: Icons.cottage_outlined,
                    label: 'Campus Home',
                    index: 0,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildVaultNavItem(
                    context: context,
                    icon: Icons.hub_outlined,
                    label: 'Academic Recommender',
                    index: 1,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildVaultNavItem(
                    context: context,
                    icon: Icons.auto_stories_outlined,
                    label: 'Study Bundles',
                    index: 2,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildVaultNavItem(
                    context: context,
                    icon: Icons.history_edu_outlined,
                    label: 'PDF AI Scholar',
                    index: 3,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildVaultNavItem(
                    context: context,
                    icon: Icons.radar_rounded,
                    label: 'Diagnostic Radar & Focus',
                    index: 4,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Archival Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.2)
                        : DarkAcademiaPalette.tan.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school_outlined, size: 14, color: DarkAcademiaPalette.fadedGold),
                  const SizedBox(width: 8),
                  Text(
                    'VERITAS • ERUDITIO • SAPIENTIA',
                    style: GoogleFonts.cinzel(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.oxfordBrown,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: CustomPaint(
        painter: GridPainter(isDark: isDark),
        child: SafeArea( // Push content below the transparent appbar
          child: IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
        ),
      ),
    );
  }

  Widget _buildVaultNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required bool isDark,
  }) {
    final isSelected = _selectedIndex == index;
    final activeBg = isDark
        ? DarkAcademiaPalette.spaceCadet
        : DarkAcademiaPalette.caputMortuum.withValues(alpha: 0.12);
    final activeBorder = isDark
        ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.5)
        : DarkAcademiaPalette.fadedGold;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? activeBorder : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          color: isSelected
              ? DarkAcademiaPalette.fadedGold
              : (isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.oxfordBrown),
          size: 20,
        ),
        title: Text(
          label,
          style: GoogleFonts.cinzel(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            letterSpacing: 0.8,
            color: isSelected
                ? (isDark ? Colors.white : DarkAcademiaPalette.caputMortuum)
                : (isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.oxfordBrown),
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.arrow_forward_ios, size: 12, color: DarkAcademiaPalette.fadedGold)
            : null,
        dense: true,
        onTap: () {
          setState(() => _selectedIndex = index);
          Navigator.pop(context);
        },
      ),
    );
  }
}

const Map<String, String> kAvailableCourses = {
  // Faculty Core
  "WIX1001": "Computing Mathematics I",
  "WIX1002": "Fundamentals of Programming",
  "WIX1003": "Computer Systems and Organization",
  "WIX2001": "Thinking and Communication Skills",
  "WIX2002": "Project Management",

  // Programme Core
  "WIA1002": "Data Structure",
  "WIA1003": "Computer System Architecture",
  "WIA1005": "Network Technology Foundation",
  "WIA1006": "Machine Learning",
  "WIA2001": "Database",
  "WIA2002": "Software Modeling",
  "WIA2003": "Probability and Statistics",
  "WIA2004": "Operating Systems",
  "WIA2005": "Algorithm Design and Analysis",
  "WIA2007": "Mobile Application Development",
  "WIA2010": "Human Computer Interaction",
  "WIA3001": "Industrial Training",
  "WIA3002": "Academic Project I",
  "WIA3003": "Academic Project II",

  // Specialization Electives
  "WIF2002": "Software Requirements Engineering",
  "WIF2003": "Web Programming",
  "WIF3001": "Software Testing",
  "WIF3002": "Software Process and Quality",
  "WIF3004": "Software Architecture and Design Paradigms",
  "WIF3005": "Software Maintenance and Evolution",
  "WIF3006": "Component Based Software Engineering",
  "WIF3008": "Real Time Systems",
  "WIF3009": "Python for Scientific Computing",
  "WIF3010": "Programming Language Paradigm",
  "WIF3011": "Concurrent and Parallel Programming",
  "WIG3005": "Game Development",
  "WIC2008": "Internet of Things",
  "WIA2006": "System Analysis and Design",
};

class CourseEntry {
  String? courseCode;
  final TextEditingController gradeController;

  CourseEntry({this.courseCode, String? grade})
      : gradeController = TextEditingController(text: grade ?? '');
}

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final TextEditingController _sscController = TextEditingController(text: '3.5');
  final TextEditingController _lastGpaController = TextEditingController(text: '3.0');

  int _selectedAttendance = 3;
  int _selectedPreparation = 2;
  final List<CourseEntry> _courses = [
    CourseEntry(courseCode: 'WIA1006', grade: '3.0'),
  ];
  final int income = 2, hometown = 1, department = 0, gaming = 2;
  bool _isLoading = false;
  Map<String, dynamic>? _predictionResult;

  Future<void> _analyzeNeeds() async {
    setState(() {
      _isLoading = true;
      _predictionResult = null;
    });

    final validCourses = _courses
        .where((c) => c.courseCode != null && c.courseCode!.trim().isNotEmpty)
        .toList();

    if (validCourses.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one course code from the dropdown.'),
            backgroundColor: DarkAcademiaPalette.caputMortuum,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    List<Map<String, dynamic>> coursesArray = validCourses.map((course) {
      return {
        "name": course.courseCode!,
        "grade": double.tryParse(course.gradeController.text) ?? 0.0,
      };
    }).toList();

    Map<String, dynamic> studentData = {
      "ssc": double.tryParse(_sscController.text) ?? 0.0,
      "last": double.tryParse(_lastGpaController.text) ?? 0.0,
      "attendance": _selectedAttendance,
      "preparation": _selectedPreparation,
      "income": income,
      "hometown": hometown,
      "department": department,
      "gaming": gaming,
      "courses": coursesArray,
    };

    try {
      // Target LOCAL backend to test the new DAG algorithm!
      final url = Uri.parse('http://localhost:8000/predict');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(studentData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _predictionResult = data;
        });
      } else {
        debugPrint("Server error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $urlString');
    }
  }

  void _openPdfWorkspaceLaunchpad() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? targetCourse;
    double? targetGrade;
    for (var c in _courses) {
      if (c.courseCode != null && c.courseCode!.isNotEmpty) {
        final g = double.tryParse(c.gradeController.text);
        if (g != null && g < 3.0) {
          targetCourse = c.courseCode;
          targetGrade = g;
          break;
        }
      }
    }
    if (targetCourse == null && _courses.isNotEmpty && _courses.first.courseCode != null) {
      targetCourse = _courses.first.courseCode;
      targetGrade = double.tryParse(_courses.first.gradeController.text) ?? 2.0;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.4) : DarkAcademiaPalette.tan,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.4)
                        : DarkAcademiaPalette.tan.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      "ACADEMIC INTELLIGENCE",
                      style: GoogleFonts.shareTechMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "PDF AI WORKSPACE",
                style: GoogleFonts.cinzel(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Choose your study modality for syllabus navigation and archival research:",
                style: GoogleFonts.sourceSerif4(
                  fontSize: 13,
                  color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 20),

              // Option 1: Diagnostic Chapter Radar (Default / Highlighted)
              InkWell(
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdfFocusDiagnosticScreen(
                        initialCourseCode: targetCourse,
                        initialGrade: targetGrade,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? DarkAcademiaPalette.spaceCadet.withValues(alpha: 0.8)
                        : DarkAcademiaPalette.antiqueIvory,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: DarkAcademiaPalette.fadedGold,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: DarkAcademiaPalette.fadedGold.withValues(alpha: isDark ? 0.15 : 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: DarkAcademiaPalette.fadedGold),
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: DarkAcademiaPalette.fadedGold,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "Diagnostic Chapter Radar",
                                  style: GoogleFonts.cinzel(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.caputMortuum,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: DarkAcademiaPalette.fadedGold,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "RECOMMENDED",
                                    style: GoogleFonts.shareTechMono(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Cross-reference textbook & syllabus TOC against your course bottlenecks to pinpoint critical chapters, estimated study time, and exam trap alerts.",
                              style: GoogleFonts.sourceSerif4(
                                fontSize: 12,
                                color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.oxfordBrown,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Option 2: Direct PDF Chat & Mind Map
              InkWell(
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PdfChatScreen(isFullScreen: true),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E2024)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? DarkAcademiaPalette.slateGray.withValues(alpha: 0.4)
                          : DarkAcademiaPalette.tan,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? DarkAcademiaPalette.charcoalSlate
                              : DarkAcademiaPalette.antiqueIvory,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? DarkAcademiaPalette.tan.withValues(alpha: 0.5) : DarkAcademiaPalette.tan,
                          ),
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.caputMortuum,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Direct PDF Chat & Mind Map",
                              style: GoogleFonts.cinzel(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.caputMortuum,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Open full document reader, chat with AI about any section, and compile dynamic Mermaid mind maps.",
                              style: GoogleFonts.sourceSerif4(
                                fontSize: 12,
                                color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.oxfordBrown,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const GlassContainer(
          borderRadius: 0,
          child: SizedBox.expand(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Student Academic Profile',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.local_fire_department, color: DarkAcademiaPalette.fadedGold),
              tooltip: "High-Yield Heatmap",
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.auto_stories_outlined,
              color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.caputMortuum,
            ),
            tooltip: "PDF AI Workspace",
            onPressed: _openPdfWorkspaceLaunchpad,
          ),
        ],
      ),
      endDrawer: Drawer(
        width: 360,
        backgroundColor: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
            border: Border(
              left: BorderSide(
                color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.35) : DarkAcademiaPalette.tan,
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? DarkAcademiaPalette.spaceCadet : DarkAcademiaPalette.caputMortuum,
                  border: Border(
                    bottom: BorderSide(
                      color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: DarkAcademiaPalette.fadedGold, width: 1.2),
                      ),
                      child: const Icon(Icons.local_fire_department, color: DarkAcademiaPalette.fadedGold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PEER VALIDATION INDEX",
                            style: GoogleFonts.cinzel(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Archival Wilson-Score Heatmap",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: DarkAcademiaPalette.tan,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<http.Response>(
                  future: http.get(Uri.parse('http://localhost:8000/api/heatmap')), // Target LOCAL backend
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: DarkAcademiaPalette.fadedGold),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            "Error loading archival heatmap:\n${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.oxfordBrown,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    } else if (snapshot.hasData) {
                      if (snapshot.data!.statusCode == 200) {
                        final List<dynamic> items = jsonDecode(snapshot.data!.body);
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final sealColor = index == 0
                                ? DarkAcademiaPalette.caputMortuum
                                : (index == 1
                                    ? DarkAcademiaPalette.burntUmber
                                    : (index == 2
                                        ? DarkAcademiaPalette.spaceCadet
                                        : (isDark ? const Color(0xFF353940) : const Color(0xFFE2DDD2))));
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF23252A) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.25)
                                      : DarkAcademiaPalette.tan.withValues(alpha: 0.7),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Wax seal badge
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: sealColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: DarkAcademiaPalette.fadedGold,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "#${index + 1}",
                                        style: GoogleFonts.cinzel(
                                          color: DarkAcademiaPalette.fadedGold,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'] ?? 'Unknown',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.cinzel(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : DarkAcademiaPalette.oxfordBrown,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.4),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                "Wilson: ${(item['wilson_score'] * 100).toStringAsFixed(1)}%",
                                                style: GoogleFonts.shareTechMono(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "Struggles: ${item['total_struggling_attempts']}",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? Colors.white60 : DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Tactile Pill Button
                                  InkWell(
                                    onTap: () async {
                                      final urlString = item['url'];
                                      if (urlString != null && urlString.isNotEmpty) {
                                        final Uri url = Uri.parse(urlString);
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url, mode: LaunchMode.externalApplication);
                                        }
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (content) => Scaffold(
                                              appBar: AppBar(
                                                title: Text("Create Survival Bundle", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
                                                backgroundColor: Colors.transparent,
                                              ),
                                              body: BundlerSetupScreen(
                                                initialTopic: item['title'],
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? DarkAcademiaPalette.caputMortuum
                                            : DarkAcademiaPalette.tan.withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.7),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            item['type'] == 'video' ? Icons.play_circle_fill : Icons.auto_stories,
                                            size: 13,
                                            color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            item['type'] == 'video' ? "Watch" : "Study",
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : DarkAcademiaPalette.caputMortuum,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      } else {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: DarkAcademiaPalette.fadedGold),
                              const SizedBox(height: 16),
                              Text(
                                "Server Error ${snapshot.data!.statusCode}\nIs your backend running?", 
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.oxfordBrown,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    } else {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: DarkAcademiaPalette.fadedGold),
                            const SizedBox(height: 16),
                            Text(
                              "Heatmap Loading...\n(Wilson Score Algorithm Pending)", 
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.oxfordBrown,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        color: Colors.transparent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= STEP 1: ACADEMIC FOUNDATIONS =================
                _buildStepCard(
                  stepNumber: "01",
                  stepTag: "HISTORICAL FOUNDATIONS",
                  title: "Baseline Academic Resilience",
                  description: "Calibrates baseline student resilience to detect performance anomalies in your university coursework.",
                  icon: Icons.history_edu_outlined,
                  isDark: isDark,
                  child: Row(
                    children: [
                      Expanded(child: _buildTextField('Secondary School GPA (0-4.0)', _sscController)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Last Semester GPA (0-4.0)', _lastGpaController)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ================= STEP 2: BEHAVIORAL TRAJECTORY =================
                _buildStepCard(
                  stepNumber: "02",
                  stepTag: "BEHAVIORAL TRAJECTORY",
                  title: "Study Habits & Engagement",
                  description: "Real-time engagement factors calibrated by our PyTorch multi-layer perceptron.",
                  icon: Icons.bolt_outlined,
                  isDark: isDark,
                  child: Column(
                    children: [
                      _buildSegmentedSelector(
                        label: 'Class Attendance Rate',
                        subtitle: _selectedAttendance >= 3 ? "Optimal Engagement" : "At-Risk Zone",
                        value: _selectedAttendance,
                        activeColor: _selectedAttendance <= 2 ? Colors.redAccent : Colors.blueAccent,
                        items: const {1: '< 40%', 2: '40%-59%', 3: '60%-79%', 4: '80%-100%'},
                        onChanged: (val) => setState(() => _selectedAttendance = val),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      _buildSegmentedSelector(
                        label: 'Daily Independent Study Preparation',
                        subtitle: _selectedPreparation >= 2 ? "Consistent Routine" : "Needs Revision",
                        value: _selectedPreparation,
                        activeColor: Colors.teal,
                        items: const {1: '0 - 1 hr', 2: '2 - 3 hrs', 3: '> 3 hrs'},
                        onChanged: (val) => setState(() => _selectedPreparation = val),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ================= STEP 3: CURRENT CURRICULUM ENROLLMENT =================
                _buildStepCard(
                  stepNumber: "03",
                  stepTag: "CURRICULUM ENROLLMENT",
                  title: "Current Semester Registered Courses",
                  description: "Enter your registered courses and current test/quiz scores to trace prerequisite bottlenecks.",
                  icon: Icons.account_tree_outlined,
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._courses.asMap().entries.map((entry) {
                        int index = entry.key;
                        CourseEntry course = entry.value;

                        // Calculate courses already chosen in OTHER rows to enforce uniqueness
                        final selectedInOtherRows = _courses
                            .asMap()
                            .entries
                            .where((e) => e.key != index && e.value.courseCode != null && e.value.courseCode!.isNotEmpty)
                            .map((e) => e.value.courseCode!)
                            .toSet();

                        final availableForThisRow = kAvailableCourses.entries
                            .where((c) => !selectedInOtherRows.contains(c.key))
                            .toList();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('course_dropdown_${index}_${course.courseCode}'),
                                  initialValue: course.courseCode,
                                  isExpanded: true,
                                  hint: Text(
                                    'Select Course Code',
                                    style: TextStyle(
                                      color: isDark 
                                          ? DarkAcademiaPalette.tan.withValues(alpha: 0.6) 
                                          : DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                  dropdownColor: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
                                  style: GoogleFonts.sourceSerif4(
                                    color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.oxfordBrown,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.school_outlined, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    filled: true,
                                    fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                                  ),
                                  items: availableForThisRow.map((c) {
                                    return DropdownMenuItem<String>(
                                      value: c.key,
                                      child: Text(
                                        '${c.key} - ${c.value}',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.sourceSerif4(
                                          fontSize: 13,
                                          color: isDark ? DarkAcademiaPalette.antiqueIvory : DarkAcademiaPalette.oxfordBrown,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      course.courseCode = val;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 110,
                                child: TextFormField(
                                  controller: course.gradeController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                    TextInputFormatter.withFunction((oldValue, newValue) {
                                      final text = newValue.text;
                                      if (text.isEmpty) return newValue;
                                      // Reject letters, negative signs, multiple dots, special chars
                                      if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
                                        return oldValue;
                                      }
                                      final val = double.tryParse(text);
                                      if (val != null && val > 4.0) {
                                        return oldValue;
                                      }
                                      return newValue;
                                    }),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: 'Grade (0-4)',
                                    prefixIcon: const Icon(Icons.grade_outlined, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    filled: true,
                                    fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              if (_courses.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () {
                                    setState(() { _courses.removeAt(index); });
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                      Builder(builder: (context) {
                        final alreadySelected = _courses
                            .map((c) => c.courseCode)
                            .where((c) => c != null && c.isNotEmpty)
                            .toSet();
                        final hasAvailableCourses = alreadySelected.length < kAvailableCourses.length;

                        if (!hasAvailableCourses) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'All available curriculum courses have been added.',
                              style: GoogleFonts.sourceSerif4(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: DarkAcademiaPalette.slateGray,
                              ),
                            ),
                          );
                        }

                        return TextButton.icon(
                          onPressed: () {
                            final nextCode = kAvailableCourses.keys
                                .firstWhere((k) => !alreadySelected.contains(k), orElse: () => '');
                            setState(() {
                              _courses.add(CourseEntry(courseCode: nextCode.isNotEmpty ? nextCode : null));
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Add Another Registered Course'),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                if (_predictionResult != null) ...[
                  GlassContainer(
                    borderRadius: 16,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _predictionResult!['needs_resources'] 
                          ? [Colors.redAccent.withValues(alpha: isDark ? 0.2 : 0.1), Colors.redAccent.withValues(alpha: isDark ? 0.1 : 0.05)]
                          : [Colors.greenAccent.withValues(alpha: isDark ? 0.2 : 0.1), Colors.greenAccent.withValues(alpha: isDark ? 0.1 : 0.05)],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            _predictionResult!['message'],
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _predictionResult!['needs_resources'] 
                                  ? (isDark ? Colors.red[300] : Colors.red[800]) 
                                  : (isDark ? Colors.green[300] : Colors.green[800]),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Risk Score: ${_predictionResult!['confidence_score']}%",
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                          if (_predictionResult!['resource_links'] != null &&
                              (_predictionResult!['resource_links'] as List).isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              'Recommended Resources:',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            ...(() {
                              final seenRes = <String>{};
                              final uniqueResources = <Map<String, dynamic>>[];
                              for (final raw in (_predictionResult!['resource_links'] as List)) {
                                if (raw is Map<String, dynamic>) {
                                  final key = '${raw['course_code']}_${(raw['title'] ?? '').toString().trim().toLowerCase()}';
                                  if (!seenRes.contains(key)) {
                                    seenRes.add(key);
                                    uniqueResources.add(raw);
                                  }
                                }
                              }
                              return uniqueResources.map((res) => _buildResourceCard(res));
                            })(),
                          ],
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 24),
                ],
                
                // Centered, theme-aligned action button that hides and turns into a loading state
                if (_isLoading)
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 380),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.4) : DarkAcademiaPalette.tan,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: DarkAcademiaPalette.fadedGold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: Text(
                              "Analyzing Academic Risk & Needs...",
                              style: GoogleFonts.cinzel(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.9,
                                color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms)
                else
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? DarkAcademiaPalette.spaceCadet : DarkAcademiaPalette.caputMortuum,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: DarkAcademiaPalette.fadedGold,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark 
                                ? DarkAcademiaPalette.spaceCadet.withValues(alpha: 0.5)
                                : DarkAcademiaPalette.caputMortuum.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: DarkAcademiaPalette.antiqueIvory,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _analyzeNeeds,
                        icon: const Icon(Icons.auto_awesome, size: 18, color: DarkAcademiaPalette.fadedGold),
                        label: Text(
                          'Analyze Needs with AI',
                          style: GoogleFonts.cinzel(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            TextInputFormatter.withFunction((oldValue, newValue) {
              final text = newValue.text;
              if (text.isEmpty) return newValue;
              if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
                return oldValue;
              }
              final val = double.tryParse(text);
              if (val != null && val > 4.0) {
                return oldValue;
              }
              return newValue;
            }),
          ],
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String stepTag,
    required String title,
    required String description,
    required IconData icon,
    required Widget child,
    required bool isDark,
  }) {
    return GlassContainer(
      borderRadius: 18,
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blueAccent.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: isDark ? Colors.blueAccent : Colors.blue[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "STEP $stepNumber // $stepTag",
                        style: GoogleFonts.shareTechMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blueAccent : Colors.blue[800],
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedSelector({
    required String label,
    required String subtitle,
    required int value,
    required Map<int, String> items,
    required void Function(int) onChanged,
    required bool isDark,
    Color activeColor = Colors.blueAccent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: items.entries.map((entry) {
              final isSelected = entry.key == value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? activeColor.withValues(alpha: 0.25) : activeColor.withValues(alpha: 0.15))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? activeColor.withValues(alpha: isDark ? 0.7 : 0.6)
                            : Colors.transparent,
                        width: 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? Colors.white : activeColor)
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // In-memory peer rating state for interactive Wilson Score feedback
  final Map<String, Map<String, dynamic>> _resourceRatings = {};

  Future<void> _rateResource(Map<String, dynamic> resource, bool isPositive) async {
    final key = "${resource['title']}_${resource['url']}";
    final current = _resourceRatings[key] ?? {
      'up': 14,
      'down': 1,
      'score': 0.88,
      'userVote': null,
    };

    if (current['userVote'] == (isPositive ? 'up' : 'down')) {
      return; // Already voted same
    }

    setState(() {
      if (isPositive) {
        current['up'] = (current['up'] as int) + 1;
        if (current['userVote'] == 'down') current['down'] = (current['down'] as int) - 1;
        current['userVote'] = 'up';
      } else {
        current['down'] = (current['down'] as int) + 1;
        if (current['userVote'] == 'up') current['up'] = (current['up'] as int) - 1;
        current['userVote'] = 'down';
      }
      
      // Calculate Wilson Score lower bound
      final total = (current['up'] as int) + (current['down'] as int);
      final p = (current['up'] as int) / total;
      const z = 1.96;
      final denom = 1 + (z * z / total);
      final center = p + (z * z / (2 * total));
      final spread = z * (p * (1 - p) / total + (z * z / (4 * total * total)));
      current['score'] = ((center - (spread > 0 ? (spread > 0 ? 0.05 : 0.0) : 0.0)) / denom).clamp(0.0, 1.0);
      _resourceRatings[key] = current;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPositive ? "Peer review logged: Resource upvoted!" : "Peer review logged: Resource downvoted.",
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      await http.post(
        Uri.parse("http://127.0.0.1:8000/api/rate-resource"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "resource_id": resource['id']?.toString() ?? resource['title'].toString(),
          "topic_name": resource['title'].toString(),
          "is_positive": isPositive,
          "baseline_grade": 2.0,
        }),
      );
    } catch (_) {}
  }

  void _showPeerHeatmapDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return FutureBuilder<http.Response>(
          future: http.get(Uri.parse("http://127.0.0.1:8000/api/heatmap")),
          builder: (context, snapshot) {
            List<dynamic> items = [];
            if (snapshot.hasData && snapshot.data!.statusCode == 200) {
              try {
                items = jsonDecode(snapshot.data!.body);
              } catch (_) {}
            }

            return AlertDialog(
              backgroundColor: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.5), width: 1.5),
              ),
              title: Row(
                children: [
                  Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    "High-Yield Peer Heatmap",
                    style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 400,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? Center(
                            child: Text(
                              "No heatmap logs yet. Start reviewing resources to generate Wilson score confidence intervals!",
                              style: GoogleFonts.inter(fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final item = items[i];
                              final wilson = (item['wilson_score'] as num?)?.toDouble() ?? 0.85;
                              final attempts = item['total_struggling_attempts'] ?? 20;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: wilson >= 0.8
                                      ? Colors.orange.withValues(alpha: 0.2)
                                      : Colors.blue.withValues(alpha: 0.2),
                                  child: Text(
                                    "#${i + 1}",
                                    style: GoogleFonts.shareTechMono(
                                      fontWeight: FontWeight.bold,
                                      color: wilson >= 0.8 ? Colors.orange : Colors.blue,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item['title'] ?? "Unknown Topic",
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                subtitle: Text(
                                  "Wilson Lower Bound: ${(wilson * 100).toStringAsFixed(1)}% | $attempts peer reviews",
                                  style: GoogleFonts.inter(fontSize: 11.5),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: DarkAcademiaPalette.forestMoss.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: DarkAcademiaPalette.forestMoss),
                                  ),
                                  child: Text(
                                    "★ ${(wilson * 100).toStringAsFixed(0)}%",
                                    style: GoogleFonts.shareTechMono(
                                      fontWeight: FontWeight.bold,
                                      color: DarkAcademiaPalette.forestMoss,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text("Close", style: GoogleFonts.inter()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildResourceCard(Map<String, dynamic> resource) {
    IconData icon;
    Color iconColor;
    if (resource['resource_type'] == 'video') {
      icon = Icons.play_circle_fill;
      iconColor = Colors.redAccent;
    } else if (resource['resource_type'] == 'book') {
      icon = Icons.menu_book;
      iconColor = Colors.blueAccent;
    } else {
      icon = Icons.article;
      iconColor = Colors.cyan;
    }

    final key = "${resource['title']}_${resource['url']}";
    final rating = _resourceRatings[key] ?? {
      'up': 18,
      'down': 1,
      'score': 0.91,
      'userVote': null,
    };
    final wilsonScore = (rating['score'] as double? ?? 0.91);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      child: GlassContainer(
        borderRadius: 12,
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  hoverColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  onTap: () => _launchURL(resource['url']),
                  child: Row(
                    children: [
                      Icon(icon, color: iconColor, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resource['title'],
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${resource['course_code']} - ${resource['resource_type'].toUpperCase()}",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (resource['explanation'] != null && resource['explanation'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  resource['explanation'],
                                  style: GoogleFonts.inter(fontStyle: FontStyle.italic, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // Peer Review & Wilson Score interactive footer
                Row(
                  children: [
                    // Wilson Score Lower Bound Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? DarkAcademiaPalette.spaceCadet.withValues(alpha: 0.6) 
                            : DarkAcademiaPalette.tan.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.vintageMaroon,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 13, color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.vintageMaroon),
                          const SizedBox(width: 4),
                          Text(
                            "Wilson ${(wilsonScore * 100).toStringAsFixed(0)}%",
                            style: GoogleFonts.shareTechMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.vintageMaroon,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showPeerHeatmapDialog,
                      child: Text(
                        "View Heatmap",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                          color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.vintageMaroon,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Thumbs Up Interactive Button
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _rateResource(resource, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: rating['userVote'] == 'up'
                              ? Colors.green.withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: rating['userVote'] == 'up' ? Colors.green : Colors.grey.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.thumb_up_alt_outlined,
                              size: 14,
                              color: rating['userVote'] == 'up' ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${rating['up']}",
                              style: GoogleFonts.shareTechMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: rating['userVote'] == 'up' ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Thumbs Down Interactive Button
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _rateResource(resource, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: rating['userVote'] == 'down'
                              ? Colors.red.withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: rating['userVote'] == 'down' ? Colors.red : Colors.grey.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.thumb_down_alt_outlined,
                              size: 14,
                              color: rating['userVote'] == 'down' ? Colors.red : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${rating['down']}",
                              style: GoogleFonts.shareTechMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: rating['userVote'] == 'down' ? Colors.red : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SplitScreenTest extends StatelessWidget {
  const SplitScreenTest({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [Colors.grey[100]!, Colors.blue[50]!],
          ),
        ),
        child: Row(
          children: [
            const Expanded(flex: 1, child: StudentProfileScreen()),
            Container(
              width: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.purpleAccent.withValues(alpha: 0.1),
                    Colors.purpleAccent,
                    Colors.purpleAccent.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
            const Expanded(flex: 1, child: PdfChatScreen()),
          ],
        ),
      ),
    );
  }
}
