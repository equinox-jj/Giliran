package images

import (
	"bytes"
	"errors"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"testing"
)

func encodePNG(t *testing.T, w, h int, c color.Color) []byte {
	t.Helper()
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := range h {
		for x := range w {
			img.Set(x, y, c)
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("png.Encode: %v", err)
	}
	return buf.Bytes()
}

func encodeJPEG(t *testing.T, w, h int) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, image.NewRGBA(image.Rect(0, 0, w, h)), nil); err != nil {
		t.Fatalf("jpeg.Encode: %v", err)
	}
	return buf.Bytes()
}

func decodeJPEG(t *testing.T, data []byte) image.Image {
	t.Helper()
	img, err := jpeg.Decode(bytes.NewReader(data))
	if err != nil {
		t.Fatalf("output is not a JPEG: %v", err)
	}
	return img
}

// pngHeader declares a w × h PNG without any pixel data.
func pngHeader(w, h uint32) []byte {
	b := []byte("\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR")
	b = append(b, byte(w>>24), byte(w>>16), byte(w>>8), byte(w), byte(h>>24), byte(h>>16), byte(h>>8), byte(h))
	return append(b, 8, 6, 0, 0, 0, 0, 0, 0, 0)
}

func TestSniff(t *testing.T) {
	// Arrange
	tests := []struct {
		name    string
		data    []byte
		want    string
		wantErr bool
	}{
		{"jpeg", encodeJPEG(t, 4, 4), JPEG, false},
		{"png", encodePNG(t, 4, 4, color.Black), PNG, false},
		{"webp", []byte("RIFF\x24\x00\x00\x00WEBPVP8 "), WebP, false},
		{"gif", []byte("GIF89a\x01\x00\x01\x00"), "", true},
		{"pdf named as jpeg", []byte("%PDF-1.7\n"), "", true},
		{"empty", nil, "", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			got, err := Sniff(tt.data)

			// Assert
			if got != tt.want || (err != nil) != tt.wantErr {
				t.Errorf("Sniff = %q, %v; want %q, error %v", got, err, tt.want, tt.wantErr)
			}
		})
	}
}

func TestAvatarShrinksToFit(t *testing.T) {
	// Arrange
	data := encodeJPEG(t, 2048, 1024)

	// Act
	out, err := Avatar(data)

	// Assert
	if err != nil {
		t.Fatalf("Avatar: %v", err)
	}
	if b := decodeJPEG(t, out).Bounds(); b.Dx() != 512 || b.Dy() != 256 {
		t.Errorf("size %dx%d, want 512x256", b.Dx(), b.Dy())
	}
}

func TestAvatarDoesNotUpscale(t *testing.T) {
	// Arrange
	data := encodePNG(t, 100, 80, color.Black)

	// Act
	out, err := Avatar(data)

	// Assert
	if err != nil {
		t.Fatalf("Avatar: %v", err)
	}
	if b := decodeJPEG(t, out).Bounds(); b.Dx() != 100 || b.Dy() != 80 {
		t.Errorf("size %dx%d, want 100x80", b.Dx(), b.Dy())
	}
}

func TestAvatarFlattensTransparencyOnWhite(t *testing.T) {
	// Arrange
	data := encodePNG(t, 8, 8, color.NRGBA{})

	// Act
	out, err := Avatar(data)

	// Assert
	if err != nil {
		t.Fatalf("Avatar: %v", err)
	}
	if r, g, b, _ := decodeJPEG(t, out).At(4, 4).RGBA(); r>>8 < 250 || g>>8 < 250 || b>>8 < 250 {
		t.Errorf("pixel %d,%d,%d, want white", r>>8, g>>8, b>>8)
	}
}

func TestAvatarRejects(t *testing.T) {
	// Arrange
	tests := []struct {
		name string
		data []byte
	}{
		{"not an image", []byte("hello, this is text")},
		{"truncated png", encodePNG(t, 64, 64, color.Black)[:60]},
		{"too many pixels", pngHeader(10_000, 10_000)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			_, err := Avatar(tt.data)

			// Assert
			if !errors.Is(err, ErrUnsupported) {
				t.Errorf("err %v, want ErrUnsupported", err)
			}
		})
	}
}
