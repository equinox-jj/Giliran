package qris

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/png"
	"strings"
	"testing"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/qrcode"
)

// tlv encodes one EMV field.
func tlv(tag, value string) string {
	return fmt.Sprintf("%s%02d%s", tag, len(value), value)
}

// withCRC appends tag 63 with the checksum over body and "6304".
func withCRC(body string) string {
	body += "6304"
	return body + fmt.Sprintf("%04X", CRC16(body))
}

// validBody is a static QRIS code without its CRC field.
var validBody = tlv("00", "01") + tlv("01", "11") +
	tlv("26", tlv("00", "ID.CO.QRIS.WWW")+tlv("01", "936009140000000000")) +
	tlv("52", "5812") + tlv("53", "360") + tlv("58", "ID") +
	tlv("59", "WARUNG BU RINA") + tlv("60", "JAKARTA")

func TestCRC16CheckValue(t *testing.T) {
	// Act
	got := CRC16("123456789")

	// Assert
	// The published check value of CRC-16/CCITT-FALSE.
	if got != 0x29B1 {
		t.Errorf("CRC16 = %04X, want 29B1", got)
	}
}

func TestCRC16Empty(t *testing.T) {
	// Act
	got := CRC16("")

	// Assert
	if got != 0xFFFF {
		t.Errorf("CRC16(\"\") = %04X, want the initial value FFFF", got)
	}
}

func TestParseValid(t *testing.T) {
	// Arrange
	raw := withCRC(validBody)

	// Act
	p, err := Parse(raw)

	// Assert
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	if p.Raw != raw || p.MerchantName() != "WARUNG BU RINA" || p.Fields["58"] != "ID" {
		t.Errorf("payload %+v", p)
	}
	if _, nested := p.Fields["00"]; !nested || len(p.Fields) != 9 {
		t.Errorf("fields %v, want the 9 top-level tags", p.Fields)
	}
}

func TestParseAcceptsLowercaseCRC(t *testing.T) {
	// Arrange
	raw := withCRC(validBody)
	raw = raw[:len(raw)-4] + strings.ToLower(raw[len(raw)-4:])

	// Act
	_, err := Parse(raw)

	// Assert
	if err != nil {
		t.Errorf("Parse: %v", err)
	}
}

func TestParseInvalid(t *testing.T) {
	// Arrange
	valid := withCRC(validBody)
	last := "0"
	if valid[len(valid)-1] == '0' {
		last = "1"
	}
	flipped := valid[:len(valid)-1] + last
	tests := []struct {
		name string
		raw  string
	}{
		{"empty", ""},
		{"too long", withCRC(validBody + tlv("62", strings.Repeat("x", 99)) + strings.Repeat(tlv("80", strings.Repeat("y", 90)), 5))},
		{"truncated header", valid + "62"},
		{"non-digit tag", withCRC("0A0201" + validBody[6:])},
		{"non-digit length", withCRC("00X201" + validBody[6:])},
		{"zero length", withCRC(validBody + "6200")},
		{"field overruns payload", validBody + "6304"},
		{"duplicate tag", withCRC(validBody + tlv("58", "ID"))},
		{"wrong format indicator", withCRC(tlv("00", "02") + validBody[6:])},
		{"format indicator not first", withCRC(tlv("01", "11") + tlv("00", "01") + validBody[12:])},
		{"no CRC", validBody},
		{"CRC not last", withCRC(validBody)[:len(valid)] + tlv("64", "ID")},
		{"short CRC", validBody + tlv("63", "ABC")},
		{"missing merchant name", withCRC(strings.Replace(validBody, tlv("59", "WARUNG BU RINA"), "", 1))},
		{"blank merchant name", withCRC(strings.Replace(validBody, tlv("59", "WARUNG BU RINA"), tlv("59", "   "), 1))},
		{"wrong CRC", flipped},
		{"tampered body", strings.Replace(valid, "RINA", "BUDI", 1)},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := Parse(tt.raw)

			// Assert
			if !errors.Is(err, ErrInvalid) {
				t.Errorf("Parse(%q) error %v, want ErrInvalid", tt.raw, err)
			}
		})
	}
}

// qrPNG renders text as a QR code PNG.
func qrPNG(t *testing.T, text string) []byte {
	t.Helper()
	m, err := qrcode.NewQRCodeWriter().Encode(text, gozxing.BarcodeFormat_QR_CODE, 300, 300, nil)
	if err != nil {
		t.Fatalf("Encode: %v", err)
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, m); err != nil {
		t.Fatalf("png.Encode: %v", err)
	}
	return buf.Bytes()
}

func TestDecodeReadsQRCode(t *testing.T) {
	// Arrange
	raw := withCRC(validBody)
	data := qrPNG(t, raw)

	// Act
	got, err := Decode(data)

	// Assert
	if err != nil || got != raw {
		t.Fatalf("Decode = %q, %v; want %q", got, err, raw)
	}
}

func TestDecodeErrors(t *testing.T) {
	// Arrange
	var blank bytes.Buffer
	if err := png.Encode(&blank, image.NewGray(image.Rect(0, 0, 200, 200))); err != nil {
		t.Fatalf("png.Encode: %v", err)
	}
	tests := []struct {
		name string
		data []byte
	}{
		{"not an image", []byte("definitely not an image")},
		{"image without a code", blank.Bytes()},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := Decode(tt.data)

			// Assert
			if !errors.Is(err, ErrNoCode) {
				t.Errorf("Decode error %v, want ErrNoCode", err)
			}
		})
	}
}
