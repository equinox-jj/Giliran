package security

import "testing"

func TestSHA256Hex(t *testing.T) {
	// Arrange
	const want = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" // FIPS 180-2 "abc"

	// Act
	got := SHA256Hex([]byte("abc"))

	// Assert
	if got != want {
		t.Errorf("got %s, want %s", got, want)
	}
}
