import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/resource_item.dart';
import '../theme/app_theme.dart';

class VideoPlayerWidget extends StatelessWidget {
  final ResourceItem item;

  const VideoPlayerWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrl = item.content.trim().startsWith('http://') || item.content.trim().startsWith('https://');

    // Never display database row keys (e.g. "neon_1", "live_yt_...") as the title
    String displayTitle;
    if (item.title != null && item.title!.trim().isNotEmpty && !item.title!.toLowerCase().startsWith('neon_')) {
      displayTitle = item.title!.trim();
    } else if (item.topic.isNotEmpty && !item.topic.toLowerCase().startsWith('neon_') && int.tryParse(item.topic) == null) {
      displayTitle = item.topic.trim();
    } else {
      displayTitle = "${item.topic} Lecture";
    }

    // Subtitle displays the subject / course domain if distinct from the title
    String displaySubtitle = "";
    if (item.topic.isNotEmpty && item.topic.trim().toLowerCase() != displayTitle.toLowerCase() && !item.topic.toLowerCase().startsWith('neon_')) {
      displaySubtitle = "Subject: ${item.topic}";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? DarkAcademiaPalette.charcoalSlate : DarkAcademiaPalette.antiqueIvory,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? DarkAcademiaPalette.fadedGold.withValues(alpha: 0.3) : DarkAcademiaPalette.tan,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top badge & duration
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded, color: Colors.red, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        "VIDEO LECTURE",
                        style: GoogleFonts.shareTechMono(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "${item.durationMin} MIN",
                  style: GoogleFonts.shareTechMono(
                    color: isDark ? DarkAcademiaPalette.fadedGold : DarkAcademiaPalette.caputMortuum,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Video Title
            Text(
              displayTitle,
              style: GoogleFonts.cinzel(
                color: isDark ? Colors.white : DarkAcademiaPalette.caputMortuum,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            if (displaySubtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                displaySubtitle,
                style: GoogleFonts.shareTechMono(
                  color: isDark ? DarkAcademiaPalette.slateGray : DarkAcademiaPalette.coffee,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Video Preview / Action Card
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_outline, color: Colors.white70, size: 48),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(isUrl ? "Watch Video Stream" : "Search Video on YouTube"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final targetUrl = isUrl
                            ? item.content.trim()
                            : "https://www.youtube.com/results?search_query=${Uri.encodeComponent(item.topic)}";
                        final uri = Uri.parse(targetUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
