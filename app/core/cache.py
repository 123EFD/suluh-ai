import os
import time
import json
import hashlib
import logging
from typing import Optional, Any, Callable, Dict
import redis
from app.core.config import REDIS_URL
from app.lens_cache import LensLRUTTLCache

logger = logging.getLogger("recommender.cache")

class UnifiedCacheManager:
    """
    Two-Tier Hybrid Cache Architecture:
    - Tier 1 (L1): Local process in-memory LRU with TTL (sub-millisecond reads).
    - Tier 2 (L2): Distributed Redis cache (shared across workers/containers).
    - Circuit Breaker: Automatically detects Redis connection failures and falls
      back gracefully to L1 in-memory caching without disrupting active requests.
    """

    def __init__(
        self,
        redis_url: Optional[str] = None,
        l1_capacity: int = 512,
        circuit_cooldown_seconds: float = 30.0
    ):
        self.redis_url = redis_url or REDIS_URL or os.getenv("REDIS_URL", "redis://localhost:6379/0")
        self.circuit_cooldown = circuit_cooldown_seconds
        self._circuit_open_until: float = 0.0

        # L1 Local In-Memory Cache
        self.l1_cache = LensLRUTTLCache(capacity=l1_capacity, ttl_seconds=86400.0)

        # L2 Redis Connection Pool
        self._redis_client: Optional[redis.Redis] = None
        self._init_redis_client()

    def _init_redis_client(self) -> None:
        """Initializes the Redis client with connection pooling and timeouts."""
        if not self.redis_url:
            self._redis_client = None
            return

        try:
            pool = redis.ConnectionPool.from_url(
                self.redis_url,
                socket_timeout=1.5,
                socket_connect_timeout=1.5,
                max_connections=20,
                decode_responses=True
            )
            self._redis_client = redis.Redis(connection_pool=pool)
            # Quick non-blocking ping
            self._redis_client.ping()
            self._circuit_open_until = 0.0
            logger.info("Connected to Redis distributed cache at %s", self.redis_url)
        except Exception as e:
            logger.warning("Redis unavailable at startup (%s). Defaulting to L1 local cache.", e)
            self._trigger_circuit_breaker()

    def _trigger_circuit_breaker(self) -> None:
        """Opens the circuit breaker for a temporary cooldown period."""
        self._circuit_open_until = time.time() + self.circuit_cooldown

    def is_redis_available(self) -> bool:
        """Checks if L2 Redis client is active and circuit breaker is closed."""
        if not self._redis_client or time.time() < self._circuit_open_until:
            return False
        return True

    def _generate_cache_key(self, namespace: str, raw_key: str) -> str:
        """
        Creates a deterministic Redis key with namespace isolation.
        Uses MD5 hashing with usedforsecurity=False for long inputs (Bandit B324 compliant).
        """
        clean_ns = namespace.strip().lower()
        key_str = raw_key.strip()
        if len(key_str) > 64 or " " in key_str or "\n" in key_str:
            digest = hashlib.md5(key_str.encode("utf-8"), usedforsecurity=False).hexdigest()
            return f"recommender:{clean_ns}:{digest}"
        return f"recommender:{clean_ns}:{key_str}"

    def get(self, namespace: str, key: str) -> Optional[Any]:
        """
        Retrieves a value from the two-tier cache:
        1. Checks L1 in-memory cache first (sub-millisecond).
        2. If L1 misses and Redis is available, checks L2 Redis.
        3. If L2 hits, backfills L1 for subsequent worker calls.
        """
        full_key = self._generate_cache_key(namespace, key)

        # 1. Check L1 in-memory cache
        l1_val = self.l1_cache.get(namespace, "unified", key)
        if l1_val is not None:
            try:
                return json.loads(l1_val)
            except Exception:
                return l1_val

        # 2. Check L2 Redis cache
        if self.is_redis_available() and self._redis_client:
            try:
                raw_l2 = self._redis_client.get(full_key)
                if raw_l2 is not None:
                    try:
                        parsed = json.loads(raw_l2)
                    except Exception:
                        parsed = raw_l2

                    # Backfill L1 local cache
                    self.l1_cache.put(namespace, "unified", key, raw_l2)
                    return parsed
            except Exception as err:
                logger.warning("Redis GET failed for %s (%s). Falling back to L1.", full_key, err)
                self._trigger_circuit_breaker()

        return None

    def set(self, namespace: str, key: str, value: Any, ttl_seconds: int = 3600) -> bool:
        """
        Stores a value in both L1 local in-memory cache and L2 distributed Redis.
        Serializes complex objects safely to JSON (no pickle).
        """
        full_key = self._generate_cache_key(namespace, key)

        # Safe JSON serialization
        if isinstance(value, str):
            serialized = value
        else:
            try:
                serialized = json.dumps(value)
            except Exception:
                serialized = str(value)

        # 1. Populate L1 Local Cache
        try:
            self.l1_cache.put(namespace, "unified", key, serialized)
        except Exception as e:
            logger.warning("L1 cache put error: %s", e)

        # 2. Populate L2 Redis Cache
        if self.is_redis_available() and self._redis_client:
            try:
                self._redis_client.set(full_key, serialized, ex=max(1, ttl_seconds))
                return True
            except Exception as err:
                logger.warning("Redis SET failed for %s (%s).", full_key, err)
                self._trigger_circuit_breaker()

        return True

    def delete(self, namespace: str, key: str) -> bool:
        """Removes a key from both L1 and L2 cache tiers."""
        full_key = self._generate_cache_key(namespace, key)

        # Evict from L1
        composite_l1_key = self.l1_cache._generate_key(namespace, "unified", key)
        if composite_l1_key in self.l1_cache.map:
            node = self.l1_cache.map[composite_l1_key]
            self.l1_cache._remove_node(node)
            del self.l1_cache.map[composite_l1_key]

        # Evict from L2
        if self.is_redis_available() and self._redis_client:
            try:
                self._redis_client.delete(full_key)
                return True
            except Exception as err:
                logger.warning("Redis DELETE failed for %s (%s).", full_key, err)
                self._trigger_circuit_breaker()

        return True

    def get_or_set(
        self,
        namespace: str,
        key: str,
        ttl_seconds: int,
        factory_fn: Callable[[], Any]
    ) -> Any:
        """Cache-aside helper: returns cached value or computes and populates both tiers."""
        cached = self.get(namespace, key)
        if cached is not None:
            return cached

        fresh_val = factory_fn()
        if fresh_val is not None:
            self.set(namespace, key, fresh_val, ttl_seconds)
        return fresh_val

    def health_check(self) -> Dict[str, Any]:
        """Provides operational metrics across L1 and L2 cache layers."""
        redis_status = "disabled"
        latency_ms = None

        if self.is_redis_available() and self._redis_client:
            try:
                t0 = time.time()
                self._redis_client.ping()
                latency_ms = round((time.time() - t0) * 1000, 2)
                redis_status = "healthy"
            except Exception as e:
                redis_status = f"unhealthy ({e})"
        elif self.redis_url and time.time() < self._circuit_open_until:
            redis_status = f"circuit_open (cooling down for {round(self._circuit_open_until - time.time(), 1)}s)"

        return {
            "l1_local_items": len(self.l1_cache.map),
            "l1_capacity": self.l1_cache.capacity,
            "l2_redis_status": redis_status,
            "l2_redis_url": self.redis_url.split("@")[-1] if self.redis_url else None,
            "l2_latency_ms": latency_ms
        }

# Global singleton instance for the recommender backend
cache_manager = UnifiedCacheManager()
