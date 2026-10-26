// Package qris reads QRIS payment codes: it finds the QR code in an image and
// checks that its payload is a well-formed EMV merchant-presented code (TLV
// structure and CRC-16/CCITT-FALSE checksum), as FR-GRP-03 requires before
// the code is saved.
package qris

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	_ "image/jpeg" // register the JPEG decoder
	_ "image/png"  // register the PNG decoder
	"strconv"
	"strings"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/qrcode"
	_ "golang.org/x/image/webp" // register the WebP decoder
)

// EMV tags the parser checks.
const (
	tagFormatIndicator = "00"
	tagMerchantName    = "59"
	tagCRC             = "63"
)

// MaxPayloadLength bounds a payload; EMV codes are far shorter.
const MaxPayloadLength = 512

// maxPixels bounds the decoded image, as in pkg/images.
const maxPixels = 40_000_000

var (
	// ErrNoCode means the image has no readable QR code.
	ErrNoCode = errors.New("qris: no QR code found")
	// ErrInvalid means the payload is not a valid QRIS code.
	ErrInvalid = errors.New("qris: invalid payload")
)

// Payload is a validated QRIS code.
type Payload struct {
	Raw string
	// Fields maps each top-level EMV tag to its value. Nested templates
	// (merchant account information, additional data) stay unparsed.
	Fields map[string]string
}

// MerchantName returns tag 59, the merchant name shown to payers.
func (p Payload) MerchantName() string {
	return p.Fields[tagMerchantName]
}

// Decode finds a QR code in a JPEG, PNG or WebP image and returns its text.
func Decode(data []byte) (string, error) {
	cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return "", fmt.Errorf("%w: %w", ErrNoCode, err)
	}
	if cfg.Width <= 0 || cfg.Height <= 0 || cfg.Width*cfg.Height > maxPixels {
		return "", fmt.Errorf("%w: %dx%d pixels", ErrNoCode, cfg.Width, cfg.Height)
	}
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return "", fmt.Errorf("%w: %w", ErrNoCode, err)
	}
	bmp, err := gozxing.NewBinaryBitmapFromImage(img)
	if err != nil {
		return "", fmt.Errorf("%w: %w", ErrNoCode, err)
	}
	res, err := qrcode.NewQRCodeReader().Decode(bmp, map[gozxing.DecodeHintType]any{
		gozxing.DecodeHintType_TRY_HARDER: true,
	})
	if err != nil {
		return "", fmt.Errorf("%w: %w", ErrNoCode, err)
	}
	return res.GetText(), nil
}

// Parse checks raw as an EMV merchant-presented code: a sequence of
// tag (2 digits), length (2 digits) and value fields that starts with the
// payload format indicator 00 = "01", carries a merchant name (59) and ends
// with a 4-hex-digit CRC (63) over everything before it.
func Parse(raw string) (Payload, error) {
	if raw == "" || len(raw) > MaxPayloadLength {
		return Payload{}, fmt.Errorf("%w: length %d", ErrInvalid, len(raw))
	}
	fields := map[string]string{}
	var tags []string
	for i := 0; i < len(raw); {
		if i+4 > len(raw) {
			return Payload{}, fmt.Errorf("%w: truncated field at %d", ErrInvalid, i)
		}
		tag, lenStr := raw[i:i+2], raw[i+2:i+4]
		if !isDigits(tag) || !isDigits(lenStr) {
			return Payload{}, fmt.Errorf("%w: bad tag or length at %d", ErrInvalid, i)
		}
		n, _ := strconv.Atoi(lenStr)
		if n == 0 || i+4+n > len(raw) {
			return Payload{}, fmt.Errorf("%w: field %s overruns the payload", ErrInvalid, tag)
		}
		if _, dup := fields[tag]; dup {
			return Payload{}, fmt.Errorf("%w: duplicate tag %s", ErrInvalid, tag)
		}
		fields[tag] = raw[i+4 : i+4+n]
		tags = append(tags, tag)
		i += 4 + n
	}

	if tags[0] != tagFormatIndicator || fields[tagFormatIndicator] != "01" {
		return Payload{}, fmt.Errorf("%w: must start with 000201", ErrInvalid)
	}
	if tags[len(tags)-1] != tagCRC || len(fields[tagCRC]) != 4 {
		return Payload{}, fmt.Errorf("%w: must end with a 4-digit CRC (63)", ErrInvalid)
	}
	if strings.TrimSpace(fields[tagMerchantName]) == "" {
		return Payload{}, fmt.Errorf("%w: missing merchant name (59)", ErrInvalid)
	}
	// The checksum covers the payload up to and including "6304".
	body := raw[:len(raw)-4]
	if want := fmt.Sprintf("%04X", CRC16(body)); !strings.EqualFold(fields[tagCRC], want) {
		return Payload{}, fmt.Errorf("%w: CRC %s, want %s", ErrInvalid, fields[tagCRC], want)
	}
	return Payload{Raw: raw, Fields: fields}, nil
}

// CRC16 is CRC-16/CCITT-FALSE: polynomial 0x1021, initial value 0xFFFF, no
// reflection, no final XOR.
func CRC16(s string) uint16 {
	crc := uint16(0xFFFF)
	for i := 0; i < len(s); i++ {
		crc ^= uint16(s[i]) << 8
		for range 8 {
			if crc&0x8000 != 0 {
				crc = crc<<1 ^ 0x1021
			} else {
				crc <<= 1
			}
		}
	}
	return crc
}

func isDigits(s string) bool {
	for i := 0; i < len(s); i++ {
		if s[i] < '0' || s[i] > '9' {
			return false
		}
	}
	return true
}
