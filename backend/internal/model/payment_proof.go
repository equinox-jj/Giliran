package model

import (
	"time"

	"github.com/google/uuid"
)

// MaxProofSizeBytes is the largest proof upload accepted (5 MB).
const MaxProofSizeBytes = 5 << 20

// ProofContentType is the image type of a proof upload, stored in
// payment_proofs.content_type.
type ProofContentType string

const (
	ProofContentTypeJPEG ProofContentType = "image/jpeg"
	ProofContentTypePNG  ProofContentType = "image/png"
	ProofContentTypeWebP ProofContentType = "image/webp"
)

// IsValid reports whether t is an accepted image type (the CHECK constraint).
func (t ProofContentType) IsValid() bool {
	switch t {
	case ProofContentTypeJPEG, ProofContentTypePNG, ProofContentTypeWebP:
		return true
	}
	return false
}

// PaymentProof is one uploaded transfer screenshot, mirroring the
// payment_proofs table (DB_SCHEME §3.10). Replaced proofs stay in history.
type PaymentProof struct {
	ID          uuid.UUID        `db:"id"`
	PaymentID   uuid.UUID        `db:"payment_id"`
	ObjectKey   string           `db:"object_key"` // MinIO object key
	ContentType ProofContentType `db:"content_type"`
	SizeBytes   int32            `db:"size_bytes"`  // at most MaxProofSizeBytes
	ImagePHash  *int64           `db:"image_phash"` // perceptual hash, for v3 duplicate detection
	UploadedBy  uuid.UUID        `db:"uploaded_by"`
	CreatedAt   time.Time        `db:"created_at"`
}
