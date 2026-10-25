package security

import (
	"crypto/sha256"
	"encoding/hex"
)

// SHA256Hex is the lowercase hex SHA-256 of b. It is the stored form of
// refresh and claim tokens, the draw seed_hash and the idempotency
// request_hash.
func SHA256Hex(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}
