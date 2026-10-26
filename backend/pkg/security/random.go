package security

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
)

// codeAlphabet matches the [A-Z0-9] CHECK on invite and verification codes.
const codeAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

// RandomToken returns n random bytes as unpadded URL-safe base64. Use 32 bytes
// for refresh and claim tokens; store only their SHA256Hex.
func RandomToken(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("security: read token: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

// RandomCode returns n characters drawn uniformly from [A-Z0-9], for invite
// codes (8) and draw verification codes (10).
func RandomCode(n int) (string, error) {
	// 252 is the largest multiple of 36 below 256; rejecting bytes at or above
	// it keeps every character equally likely.
	const limit = 256 - 256%len(codeAlphabet)
	out := make([]byte, 0, n)
	buf := make([]byte, n)
	for len(out) < n {
		if _, err := rand.Read(buf); err != nil {
			return "", fmt.Errorf("security: read code: %w", err)
		}
		for _, b := range buf {
			if int(b) < limit && len(out) < n {
				out = append(out, codeAlphabet[int(b)%len(codeAlphabet)])
			}
		}
	}
	return string(out), nil
}
