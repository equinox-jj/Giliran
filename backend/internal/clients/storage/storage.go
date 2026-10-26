// Package storage keeps uploaded files (avatars, payment proofs, QRIS images)
// in a MinIO bucket. Objects are private; clients read them through
// short-lived presigned URLs.
package storage

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/url"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"github.com/equinox-jj/Giliran/backend/pkg/config"
)

// Storage is what services need from the object store.
type Storage interface {
	// Put stores size bytes from r under key.
	Put(ctx context.Context, key, contentType string, r io.Reader, size int64) error
	// Delete removes key. A missing key is not an error.
	Delete(ctx context.Context, key string) error
	// PresignGet returns a URL that downloads key until the presign TTL
	// passes.
	PresignGet(ctx context.Context, key string) (string, error)
}

// MinIO implements Storage. Uploads and deletes go to the internal endpoint;
// presigned URLs are signed for the public one, which is the host clients
// send them to.
type MinIO struct {
	internal *minio.Client
	public   *minio.Client
	bucket   string
	ttl      time.Duration
}

func NewMinIO(cfg config.MinIO) (*MinIO, error) {
	opts := func() *minio.Options {
		// A fixed region keeps presigning offline: no bucket-location lookup.
		return &minio.Options{
			Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
			Secure: cfg.UseSSL,
			Region: cfg.Region,
		}
	}
	internal, err := minio.New(cfg.Endpoint, opts())
	if err != nil {
		return nil, fmt.Errorf("storage: minio client: %w", err)
	}
	public := internal
	if cfg.PublicURL != "" {
		u, err := url.Parse(cfg.PublicURL)
		if err != nil {
			return nil, fmt.Errorf("storage: MINIO_PUBLIC_URL: %w", err)
		}
		o := opts()
		o.Secure = u.Scheme == "https"
		if public, err = minio.New(u.Host, o); err != nil {
			return nil, fmt.Errorf("storage: public minio client: %w", err)
		}
	}
	return &MinIO{internal: internal, public: public, bucket: cfg.Bucket, ttl: cfg.PresignTTL}, nil
}

func (m *MinIO) Put(ctx context.Context, key, contentType string, r io.Reader, size int64) error {
	_, err := m.internal.PutObject(ctx, m.bucket, key, r, size, minio.PutObjectOptions{ContentType: contentType})
	if err != nil {
		return fmt.Errorf("storage: put %s: %w", key, err)
	}
	return nil
}

func (m *MinIO) Delete(ctx context.Context, key string) error {
	err := m.internal.RemoveObject(ctx, m.bucket, key, minio.RemoveObjectOptions{})
	if err != nil && minio.ToErrorResponse(err).Code != minio.NoSuchKey {
		return fmt.Errorf("storage: delete %s: %w", key, err)
	}
	return nil
}

func (m *MinIO) PresignGet(ctx context.Context, key string) (string, error) {
	if key == "" {
		return "", errors.New("storage: presign: empty key")
	}
	u, err := m.public.PresignedGetObject(ctx, m.bucket, key, m.ttl, nil)
	if err != nil {
		return "", fmt.Errorf("storage: presign %s: %w", key, err)
	}
	return u.String(), nil
}
