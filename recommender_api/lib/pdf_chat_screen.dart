import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/glassmorphism.dart';
import 'theme/app_theme.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class CustomLatexElementBuilder extends MarkdownElementBuilder {
  final TextStyle? textStyle;
  final double? textScaleFactor;

  CustomLatexElementBuilder({this.textStyle, this.textScaleFactor});

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    String text = element.textContent.trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    // Strip unescaped or nested dollar signs from inside the math string to avoid:
    // "Parser Error: Can't use function '$' in math mode"
    if (text.startsWith(r'$') && text.endsWith(r'$') && text.length > 2) {
      text = text.substring(1, text.length - 1).trim();
    }
    text = text.replaceAll(r'$', '');

    MathStyle mathStyle = MathStyle.text;
    if (element.attributes['MathStyle'] == 'display') {
      mathStyle = MathStyle.display;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.antiAlias,
      child: Math.tex(
        text,
        textStyle: textStyle,
        mathStyle: mathStyle,
        textScaleFactor: textScaleFactor,
        onErrorFallback: (err) {
          return Text(
            element.textContent,
            style: (textStyle ?? const TextStyle()).copyWith(
              fontStyle: FontStyle.italic,
              fontFamily: 'serif',
            ),
          );
        },
      ),
    );
  }
}

class AcademicBlockquoteBuilder extends MarkdownElementBuilder {
  final bool isDark;
  AcademicBlockquoteBuilder({required this.isDark});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final rawText = element.textContent;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD2E3FC), // Distinct light blue container
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(
            color: Color(0xFF1967D2), // Dark academic royal blue indicator
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: MarkdownBody(
        data: rawText,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            color: Color(0xFF111111), // High-contrast jet black text
            fontFamily: 'serif',
            fontSize: 14.5,
            height: 1.5,
          ),
          strong: const TextStyle(
            color: Color(0xFF000000), // Solid black bold text
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
          ),
          listBullet: const TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.bold,
          ),
          h1: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
          h2: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
          h3: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class PdfChatScreen extends StatefulWidget {
  final bool isFullScreen;
  final String? initialPdfName;
  final int? initialPage;
  final String? initialPrompt;

  const PdfChatScreen({
    super.key,
    this.isFullScreen = false,
    this.initialPdfName,
    this.initialPage,
    this.initialPrompt,
  });

  @override
  State<PdfChatScreen> createState() => _PdfChatScreenState();
}

class _PdfChatScreenState extends State<PdfChatScreen> with TickerProviderStateMixin {
  List<String> _pdfLibrary = [];
  final String _baseUrl = "http://localhost:8000"; // Test local backend

  Uint8List? _pdfBytes;
  String _pdfName = "";
  bool _isProcessingPdf = false;

  final TextEditingController _chatController = TextEditingController();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isAiThinking = false;

  List<Map<String, String>> _currentActiveChat = [];

  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnimation;
  bool _isSidebarOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchLibrary();
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeOutCubic,
    );

    if (widget.initialPdfName != null && widget.initialPdfName!.isNotEmpty) {
      _loadChatForFile(widget.initialPdfName!);
    }
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _chatController.text = widget.initialPrompt!;
    }
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    _chatController.dispose();
    _pdfViewerController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _fetchLibrary(); // refresh library when opened
        _sidebarController.forward();
      } else {
        _sidebarController.reverse();
      }
    });
  }

  Future<void> _loadChatForFile(String filename) async {
    setState(() {
      _pdfName = filename;
      _pdfBytes = null; // Clear previous bytes so it fetches from network
      _currentActiveChat = [];
    });

    try {
      final response = await http.get(Uri.parse('$_baseUrl/get-chat/$filename'));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _currentActiveChat = data.map((item) => {
            "role": item['role'].toString(),
            "text": item['text'].toString()
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Failed to load chat for $filename: $e");
    }
  }

  Future<bool> _waitForProcessing(String filename) async {
    bool isDone = false;
    bool success = false;

    while (!isDone) {
      await Future.delayed(const Duration(seconds: 2));

      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/job-status/${Uri.encodeComponent(filename)}')
        );

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);

          if (data['status'] == 'completed') {
            isDone = true;
            success = true;
          } else if (data['status'] == 'failed') {
            isDone = true;
            success = false;
          }
        }
      } catch (e) {
        debugPrint("Error waiting for processing: $e");
      }
    }
    return success;
  }

  Future<void> _saveMessage(String role, String text) async {
    setState(() {
      _currentActiveChat.add({"role": role, "text": text});
    });

    try {
      await http.post(
        Uri.parse('$_baseUrl/save-message'),
        headers: { 'Content-type' : 'application/json' },
        body: jsonEncode({
          "filename": _pdfName,
          "role": role,
          "text": text,
        }),
      );
    } catch (e) {
      debugPrint("Failed to save message: $e");
    }
  }

  Future<void> _fetchLibrary() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/library'));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        debugPrint("FLUTTER RECEIVED THIS LIBRARY DATA: $data");

        setState(() {
          _pdfLibrary = List<String>.from(data);
        });
      }
    } catch (e) {
      debugPrint("Library Fetch Error: $e");
    }
  }

  Future<void> _pickAndUploadPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null) {
      setState(() {
        _pdfBytes = result.files.single.bytes;
        _pdfName = result.files.single.name;
        _isProcessingPdf = true;
      });

      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/upload-pdf'),
        );
        request.files.add(
          http.MultipartFile.fromBytes('file', _pdfBytes!, filename: _pdfName),
        );

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);

          setState(() {
            _pdfName = data['filename'];
            if (!_pdfLibrary.contains(_pdfName)) {
              _pdfLibrary.insert(0, _pdfName);
            }

            _currentActiveChat = [
              {"role": "ai", "text": "⏳ AI is reading and memorizing this document. Please wait..."}
            ];
          });

          bool success = await _waitForProcessing(data['filename']);
          await _loadChatForFile(data['filename']);

          if (_currentActiveChat.isEmpty) {
            if (success) {
              _saveMessage(
                "ai",
                "✅ Successfully loaded the document. What would you like to know?",
              );
            } else {
              _saveMessage(
                "ai",
                "❌ The AI failed to extract text or vectorize this document. Please check the backend worker logs.",
              );
            }
          }
        }
      } catch (e) {
        _saveMessage("ai", "❌ Upload failed: $e");
      } finally {
        setState(() => _isProcessingPdf = false);
      }
    }
  }

  String _sanitizeMarkdown(String raw) {
    if (raw.isEmpty) return raw;

    // 1. Prevent collision with flutter_markdown_latex's '( ' and ' )' delimiters
    // Whenever math is inside parentheses like "( $math$ )", remove whitespace around $
    String sanitized = raw.replaceAllMapped(
      RegExp(r'\(\s+\$'),
      (m) => '(\$',
    ).replaceAllMapped(
      RegExp(r'\$\s+\)'),
      (m) => '\$)',
    );

    // Also handle brackets "[ $" and "$ ]"
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\[\s+\$'),
      (m) => '[\$',
    ).replaceAllMapped(
      RegExp(r'\$\s+\]'),
      (m) => '\$]',
    );

    // 2. Clean nested $ inside display math $$...$$
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\$\$(.*?)\$\$', dotAll: true),
      (match) {
        String inner = match.group(1) ?? '';
        String cleanedInner = inner.replaceAll(r'$', '');
        return '\$\$$cleanedInner\$\$';
      },
    );

    final lines = sanitized.split('\n');
    final sanitizedLines = <String>[];
    bool inTable = false;

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      final trimmed = line.trim();

      // Check if line is part of a markdown table
      final isTableLine = trimmed.startsWith('|') || (trimmed.contains('|') && trimmed.endsWith('|'));
      if (isTableLine) {
        inTable = true;
        // In GFM tables, multiline code fences inside table cells break parsing.
        // Replace triple backticks within table rows with inline backticks.
        if (line.contains('```')) {
          line = line.replaceAll('```', '`');
        }
      } else {
        if (inTable && !trimmed.contains('|')) {
          inTable = false;
        }
      }
      sanitizedLines.add(line);
    }

    String result = sanitizedLines.join('\n');

    // Balance unclosed triple code fences if response was streaming/interrupted
    final fenceCount = RegExp(r'```').allMatches(result).length;
    if (fenceCount % 2 != 0) {
      result += '\n```';
    }

    return result;
  }

  Future<void> _sendMessage() async {
    String question = _chatController.text.trim();
    if (question.isEmpty || _pdfName.isEmpty) return;

    _saveMessage("user", question);

    setState(() {
      _chatController.clear();
      _isAiThinking = true;
      _currentActiveChat.add({"role" : "ai", "text":""});
    });

    try {
      var request = http.Request('POST', Uri.parse('$_baseUrl/chat'));
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.headers['accept'] = 'text/event-stream';
      request.body = jsonEncode({"question": question, "filename": _pdfName}); 

      var response = await http.Client().send(request);

      if (response.statusCode == 200) {
        setState(() => _isAiThinking = false);

        await for (var chunk in response.stream.transform(utf8.decoder)) {
          setState(() {
            _currentActiveChat.last["text"] = _currentActiveChat.last['text']! + chunk;
          });
        }
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      setState(() {
        _currentActiveChat.last['text'] = "⚠️ AI Connection Error: $e";
      });
    } finally {
      setState(() => _isAiThinking = false);
    }
  }

  Future<void> _deletePdf(String filename) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/delete-pdf/${Uri.encodeComponent(filename)}')
      );

      if (response.statusCode == 200) {
        setState(() {
          _pdfLibrary.remove(filename);
          if (_pdfName == filename) {
            _pdfName = "";
            _currentActiveChat = [];
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to delete PDF: $e");
    }
  }

  Future<void> _clearChatHistory() async {
      if (_pdfName.isEmpty) return;

      setState(() {
        _currentActiveChat = [];
      });

      try {
        final response = await http.delete(
          Uri.parse('$_baseUrl/clear-chat/${Uri.encodeComponent(_pdfName)}')
        );

        if (response.statusCode == 200) {
          _saveMessage("ai", "✅ Chat history cleared.");
        } else {
          debugPrint("Failed to clear chat history: ${response.statusCode}");
        }
      } catch (e) {
          debugPrint("Clear chat error: $e");
      }
  }

  Future<void> _renamePdf(String oldFilename, String newFilename) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/rename-pdf'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "old_filename": oldFilename,
          "new_filename": newFilename
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String updatedName = data['new_filename'];

        setState(() {
          int index = _pdfLibrary.indexOf(oldFilename);
          if ( index != -1) _pdfLibrary[index] = updatedName;
          if (_pdfName == oldFilename) _pdfName = updatedName;
        });
      }
    } catch (e) {
      debugPrint("Failed to rename PDF: $e");
    }
  }

  Future<void> _showRenameDialog(String oldFilename) async {
    TextEditingController renameController = TextEditingController(
      text: oldFilename.replaceAll('.pdf', '')
    );

    return showDialog(
      context: context, 
      builder: (context) {
        return AlertDialog(
          title: const Text("Rename PDF"),
          content: TextField(
            controller: renameController,
            decoration: const InputDecoration(
              hintText: "Enter new name",
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  String newName = renameController.text.trim();
                  if (newName.isNotEmpty) {
                    Navigator.pop(context);
                    await _renamePdf(oldFilename, newName);
                  }
                },
                child: const Text("Rename"),
              ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            'PDF AI Scholar Workspace',
            style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _toggleSidebar,
          ),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: (isDark ? DarkAcademiaPalette.charcoalSlate : Colors.white).withValues(alpha: 0.7),
              ),
            ),
          ),
          actions: [
            if (widget.isFullScreen)
              IconButton(
                icon: const Icon(Icons.fullscreen_exit),
                tooltip: 'Back to Split View',
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            if (_pdfName.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.cleaning_services_rounded),
                tooltip: 'New Chat',
                onPressed: _clearChatHistory,
              ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _isProcessingPdf ? null : _pickAndUploadPdf,
              tooltip: 'Upload PDF',
            ),
          ],
        ),
        body: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Main Content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    return Row(
                      children: [
                        Expanded(flex: 5, child: _buildPdfViewer()),
                        Expanded(flex: 5, child: _buildChatInterface()),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        TabBar(
                          indicatorColor: DarkAcademiaPalette.fadedGold,
                          indicatorWeight: 3,
                          labelColor: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                          unselectedLabelColor: isDark ? DarkAcademiaPalette.slateGray : DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.6),
                          labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 13),
                          unselectedLabelStyle: GoogleFonts.cinzel(fontSize: 13),
                          tabs: const [
                            Tab(icon: Icon(Icons.picture_as_pdf), text: "Folio Document"),
                            Tab(icon: Icon(Icons.auto_stories), text: "Scholar Chat"),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [_buildPdfViewer(), _buildChatInterface()],
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),

            // Sidebar Overlay
            AnimatedBuilder(
              animation: _sidebarAnimation,
              builder: (context, child) {
                if (_sidebarAnimation.value == 0) {
                  return const SizedBox.shrink();
                }
                return GestureDetector(
                  onTap: _toggleSidebar,
                  child: Opacity(
                    opacity: _sidebarAnimation.value * 0.5,
                    child: Container(
                      color: Colors.black,
                    ),
                  ),
                );
              },
            ),

            // Animated Sidebar
            AnimatedBuilder(
              animation: _sidebarAnimation,
              builder: (context, child) {
                if (_sidebarAnimation.value == 0) {
                  return const SizedBox.shrink();
                }
                return FractionalTranslation(
                  translation: Offset(_sidebarAnimation.value - 1.0, 0),
                  child: child,
                );
              },
              child: SizedBox(
                width: 310,
                height: double.infinity,
                child: GlassContainer(
                  child: Material(
                    color: Colors.transparent,
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
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
                                const Icon(Icons.local_library_outlined, color: DarkAcademiaPalette.fadedGold, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'Archival Folios',
                                  style: GoogleFonts.cinzel(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_pdfLibrary.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                "No archival folios cataloged yet.",
                                style: GoogleFonts.cinzel(
                                  color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.slateGray,
                                  fontSize: 13,
                                ),
                              ),
                            ).animate().fadeIn(duration: 400.ms),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _pdfLibrary.length,
                              itemBuilder: (context, index) {
                                String filename = _pdfLibrary[index];
                                final isCurrent = _pdfName == filename;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? (isDark ? DarkAcademiaPalette.spaceCadet : DarkAcademiaPalette.tan.withValues(alpha: 0.35))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isCurrent
                                        ? Border.all(color: DarkAcademiaPalette.fadedGold, width: 1.2)
                                        : Border.all(color: Colors.transparent),
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.menu_book,
                                      color: isCurrent
                                          ? DarkAcademiaPalette.fadedGold
                                          : (isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.caputMortuum),
                                      size: 20,
                                    ),
                                    title: Text(
                                      filename,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'serif',
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 13.5,
                                        color: isDark ? Colors.white : DarkAcademiaPalette.oxfordBrown,
                                      ),
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        size: 18,
                                        color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.slateGray,
                                      ),
                                      onSelected: (value) {
                                        if (value == 'rename') {
                                          _showRenameDialog(filename);
                                        } else if (value == 'delete') {
                                          _deletePdf(filename);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => [
                                        const PopupMenuItem(
                                          value: 'rename',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 16, color: DarkAcademiaPalette.burntUmber),
                                              SizedBox(width: 8),
                                              Text("Rename Folio"),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, size: 16, color: DarkAcademiaPalette.caputMortuum),
                                              SizedBox(width: 8),
                                              Text("Delete", style: TextStyle(color: DarkAcademiaPalette.caputMortuum)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      _toggleSidebar();
                                      _loadChatForFile(filename);
                                    },
                                  ),
                                ).animate().fadeIn(delay: (50 * index).ms, duration: 400.ms).slideX(begin: -0.2, end: 0);
                              },
                            ),
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

  Widget _buildPdfViewer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
        border: Border(
          right: BorderSide(
            color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.2) : DarkAcademiaPalette.tan,
            width: 1,
          ),
        ),
      ),
      child: _isProcessingPdf
          ? const Center(
              child: CircularProgressIndicator(color: DarkAcademiaPalette.fadedGold),
            )
          : _pdfName.isNotEmpty
          ? (_pdfBytes != null 
              ? SfPdfViewer.memory(
                  _pdfBytes!,
                  controller: _pdfViewerController,
                  onDocumentLoaded: (details) {
                    if (widget.initialPage != null && widget.initialPage! > 0) {
                      _pdfViewerController.jumpToPage(widget.initialPage!);
                    }
                  },
                  onDocumentLoadFailed: (details) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load local PDF: ${details.description}')));
                  },
                )
              : SfPdfViewer.network(
                  '$_baseUrl/get-pdf/${Uri.encodeComponent(_pdfName)}',
                  controller: _pdfViewerController,
                  onDocumentLoaded: (details) {
                    if (widget.initialPage != null && widget.initialPage! > 0) {
                      _pdfViewerController.jumpToPage(widget.initialPage!);
                    }
                  },
                  onDocumentLoadFailed: (details) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This PDF is no longer available on the server (it may have been deleted due to server restart).'),
                        duration: Duration(seconds: 5),
                      )
                    );
                  },
                )
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book,
                    size: 64,
                    color: isDark ? DarkAcademiaPalette.tan.withValues(alpha: 0.3) : DarkAcademiaPalette.slateGray.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Select or upload an archival folio to begin examination",
                    style: GoogleFonts.cinzel(
                      fontSize: 14,
                      color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.slateGray,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }

  Widget _buildChatInterface() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? DarkAcademiaPalette.charcoalSlate.withValues(alpha: 0.7) : DarkAcademiaPalette.antiqueIvory.withValues(alpha: 0.5),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _currentActiveChat.length,
              itemBuilder: (context, index) {
                var msg = _currentActiveChat[index];
                bool isUser = msg['role'] == 'user';

                Widget messageBubble = isUser
                    ? Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isDark ? DarkAcademiaPalette.spaceCadet : DarkAcademiaPalette.caputMortuum,
                          borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(3)),
                          border: Border.all(
                            color: DarkAcademiaPalette.fadedGold.withValues(alpha: 0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          msg['text']!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFAF7F0),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      )
                    : Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF23252A) : const Color(0xFFFAF7F0),
                            borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: const Radius.circular(3)),
                            border: Border.all(
                              color: isDark
                                  ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.25)
                                  : DarkAcademiaPalette.tan,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_stories,
                                    size: 14,
                                    color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "SCHOLAR AI RESPONSE",
                                    style: GoogleFonts.cinzel(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                      color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              MarkdownBody(
                                selectable: true,
                                data: _sanitizeMarkdown(msg['text']!),
                                builders: {
                                  'latex': CustomLatexElementBuilder(
                                    textStyle: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 15,
                                      color: isDark ? const Color(0xFFF2EFE9) : DarkAcademiaPalette.oxfordBrown,
                                    ),
                                  ),
                                  'blockquote': AcademicBlockquoteBuilder(isDark: isDark),
                                },
                                extensionSet: md.ExtensionSet(
                                  [LatexBlockSyntax(), ...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                                  [LatexInlineSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
                                ),
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 15,
                                    height: 1.55,
                                    color: isDark ? Colors.white : DarkAcademiaPalette.oxfordBrown,
                                  ),
                                  blockquote: const TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 14.5,
                                    height: 1.5,
                                    color: Color(0xFF111111),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  blockquoteDecoration: BoxDecoration(
                                    color: const Color(0xFFD2E3FC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: const Border(
                                      left: BorderSide(
                                        color: Color(0xFF1967D2),
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                  blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  code: GoogleFonts.shareTechMono(
                                    fontSize: 13,
                                    backgroundColor: isDark ? const Color(0xFF1E2024) : const Color(0xFFEDE8DC),
                                    color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.caputMortuum,
                                  ),
                                  codeblockPadding: const EdgeInsets.all(12),
                                  codeblockDecoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF141619) : const Color(0xFFEDE8DC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.3)
                                          : DarkAcademiaPalette.tan.withValues(alpha: 0.8),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: messageBubble,
                ).animate()
                 .fadeIn(duration: 300.ms)
                 .slideX(begin: isUser ? 0.15 : -0.15, end: 0, curve: Curves.easeOutCubic);
              },
            ),
          ),

          if (_isAiThinking)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "AI Scholar is consulting texts...",
                    style: GoogleFonts.cinzel(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.slateGray,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(3, (index) => 
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: DarkAcademiaPalette.fadedGold,
                            shape: BoxShape.circle,
                          ),
                        ).animate(onPlay: (controller) => controller.repeat())
                         .fadeIn(duration: 300.ms)
                         .then(delay: (150 * index).ms)
                         .fadeOut(duration: 300.ms),
                      )
                    ),
                  )
                ],
              ),
            ),

          GlassContainer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: (isDark ? DarkAcademiaPalette.charcoalSlate : Colors.white).withValues(alpha: 0.85),
                border: Border(
                  top: BorderSide(
                    color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.25) : DarkAcademiaPalette.tan,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: TextStyle(
                        fontFamily: 'serif',
                        color: isDark ? Colors.white : DarkAcademiaPalette.oxfordBrown,
                      ),
                      decoration: InputDecoration(
                        hintText: _pdfName.isEmpty ? "Select or upload an archival folio..." : "Inquire with the AI scholar...",
                        hintStyle: GoogleFonts.cinzel(
                          fontSize: 13,
                          color: (isDark ? Colors.white54 : DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.5)),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2024) : DarkAcademiaPalette.antiqueIvory.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.3) : DarkAcademiaPalette.tan,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.3) : DarkAcademiaPalette.tan,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: DarkAcademiaPalette.fadedGold,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      enabled: _pdfName.isNotEmpty,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: _pdfName.isEmpty
                          ? (isDark ? Colors.white12 : Colors.black12)
                          : (isDark ? DarkAcademiaPalette.spaceCadet : DarkAcademiaPalette.caputMortuum),
                      shape: BoxShape.circle,
                      border: _pdfName.isNotEmpty
                          ? Border.all(color: DarkAcademiaPalette.fadedGold, width: 1.2)
                          : null,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.send,
                        color: _pdfName.isEmpty ? Colors.grey : DarkAcademiaPalette.fadedGold,
                        size: 18,
                      ),
                      onPressed: _pdfName.isEmpty ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
