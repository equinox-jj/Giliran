//go:build integration

package storage

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/minio/minio-go/v7"
	tcminio "github.com/testcontainers/testcontainers-go/modules/minio"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// minioImage matches deploy/docker-compose.*.yml.
const minioImage = "pgsty/minio:RELEASE.2026-08-04T00-00-00Z"

// newTestMinIO starts MinIO with an empty bucket and returns its config.
func newTestMinIO(t *testing.T) config.MinIO {
	t.Helper()
	ctx := context.Background()
	ctr, err := tcminio.Run(ctx, minioImage)
	if err != nil {
		t.Fatalf("start minio: %v", err)
	}
	t.Cleanup(func() { _ = ctr.Terminate(context.Background()) })
	endpoint, err := ctr.ConnectionString(ctx)
	if err != nil {
		t.Fatalf("minio endpoint: %v", err)
	}
	cfg := config.MinIO{
		Endpoint: endpoint, AccessKey: ctr.Username, SecretKey: ctr.Password,
		Region: "us-east-1", Bucket: "giliran-test", PresignTTL: time.Minute,
	}
	m, err := NewMinIO(cfg)
	if err != nil {
		t.Fatalf("NewMinIO: %v", err)
	}
	if err := m.internal.MakeBucket(ctx, cfg.Bucket, minio.MakeBucketOptions{Region: cfg.Region}); err != nil {
		t.Fatalf("make bucket: %v", err)
	}
	return cfg
}

func TestMinIOPutPresignDelete(t *testing.T) {
	// Arrange
	cfg := newTestMinIO(t)
	m, err := NewMinIO(cfg)
	if err != nil {
		t.Fatalf("NewMinIO: %v", err)
	}
	ctx := context.Background()
	data := []byte("avatar bytes")
	if err := m.Put(ctx, "avatars/u/1.jpg", "image/jpeg", bytes.NewReader(data), int64(len(data))); err != nil {
		t.Fatalf("Put: %v", err)
	}

	t.Run("presigned url downloads the object", func(t *testing.T) {
		// Act
		u, err := m.PresignGet(ctx, "avatars/u/1.jpg")

		// Assert
		if err != nil {
			t.Fatalf("PresignGet: %v", err)
		}
		resp, err := http.Get(u)
		if err != nil {
			t.Fatalf("GET: %v", err)
		}
		defer resp.Body.Close()
		got, _ := io.ReadAll(resp.Body)
		if resp.StatusCode != 200 || !bytes.Equal(got, data) || resp.Header.Get("Content-Type") != "image/jpeg" {
			t.Errorf("status %d type %q body %q", resp.StatusCode, resp.Header.Get("Content-Type"), got)
		}
	})

	t.Run("delete removes the object", func(t *testing.T) {
		// Act
		err := m.Delete(ctx, "avatars/u/1.jpg")

		// Assert
		if err != nil {
			t.Fatalf("Delete: %v", err)
		}
		if _, err := m.internal.StatObject(ctx, cfg.Bucket, "avatars/u/1.jpg", minio.StatObjectOptions{}); err == nil {
			t.Error("object still exists")
		}
	})

	t.Run("deleting a missing key is not an error", func(t *testing.T) {
		// Act
		err := m.Delete(ctx, "avatars/u/missing.jpg")

		// Assert
		if err != nil {
			t.Errorf("Delete: %v", err)
		}
	})
}

func TestMinIOPresignUsesPublicURL(t *testing.T) {
	// Arrange
	cfg := config.MinIO{
		Endpoint: "minio:9000", PublicURL: "https://files.example.com", AccessKey: "k", SecretKey: "secret-key",
		Region: "us-east-1", Bucket: "giliran", PresignTTL: time.Minute,
	}
	m, err := NewMinIO(cfg)
	if err != nil {
		t.Fatalf("NewMinIO: %v", err)
	}

	// Act
	raw, err := m.PresignGet(context.Background(), "avatars/u/1.jpg")

	// Assert
	if err != nil {
		t.Fatalf("PresignGet: %v", err)
	}
	u, _ := url.Parse(raw)
	if u.Scheme != "https" || u.Host != "files.example.com" || !strings.HasSuffix(u.Path, "/giliran/avatars/u/1.jpg") {
		t.Errorf("presigned %s", raw)
	}
}
