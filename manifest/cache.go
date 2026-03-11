package manifest

import (
	"sync"
	"sync/atomic"
	"time"

	"github.com/ollama/ollama/types/model"
)

// ManifestCache provides a thread-safe cached view of manifests with
// invalidation support to avoid repeated filesystem scans.
type ManifestCache struct {
	mu        sync.RWMutex
	manifests map[model.Name]*Manifest
	lastSync  time.Time
	version   int64
	ttl       time.Duration
}

// NewManifestCache creates a new manifest cache with the specified TTL.
// A TTL of 0 means cache never expires (must be manually invalidated).
func NewManifestCache(ttl time.Duration) *ManifestCache {
	return &ManifestCache{
		ttl: ttl,
	}
}

// Get returns the cached manifests, refreshing from disk if cache is invalid.
func (c *ManifestCache) Get(continueOnError bool) (map[model.Name]*Manifest, error) {
	// Fast path: check if cache is still valid (read lock only)
	c.mu.RLock()
	if c.isValid() {
		manifests := c.manifests
		c.mu.RUnlock()
		return manifests, nil
	}
	c.mu.RUnlock()

	// Slow path: refresh cache (write lock required)
	c.mu.Lock()
	defer c.mu.Unlock()

	// Double-check after acquiring write lock (another goroutine may have refreshed)
	if c.isValid() {
		return c.manifests, nil
	}

	// Refresh from filesystem
	manifests, err := loadManifestsFromDisk(continueOnError)
	if err != nil {
		return nil, err
	}

	c.manifests = manifests
	c.lastSync = time.Now()
	return manifests, nil
}

// isValid checks if the cache is still valid (must be called with at least read lock)
func (c *ManifestCache) isValid() bool {
	if c.manifests == nil {
		return false
	}
	if c.ttl == 0 {
		return true
	}
	return time.Since(c.lastSync) < c.ttl
}

// Invalidate marks the cache as invalid, forcing a refresh on next Get().
func (c *ManifestCache) Invalidate() {
	c.mu.Lock()
	defer c.mu.Unlock()
	
	c.manifests = nil
	c.lastSync = time.Time{}
	atomic.AddInt64(&c.version, 1)
}

// Version returns the current cache version, incremented on each invalidation.
// Can be used by clients to detect when cache has been refreshed.
func (c *ManifestCache) Version() int64 {
	return atomic.LoadInt64(&c.version)
}

// Global cache instance used by the server
var globalCache = NewManifestCache(0) // Never expire, manual invalidation only

// GetGlobalCache returns the global manifest cache instance.
func GetGlobalCache() *ManifestCache {
	return globalCache
}

// InvalidateGlobalCache invalidates the global manifest cache.
// Call this after pull/push/delete operations to ensure /api/tags returns fresh data.
func InvalidateGlobalCache() {
	globalCache.Invalidate()
}

// loadManifestsFromDisk is the original Manifests() implementation
func loadManifestsFromDisk(continueOnError bool) (map[model.Name]*Manifest, error) {
	// This calls the original implementation
	return manifestsFromDisk(continueOnError)
}
