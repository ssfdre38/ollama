# Ollama Timing Issue - Root Cause Analysis

## The Problem Located! 🎯

Found the race condition in `manifest/manifest.go`:

### Current Implementation (Lines 175-240)
```go
func Manifests(continueOnError bool) (map[model.Name]*Manifest, error) {
    // Uses filepath.Glob() to scan filesystem
    matches, err := filepath.Glob(filepath.Join(manifests, "*", "*", "*", "*"))
    
    // Then reads each file individually
    for _, path := range matches {
        // Read file
        // Parse JSON
        // Build manifest map
    }
}
```

## The Race Conditions:

### 1. **No Caching** ❌
- Every call to `/api/tags` scans the entire filesystem
- No in-memory cache of manifests
- Multiple concurrent requests = multiple filesystem scans

### 2. **No Locking** ❌
- `Manifests()` function has NO mutex protection
- While one request is reading, another can be modifying
- No synchronization between pull/delete operations and list operations

### 3. **Stale Data Window** ❌
- Time between filesystem scan and response = stale data window
- If model is pulled/deleted during this window, inconsistent state
- `ollama list` vs `/api/tags` discrepancy explained!

### 4. **File I/O on Every Request** ❌
- Opens and reads every manifest file on every `/api/tags` call
- Slow + prone to timing issues
- No incremental updates

## The Fix Strategy:

### Phase 1: Add In-Memory Cache with Mutex
```go
type ManifestCache struct {
    mu        sync.RWMutex
    manifests map[model.Name]*Manifest
    lastSync  time.Time
    version   int64  // Increment on any change
}

func (c *ManifestCache) Get() (map[model.Name]*Manifest, error) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    // Return cached copy
}

func (c *ManifestCache) Invalidate() {
    c.mu.Lock()
    defer c.mu.Unlock()
    atomic.AddInt64(&c.version, 1)
    c.manifests = nil
    c.lastSync = time.Time{}
}
```

### Phase 2: Invalidate on Mutations
- Call `Invalidate()` after:
  - `ollama pull` completes
  - `ollama rm` completes
  - Manifest files created/deleted

### Phase 3: Background Refresh
```go
func (c *ManifestCache) StartWatcher() {
    // Use fsnotify to watch manifest directory
    // Invalidate cache on file changes
    // Refresh cache in background
}
```

### Phase 4: Registry Version Tracking
- Add version/timestamp to API responses
- Clients can detect stale cache
- Retry with cache-busting if needed

## Files to Modify:

1. **manifest/manifest.go**
   - Add `ManifestCache` struct
   - Replace `Manifests()` with cached version
   - Add invalidation hooks

2. **server/routes.go**
   - Initialize cache on server start
   - Use cached `Manifests()` in `ListHandler()`

3. **API handlers (pull/push/delete)**
   - Call cache invalidation after operations

4. **Tests**
   - Add race condition tests
   - Test concurrent pull + list
   - Test cache invalidation

## Expected Results:
- ✅ `/api/tags` returns consistent data
- ✅ Fast response (no filesystem scan)
- ✅ Proper synchronization between operations
- ✅ Auto-refresh on changes
- ✅ No more stale CLI vs API discrepancies
