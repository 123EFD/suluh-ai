import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/bundler_state.dart';
import '../models/resource_item.dart';
import '../widgets/flashcard_deck_widget.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/pyq_solution_widget.dart';
import '../theme/app_theme.dart';

class StudySessionScreen extends StatelessWidget {
  const StudySessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bundle = context.watch<BundlerState>().currentBundle;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final themeToggleButton = IconButton(
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
      ),
      tooltip: isDark ? "Switch to Daylight Folio" : "Switch to Midnight Archive",
      onPressed: () {
        MyApp.toggleTheme(context);
      },
    );

    if (bundle.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Archival Study Bundle", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
          actions: [
            themeToggleButton,
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: Text(
            "No resources found. Try another topic!",
            style: GoogleFonts.cinzel(fontSize: 16, color: DarkAcademiaPalette.slateGray),
          ),
        ),
      );
    }

    final totalMinutes = bundle.fold(0, (sum, item) => sum + item.durationMin);

    // Group items by type (case-insensitive)
    final flashcards = bundle.where((i) {
      final t = i.type.trim().toLowerCase();
      return t == 'flashcard' || t == 'flashcards';
    }).toList();

    final videos = bundle.where((i) {
      final t = i.type.trim().toLowerCase();
      return t == 'video_chunk' || t == 'video' || t == 'youtube';
    }).toList();

    final pyqs = bundle.where((i) {
      final t = i.type.trim().toLowerCase();
      return t == 'pyq_solution' || t == 'problem' || t == 'quiz';
    }).toList();

    final readings = bundle.where((i) {
      return !flashcards.contains(i) && !videos.contains(i) && !pyqs.contains(i);
    }).toList();

    // Dynamically build active tabs and their corresponding views
    List<Widget> activeTabs = [];
    List<Widget> activeTabViews = [];

    if (flashcards.isNotEmpty) {
      activeTabs.add(Tab(text: "Flashcards (${flashcards.length})"));
      activeTabViews.add(FlashcardDeckWidget(items: flashcards));
    }
    if (videos.isNotEmpty) {
      activeTabs.add(Tab(text: "Videos (${videos.length})"));
      activeTabViews.add(_buildListView(videos, 'video_chunk', isDark));
    }
    if (pyqs.isNotEmpty) {
      activeTabs.add(Tab(text: "Problems (${pyqs.length})"));
      activeTabViews.add(_buildListView(pyqs, 'pyq_solution', isDark));
    }
    if (readings.isNotEmpty) {
      activeTabs.add(Tab(text: "Readings (${readings.length})"));
      activeTabViews.add(_buildReadingListView(readings, isDark));
    }

    // Safety fallback: if no specific tab matched, display all items in a generic view
    if (activeTabs.isEmpty) {
      activeTabs.add(Tab(text: "Curriculum (${bundle.length})"));
      activeTabViews.add(_buildReadingListView(bundle, isDark));
    }

    return DefaultTabController(
      length: activeTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Survival Curriculum", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          actions: [
            themeToggleButton,
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            tabs: activeTabs,
            isScrollable: true,
            indicatorColor: DarkAcademiaPalette.fadedGold,
            labelColor: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
            unselectedLabelColor: isDark ? DarkAcademiaPalette.slateGray : DarkAcademiaPalette.oxfordBrown.withValues(alpha: 0.6),
            labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.cinzel(fontSize: 13),
          ),
        ),
        body: Column(
          children: [
            // Bundle summary header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? DarkAcademiaPalette.spaceCadet.withValues(alpha: 0.5) : DarkAcademiaPalette.tan.withValues(alpha: 0.25),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.3) : DarkAcademiaPalette.tan,
                    width: 1,
                  ),
                ),
              ),
              child: Text(
                "ARCHIVAL CURRICULUM // ${bundle.length} RESOURCES • $totalMinutes MIN TOTAL STUDY PLAN",
                style: GoogleFonts.shareTechMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.caputMortuum,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // The active tab view
            Expanded(
              child: TabBarView(
                children: activeTabViews,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<ResourceItem> items, String type, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final ResourceItem item = items[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "CURRICULUM NODE ${index + 1} OF ${items.length}  •  ${item.durationMin} MIN",
                style: GoogleFonts.shareTechMono(
                  color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.slateGray,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            if (type == 'video_chunk' || type == 'video')
              VideoPlayerWidget(item: item)
            else if (type == 'pyq_solution')
              PyqSolutionWidget(item: item)
            else
              _buildSingleReadingCard(item, isDark),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildReadingListView(List<ResourceItem> items, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final ResourceItem item = items[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "REFERENCE NODE ${index + 1} OF ${items.length}  •  ${item.durationMin} MIN READ",
                style: GoogleFonts.shareTechMono(
                  color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.slateGray,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            _buildSingleReadingCard(item, isDark),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildSingleReadingCard(ResourceItem item, bool isDark) {
    final isUrl = item.content.trim().startsWith('http://') || item.content.trim().startsWith('https://');
    final typeLower = item.type.trim().toLowerCase();

    IconData typeIcon = Icons.article_outlined;
    if (typeLower.contains('pdf')) {
      typeIcon = Icons.picture_as_pdf_outlined;
    } else if (typeLower.contains('book')) {
      typeIcon = Icons.menu_book_outlined;
    }

    // Never display database row keys (e.g. "neon_1", "neon_2") as the title
    String displayTitle;
    if (item.title != null && item.title!.trim().isNotEmpty && !item.title!.toLowerCase().startsWith('neon_')) {
      displayTitle = item.title!.trim();
    } else if (item.topic.isNotEmpty && !item.topic.toLowerCase().startsWith('neon_') && int.tryParse(item.topic) == null) {
      displayTitle = item.topic.trim();
    } else {
      displayTitle = "${item.topic} Document";
    }

    String displaySubtitle = "";
    if (item.topic.isNotEmpty && item.topic.trim().toLowerCase() != displayTitle.toLowerCase() && !item.topic.toLowerCase().startsWith('neon_')) {
      displaySubtitle = "Subject: ${item.topic}";
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.3) : DarkAcademiaPalette.tan,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      typeIcon,
                      size: 15,
                      color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.type.toUpperCase(),
                      style: GoogleFonts.shareTechMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "${item.durationMin} MIN READ",
                style: GoogleFonts.shareTechMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            displayTitle,
            style: GoogleFonts.cinzel(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.3,
              color: isDark ? Colors.white : DarkAcademiaPalette.caputMortuum,
            ),
          ),
          if (displaySubtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              displaySubtitle,
              style: GoogleFonts.shareTechMono(
                fontSize: 12,
                color: isDark ? DarkAcademiaPalette.slateGray : DarkAcademiaPalette.coffee,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Action or Content
          if (isUrl) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? DarkAcademiaPalette.spaceCadet.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? DarkAcademiaPalette.slateGray.withValues(alpha: 0.3) : DarkAcademiaPalette.tan.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 16, color: DarkAcademiaPalette.slateGray),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.content.trim(),
                      style: GoogleFonts.shareTechMono(
                        fontSize: 11,
                        color: isDark ? DarkAcademiaPalette.tan : DarkAcademiaPalette.slateGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text("Open Resource Online"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? DarkAcademiaPalette.spaceCadet : DarkAcademiaPalette.caputMortuum,
                  foregroundColor: isDark ? DarkAcademiaPalette.antiqueIvory : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                onPressed: () async {
                  final uri = Uri.parse(item.content.trim());
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? DarkAcademiaPalette.spaceCadet.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? DarkAcademiaPalette.slateGray.withValues(alpha: 0.3) : DarkAcademiaPalette.tan.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                item.content,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.white70 : DarkAcademiaPalette.oxfordBrown,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
