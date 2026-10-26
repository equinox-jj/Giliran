// Package images checks uploaded images by their content and prepares them
// for storage. The type a client declares is never trusted.
package images

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/jpeg"
	_ "image/png" // register the PNG decoder
	"net/http"
	"slices"

	"github.com/disintegration/imaging"
	_ "golang.org/x/image/webp" // register the WebP decoder
)

// Upload types (payment_proofs.content_type CHECK).
const (
	JPEG = "image/jpeg"
	PNG  = "image/png"
	WebP = "image/webp"
)

// sniffLen is how many leading bytes http.DetectContentType reads.
const sniffLen = 512

// maxPixels bounds the decoded size, so a small file that declares huge
// dimensions cannot exhaust memory (about 160 MB of RGBA).
const maxPixels = 40_000_000

// AvatarSize is the longest side of a stored avatar, in pixels.
const AvatarSize = 512

const avatarQuality = 85

// ErrUnsupported means the data is not a JPEG, PNG or WebP image, or cannot
// be decoded as one.
var ErrUnsupported = errors.New("images: unsupported image")

// Sniff returns the content type of data from its leading bytes, or
// ErrUnsupported if it is not an allowed image type.
func Sniff(data []byte) (string, error) {
	ct := http.DetectContentType(data[:min(len(data), sniffLen)])
	if !slices.Contains([]string{JPEG, PNG, WebP}, ct) {
		return "", ErrUnsupported
	}
	return ct, nil
}

// Avatar decodes data (JPEG, PNG or WebP), applies its EXIF orientation,
// shrinks it to fit AvatarSize × AvatarSize without cropping or upscaling,
// and re-encodes it as JPEG. Re-encoding drops EXIF and any other metadata.
func Avatar(data []byte) ([]byte, error) {
	if _, err := Sniff(data); err != nil {
		return nil, err
	}
	cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUnsupported, err)
	}
	if cfg.Width <= 0 || cfg.Height <= 0 || cfg.Width*cfg.Height > maxPixels {
		return nil, fmt.Errorf("%w: %dx%d pixels", ErrUnsupported, cfg.Width, cfg.Height)
	}
	img, err := imaging.Decode(bytes.NewReader(data), imaging.AutoOrientation(true))
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrUnsupported, err)
	}
	b := img.Bounds()
	if b.Dx() > AvatarSize || b.Dy() > AvatarSize {
		img = imaging.Fit(img, AvatarSize, AvatarSize, imaging.Lanczos)
	}
	// JPEG has no alpha; put transparent pixels on white rather than black.
	flat := imaging.New(img.Bounds().Dx(), img.Bounds().Dy(), image.White)
	flat = imaging.Overlay(flat, img, image.Point{}, 1)
	var out bytes.Buffer
	if err := jpeg.Encode(&out, flat, &jpeg.Options{Quality: avatarQuality}); err != nil {
		return nil, fmt.Errorf("images: encode avatar: %w", err)
	}
	return out.Bytes(), nil
}
