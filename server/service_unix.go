// +build !windows

package server

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
)

// setupShutdownHandler sets up signal handlers for Unix-like systems
func setupShutdownHandler(ctx context.Context, shutdownFn func()) {
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM)
	
	go func() {
		select {
		case sig := <-signals:
			slog.Info("received shutdown signal", "signal", sig)
			shutdownFn()
		case <-ctx.Done():
			return
		}
	}()
}
