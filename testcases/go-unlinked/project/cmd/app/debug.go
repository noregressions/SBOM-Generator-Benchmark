//go:build debug

package main

import (
	"fmt"
	"os"

	jwt "github.com/dgrijalva/jwt-go"
)

// debugDump prints the claims of the token in DEBUG_TOKEN without verifying it. It exists only in builds made with
// `-tags debug`, so the release binary does not contain jwt-go at all.
func debugDump() {
	raw := os.Getenv("DEBUG_TOKEN")
	if raw == "" {
		return
	}
	claims := jwt.MapClaims{}
	if _, _, err := new(jwt.Parser).ParseUnverified(raw, claims); err != nil {
		fmt.Println("debug: token not readable:", err)
		return
	}
	fmt.Println("debug: claims", claims)
}
