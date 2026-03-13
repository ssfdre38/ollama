// +build windows

package server

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"golang.org/x/sys/windows/svc"
)

// isWindowsService returns true if the process is running as a Windows service
func isWindowsService() bool {
	isService, err := svc.IsWindowsService()
	if err != nil {
		return false
	}
	return isService
}

// setupShutdownHandler sets up signal handlers for both interactive and service modes
func setupShutdownHandler(ctx context.Context, shutdownFn func()) {
	if isWindowsService() {
		// Running as Windows Service - use service control handler
		go runServiceControlHandler(ctx, shutdownFn)
	} else {
		// Running interactively - use signal handler
		setupSignalHandler(ctx, shutdownFn)
	}
}

// runServiceControlHandler handles Windows Service Control Manager signals
func runServiceControlHandler(ctx context.Context, shutdownFn func()) {
	// This is a simplified handler - for full service support, would need
	// to implement svc.Handler interface
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	
	select {
	case sig := <-signals:
		slog.Info("received shutdown signal", "signal", sig)
		shutdownFn()
	case <-ctx.Done():
		return
	}
}

// setupSignalHandler sets up SIGINT/SIGTERM handlers for interactive mode
func setupSignalHandler(ctx context.Context, shutdownFn func()) {
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
