import time
from typing import Optional, Dict

class Node:
    """Doubly linked list node holding a cached lens transformation item."""
    def __init__(self, key: str, val: str, timestamp: float):
        self.key: str = key
        self.val: str = val
        self.timestamp: float = timestamp
        self.prev: Optional['Node'] = None
        self.next: Optional['Node'] = None

class LensLRUTTLCache:
    """
    O(1) Least Recently Used (LRU) Cache with Time-To-Live (TTL) eviction.
    Uses a Hash Map for O(1) key-node lookup and a Doubly Linked List for O(1)
    promotion to head and eviction from tail.
    """
    def __init__(self, capacity: int = 128, ttl_seconds: float = 3600.0):
        self.capacity: int = capacity
        self.ttl: float = ttl_seconds
        self.map: Dict[str, Node] = {}
        
        # Sentinel dummy head and tail to simplify boundary pointer operations
        self.head: Node = Node("", "", 0.0)
        self.tail: Node = Node("", "", 0.0)
        self.head.next = self.tail
        self.tail.prev = self.head

    def _generate_key(self, lens: str, topic: str, content: str) -> str:
        """Constructs a unique deterministic composite key."""
        return f"{lens.strip().lower()}::{topic.strip().lower()}::{hash(content)}"

    # ==============================================================================
    # [BLANK 4a]: LRU Cache Retrieval with TTL Expiry Check
    # Task: Given query parameters (lens, topic, content), retrieve the cached
    # pedagogical lens transformation. If the key exists:
    # 1. Check if the entry has expired beyond ttl_seconds. If expired, purge it.
    # 2. If valid, promote the node to the head of the Doubly Linked List (most recently used).
    # 3. Return the cached string value.
    #
    # Input:
    #   lens: str - Transformation lens ("feynman", "analogy", "first_principles", "cram")
    #   topic: str - Subject topic name
    #   content: str - Source text content
    #
    # Output:
    #   Optional[str] - Cached transformed text if present and valid; None otherwise.
    # ==============================================================================
    def get(self, lens: str, topic: str, content: str) -> Optional[str]:
        """
        Retrieves a valid non-expired item from the cache and updates its recency.
        
        TODO:
        1. Generate composite key via _generate_key(lens, topic, content).
        2. If key not in self.map, return None.
        3. Retrieve node from self.map.
        4. Check expiry: if (current_time - node.timestamp) > self.ttl:
             - Remove node from linked list.
             - Delete key from self.map.
             - Return None.
        5. Move node to head of linked list (promote to most recently used).
        6. Return node.val.
        """
        # [LEARNER IMPLEMENTATION REQUIRED - DO NOT WRITE WORKING LOGIC HERE]
        return None

    # ==============================================================================
    # [BLANK 4b]: LRU Cache Insert with Node Promotion & Capacity Eviction
    # Task: Insert or update a lens transformation in the cache.
    # 1. If key exists: update value and timestamp, promote node to head.
    # 2. If key is new: create Node, insert at head, store in map.
    # 3. If size exceeds capacity: evict the least recently used node from tail.prev
    #    and remove it from map.
    #
    # Input:
    #   lens: str - Transformation lens
    #   topic: str - Topic name
    #   content: str - Source content
    #   transformed_text: str - AI-generated lens transformation to store
    #
    # Output:
    #   None
    # ==============================================================================
    def put(self, lens: str, topic: str, content: str, transformed_text: str) -> None:
        """
        Inserts or updates an entry, evicting the oldest node if capacity is reached.
        
        TODO:
        1. Generate composite key.
        2. If key in self.map:
             - Update node.val and node.timestamp.
             - Move node to head.
        3. Else:
             - If len(self.map) >= self.capacity:
                 - Evict tail.prev (LRU node) from list and map.
             - Create new Node, add to head, and store in self.map.
        """
        # [LEARNER IMPLEMENTATION REQUIRED - DO NOT WRITE WORKING LOGIC HERE]
        pass

# Global singleton instance for the API server
lens_cache = LensLRUTTLCache(capacity=256, ttl_seconds=7200.0)
