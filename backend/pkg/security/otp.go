package security

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"fmt"

	"github.com/google/uuid"
)

// OTPCodeLength is the number of digits in an email code.
const OTPCodeLength = 6

// The labels give OTP_SECRET two independent uses: deriving codes and hashing
// them for storage.
const (
	otpCodeLabel = "giliran-otp-code-v1"
	otpHashLabel = "giliran-otp-hash-v1"
)

// OTPCode derives the code for one send of an email_otp_requests row:
// HMAC-SHA256(secret, label ‖ 0x00 ‖ id ‖ uint32_be(resendCount)), then
// uint64_be(mac[0:8]) mod 10^6, zero-padded. The API stores only its hash and
// the worker derives it again to email it, so the code is never stored. The
// modulo bias is about 10^-13.
func OTPCode(secret []byte, otpID uuid.UUID, resendCount int) string {
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(otpCodeLabel))
	mac.Write([]byte{0})
	mac.Write(otpID[:])
	mac.Write(binary.BigEndian.AppendUint32(nil, uint32(resendCount))) //nolint:gosec // resend_count is 0..OTP_MAX_RESENDS
	sum := mac.Sum(nil)
	return fmt.Sprintf("%0*d", OTPCodeLength, binary.BigEndian.Uint64(sum[:8])%1_000_000)
}

// OTPCodeHash is the stored email_otp_requests.code_hash: the lowercase hex
// HMAC-SHA256(secret, label ‖ 0x00 ‖ id ‖ code).
func OTPCodeHash(secret []byte, otpID uuid.UUID, code string) string {
	return hex.EncodeToString(otpCodeMAC(secret, otpID, code))
}

// OTPCodeMatches reports in constant time whether code hashes to storedHash.
func OTPCodeMatches(secret []byte, otpID uuid.UUID, code, storedHash string) bool {
	stored, err := hex.DecodeString(storedHash)
	if err != nil || len(stored) != sha256.Size {
		return false
	}
	return hmac.Equal(otpCodeMAC(secret, otpID, code), stored)
}

func otpCodeMAC(secret []byte, otpID uuid.UUID, code string) []byte {
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(otpHashLabel))
	mac.Write([]byte{0})
	mac.Write(otpID[:])
	mac.Write([]byte(code))
	return mac.Sum(nil)
}
