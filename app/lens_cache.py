import time
import hashlib
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
    Uses a Hash Map for O(1) key-node lookup and a Doubly Linked List with sentinel
    dummy head and tail for O(1) MRU promotion and LRU eviction.
    """
    def __init__(self, capacity: int = 128, ttl_seconds: float = 3600.0):
        self.capacity: int = capacity
        self.ttl: float = ttl_seconds
        self.map: Dict[str, Node] = {}
        
        # Sentinel dummy head and tail to simplify boundary pointer operations
        self.head: Node = Node("__HEAD__", "", 0.0)
        self.tail: Node = Node("__TAIL__", "", 0.0)
        self.head.next = self.tail
        self.tail.prev = self.head

    def _generate_key(self, lens: str, topic: str, content: str) -> str:
        """Constructs a deterministic composite key using non-cryptographic MD5 hashing."""
        content_hash = hashlib.md5(content.encode("utf-8"), usedforsecurity=False).hexdigest()
        return f"{lens.strip().lower()}::{topic.strip().lower()}::{content_hash}"

    def _add_node_to_head(self, node: Node) -> None:
        """Inserts node immediately after the sentinel head (most recently used)."""
        node.prev = self.head
        node.next = self.head.next
        if self.head.next:
            self.head.next.prev = node
        self.head.next = node

    def _remove_node(self, node: Node) -> None:
        """Unlinks a node from the doubly linked list."""
        prev_node = node.prev
        next_node = node.next
        if prev_node:
            prev_node.next = next_node
        if next_node:
            next_node.prev = prev_node

    def _move_to_head(self, node: Node) -> None:
        """Promotes an existing node to the head (MRU)."""
        self._remove_node(node)
        self._add_node_to_head(node)

    def _pop_tail(self) -> Optional[Node]:
        """Pops and returns the least-recently-used node immediately preceding the sentinel tail."""
        lru_node = self.tail.prev
        if lru_node and lru_node != self.head:
            self._remove_node(lru_node)
            return lru_node
        return None
    
    def get(self, lens: str, topic: str, content: str) -> Optional[str]:
        """Retrieves cached item if present and unexpired, promoting to MRU head."""
        key = self._generate_key(lens, topic, content)
        if key not in self.map:
            return None
        
        node = self.map[key]
        if time.time() - node.timestamp > self.ttl:
            # Expired: remove from list and map
            self._remove_node(node)
            del self.map[key]
            return None
        
        # Promote node to head
        self._move_to_head(node)
        return node.val

    def put(self, lens: str, topic: str, content: str, transformed_text: str) -> None:
        """Inserts or updates an item in the cache, evicting the LRU item if at capacity."""
        key = self._generate_key(lens, topic, content)
        now = time.time()

        if key in self.map:
            node = self.map[key]
            node.val = transformed_text
            node.timestamp = now
            self._move_to_head(node)
            return

        if len(self.map) >= self.capacity:
            lru_node = self._pop_tail()
            if lru_node and lru_node.key in self.map:
                del self.map[lru_node.key]

        new_node = Node(key, transformed_text, now)
        self._add_node_to_head(new_node)
        self.map[key] = new_node

# Global singleton instance for the API server
lens_cache = LensLRUTTLCache(capacity=256, ttl_seconds=7200.0)
