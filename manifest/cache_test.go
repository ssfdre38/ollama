package manifest

import (
	"testing"
	"time"

	"github.com/ollama/ollama/types/model"
)

func TestManifestCache_Basics(t *testing.T) {
	cache := NewManifestCache(5 * time.Second)

	// First call should load from disk
	manifests1, err := cache.Get(true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Second call should return cached (same pointer)
	manifests2, err := cache.Get(true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Should be the same map (pointer equality)
	if &manifests1 != &manifests2 {
		t.Error("expected cache to return same map instance")
	}
}

func TestManifestCache_Invalidation(t *testing.T) {
	cache := NewManifestCache(0) // Never expire

	// Load once
	version1 := cache.Version()
	_, err := cache.Get(true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Invalidate
	cache.Invalidate()
	version2 := cache.Version()

	if version2 <= version1 {
		t.Errorf("expected version to increment after invalidation: %d -> %d", version1, version2)
	}

	// Next Get should reload from disk
	_, err = cache.Get(true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestManifestCache_TTL(t *testing.T) {
	cache := NewManifestCache(100 * time.Millisecond)

	// Load once
	manifests1, err := cache.Get(true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Should still be cached
	manifests2, err := cache.Get(true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if &manifests1 != &manifests2 {
		t.Error("expected cache to still be valid")
	}

	// Wait for TTL to expire
	time.Sleep(150 * time.Millisecond)

	// Should reload (note: can't test pointer inequality since
	// the new load might have identical content)
	_, err = cache.Get(true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestManifestCache_ConcurrentAccess(t *testing.T) {
	cache := NewManifestCache(0)

	// Simulate concurrent access
	done := make(chan bool)
	for i := 0; i < 10; i++ {
		go func() {
			for j := 0; j < 100; j++ {
				cache.Get(true)
				if j%10 == 0 {
					cache.Invalidate()
				}
			}
			done <- true
		}()
	}

	// Wait for all goroutines
	for i := 0; i < 10; i++ {
		<-done
	}

	// Should not panic or deadlock
	_, err := cache.Get(true)
	if err != nil {
		t.Fatalf("unexpected error after concurrent access: %v", err)
	}
}
