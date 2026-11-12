import unittest
import os
import sys

# Ensure root directory is in sys.path
root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if root_dir not in sys.path:
    sys.path.insert(0, root_dir)

class TestBackendArchitecture(unittest.TestCase):
    """Smoke and integrity tests for the FastAPI recommender backend."""

    def test_module_imports(self):
        """Verify that main and core app modules import cleanly without missing dependencies."""
        import main
        from app.bundler import router as bundler_router, create_bundle, BundleRequest, ResourceItem
        from app.video_link import search_youtube_live, rank_and_cache_video_selection

        from app.heatmap_ranker import calculate_wilson_score_lower_bound, rank_resources_by_wilson_score
        from app.lens_cache import lens_cache, LensLRUTTLCache
        from app.knowledge_tracing import update_bkt_mastery, predict_next_correct_probability
        from app.timestamp_mapper import parse_srt_subtitles, map_exam_question_to_video_timestamp
        from app.mermaid_validator import detect_and_break_graph_cycles, sanitize_mermaid_syntax

        self.assertIsNotNone(main.app)
        self.assertIsNotNone(bundler_router)
        self.assertTrue(callable(create_bundle))
        self.assertTrue(callable(search_youtube_live))
        self.assertTrue(callable(rank_and_cache_video_selection))
        self.assertTrue(callable(calculate_wilson_score_lower_bound))
        self.assertTrue(callable(rank_resources_by_wilson_score))
        self.assertIsInstance(lens_cache, LensLRUTTLCache)
        self.assertTrue(callable(update_bkt_mastery))
        self.assertTrue(callable(predict_next_correct_probability))
        self.assertTrue(callable(parse_srt_subtitles))
        self.assertTrue(callable(map_exam_question_to_video_timestamp))
        self.assertTrue(callable(detect_and_break_graph_cycles))
        self.assertTrue(callable(sanitize_mermaid_syntax))

    def test_fastapi_route_registration(self):
        """Ensure critical API endpoints are correctly mounted on the FastAPI app instance."""
        import main
        # 1. Collect from FastAPI's official OpenAPI specification paths
        routes = set(main.app.openapi().get("paths", {}).keys())

        # 2. Collect from FastAPI 0.137+ iter_route_contexts if available
        try:
            from fastapi.routing import iter_route_contexts
            for ctx in iter_route_contexts(main.app.routes):
                if hasattr(ctx, "path"):
                    routes.add(ctx.path)
        except (ImportError, AttributeError):
            pass

        # 3. Direct Starlette / APIRoute inspection with recursive router unpacking
        for r in main.app.routes:
            if hasattr(r, "path"):
                routes.add(r.path)
            elif hasattr(r, "routes"):
                for sub_r in getattr(r, "routes", []):
                    if hasattr(sub_r, "path"):
                        routes.add(sub_r.path)

        critical_endpoints = [
            "/",
            "/api/resolve-course-pdf",
            "/api/resolve-subchapter-video",
            "/api/analyze-pdf-focus",
            "/api/generate-subchapter-flashcards",
            "/upload-pdf",
            "/library",
            "/chat",
            "/bundler/create",
            "/api/log-quiz-attempt",
            "/api/bkt/update",
            "/api/map-pyq-timestamp",
            "/api/scan-pyq-photo",
            "/api/sanitize-mermaid",
        ]

        for endpoint in critical_endpoints:
            self.assertIn(
                endpoint,
                routes,
                f"Missing critical endpoint '{endpoint}' from FastAPI route table."
            )

    def test_schema_validations(self):
        """Verify that Pydantic request models enforce expected types and defaults."""
        import main

        # Test ResolveCoursePdfRequest
        pdf_req = main.ResolveCoursePdfRequest(
            course_code="WIX1001"
        )
        self.assertEqual(pdf_req.course_code, "WIX1001")

        # Test ResolveCoursePdfResponse
        pdf_res = main.ResolveCoursePdfResponse(
            course_code="WIX1001",
            course_name="Computing Mathematics",
            filename="WIX1001_Mathematics.pdf",
            source="local",
            title="Discrete Mathematics Course Pack",
            message="Found"
        )
        self.assertEqual(pdf_res.course_code, "WIX1001")
        self.assertEqual(pdf_res.course_name, "Computing Mathematics")
        self.assertEqual(pdf_res.source, "local")
        self.assertEqual(pdf_res.title, "Discrete Mathematics Course Pack")

        # Test ResolveSubchapterVideoRequest
        vid_req = main.ResolveSubchapterVideoRequest(
            course_code="WIA1002",
            subchapter_title="Linked Lists & Trees"
        )
        self.assertEqual(vid_req.course_code, "WIA1002")
        self.assertEqual(vid_req.subchapter_title, "Linked Lists & Trees")

    def test_resource_deduplication_logic(self):
        """Verify that duplicate learning resources are filtered by (course_code, title, url)."""
        raw_resources = [
            {"course_code": "WIX1002", "title": "Java Fundamentals", "url": "https://example.com/java"},
            {"course_code": "WIX1002", "title": "Java Fundamentals", "url": "https://example.com/java"},
            {"course_code": "WIX1002", "title": "Code like a Pro in C", "url": "https://example.com/c"},
        ]

        seen_keys = set()
        deduped = []
        for r in raw_resources:
            key = f"{r['course_code'].strip().upper()}_{r['title'].strip().lower()}_{r['url'].strip().lower()}"
            if key not in seen_keys:
                seen_keys.add(key)
                deduped.append(r)

        self.assertEqual(len(deduped), 2)
        self.assertEqual(deduped[0]["title"], "Java Fundamentals")
        self.assertEqual(deduped[1]["title"], "Code like a Pro in C")

    def test_zero_topic_contamination_in_study_bundler(self):
        """Verify that study bundles are strictly isolated to their domain with zero topic contamination."""
        from app.bundler import create_bundle, BundleRequest

        # 1. Computer Networks Bundle
        net_bundle = create_bundle(BundleRequest(minutes_available=30, topic="Computer Networks"))
        self.assertTrue(len(net_bundle) > 0)
        for item in net_bundle:
            content_lower = item.content.lower()
            # Must NOT contain unrelated dynamic programming or SOLID principles
            self.assertNotIn("dynamic programming", content_lower)
            self.assertNotIn("solid principle", content_lower)
            self.assertNotIn("square root of", content_lower)

        # 2. Database Systems Bundle
        db_bundle = create_bundle(BundleRequest(minutes_available=30, topic="Database"))
        self.assertTrue(len(db_bundle) > 0)
        for item in db_bundle:
            content_lower = item.content.lower()
            # Must NOT contain network packet transmission or dynamic programming
            self.assertNotIn("packet transmission", content_lower)
            self.assertNotIn("dynamic programming", content_lower)
            self.assertNotIn("square root of", content_lower)

    def test_lens_lru_ttl_cache(self):
        """Verify LRU capacity eviction and TTL expiry in LensLRUTTLCache."""
        from app.lens_cache import LensLRUTTLCache

        cache = LensLRUTTLCache(capacity=2, ttl_seconds=10.0)
        cache.put("lens", "topic", "content1", "transformed1")
        cache.put("lens", "topic", "content2", "transformed2")
        self.assertEqual(cache.get("lens", "topic", "content1"), "transformed1")

        # Adding a 3rd item should evict content2 (since content1 was accessed and promoted to MRU)
        cache.put("lens", "topic", "content3", "transformed3")
        self.assertIsNone(cache.get("lens", "topic", "content2"))
        self.assertEqual(cache.get("lens", "topic", "content1"), "transformed1")
        self.assertEqual(cache.get("lens", "topic", "content3"), "transformed3")

    def test_knowledge_tracing_bkt(self):
        """Verify Bayesian Knowledge Tracing updates and trajectory tracing."""
        from app.knowledge_tracing import update_bkt_mastery, predict_next_correct_probability, trace_mastery_trajectory

        # Correct response should increase mastery
        prior = 0.20
        post_correct = update_bkt_mastery(prior, is_correct=True)
        self.assertGreater(post_correct, prior)

        # Incorrect response should decrease or dampen mastery
        post_incorrect = update_bkt_mastery(prior, is_correct=False)
        self.assertLess(post_incorrect, post_correct)

        # Trajectory of correct responses should monotonically trend upward
        traj = trace_mastery_trajectory([True, True, True], initial_prior=0.10)
        self.assertEqual(len(traj), 3)
        self.assertTrue(traj[0] < traj[1] < traj[2])

    def test_timestamp_mapper(self):
        """Verify SRT parsing and sliding window exam question timestamp mapping."""
        from app.timestamp_mapper import parse_srt_subtitles, map_exam_question_to_video_timestamp

        sample_srt = """1
00:01:10,000 --> 00:01:15,000
In this lecture we discuss pointers in C programming.

2
00:01:16,000 --> 00:01:25,000
A pointer stores the memory address of another variable.

3
00:01:26,000 --> 00:01:35,000
Dynamic memory allocation uses malloc and free.
"""
        subs = parse_srt_subtitles(sample_srt)
        self.assertEqual(len(subs), 3)
        self.assertAlmostEqual(subs[0]["start_sec"], 70.0)

        match = map_exam_question_to_video_timestamp("How does a pointer store a memory address?", subs, window_size=2)
        self.assertGreater(match["similarity_score"], 0.0)
        self.assertEqual(match["timestamp_sec"], 70.0)

    def test_photo_scanner_normalization(self):
        """Verify base64 data URI normalization and schema generation in photo scanner."""
        from app.photo_scanner import normalize_base64_image
        raw = "abc123xyz"
        uri = normalize_base64_image(raw)
        self.assertEqual(uri, "data:image/jpeg;base64,abc123xyz")
        already_uri = "data:image/png;base64,12345"
        self.assertEqual(normalize_base64_image(already_uri), already_uri)

if __name__ == "__main__":
    unittest.main()
