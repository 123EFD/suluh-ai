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

        self.assertIsNotNone(main.app)
        self.assertIsNotNone(bundler_router)
        self.assertTrue(callable(create_bundle))
        self.assertTrue(callable(search_youtube_live))
        self.assertTrue(callable(rank_and_cache_video_selection))

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

if __name__ == "__main__":
    unittest.main()
