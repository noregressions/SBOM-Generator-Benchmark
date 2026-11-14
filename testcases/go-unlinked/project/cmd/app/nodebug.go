//go:build !debug

package main

// debugDump does nothing in a release build. See debug.go.
func debugDump() {}
