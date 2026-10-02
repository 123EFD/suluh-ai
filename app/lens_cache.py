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
    
    def get(self, lens: str, topic: str, content: str) -> Optional[str]:

        key = self._generate_key(lens, topic, content)
        if key not in self.map:
            return None
        
        if time.time() - self.map[key].timestamp > self.ttl:
            # Expired: remove from list and map
            node = self.map[key]
            previous = node.prev
            following = node.next
            if previous is None or following is None:
                del self.map[key]
                return None
            previous.next = following
            following.prev = previous
            del self.map[key]
            return None
        
        # Promote the node to the head of the list
        node = self.map[key]
        previous = node.prev
        following = node.next
        if previous is None or following is None:
            return None
        previous.next = following
        following.prev = previous
        node.next = self.head
        node.prev = None
        self.head.prev = node
        self.head = node

        return node.val

    def put(self, lens: str, topic: str, content: str, transformed_text: str) -> None:
        key = self._generate_key(lens, topic, content)
        if key in self.map:
            node = self.map[key]
            node.val = transformed_text
            node.timestamp = time.time()
            prev = node.prev
            next = node.next
            if prev is None or next is None:
                return None
            node.next = self.head
            node.prev = None
            self.head.prev = node
            self.head = node    
        if len(self.map) >= self.capacity:
            lru_node = self.tail.prev
            if lru_node is not None and lru_node.prev is not None:
                lru_node.prev.next = self.tail
                self.tail.prev = lru_node.prev
                del self.map[lru_node.key]
        # Create a new node and add it to the cache
        new_node = Node(key, transformed_text, time.time())
        new_node.next = self.head
        new_node.prev = None
        self.head.prev = new_node
        self.head = new_node
        self.map[key] = new_node

# Global singleton instance for the API server
lens_cache = LensLRUTTLCache(capacity=256, ttl_seconds=7200.0)
