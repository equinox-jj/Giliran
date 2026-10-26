package controller

import (
	"io"
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/model"
)

// pathID parses the UUID path parameter name. A malformed ID cannot name an
// existing resource, so it gets notFound like an unknown one.
func pathID(c fiber.Ctx, name string, notFound *model.Error) (uuid.UUID, error) {
	id, err := uuid.Parse(c.Params(name))
	if err != nil {
		return uuid.Nil, notFound
	}
	return id, nil
}

// groupID parses the group_id path parameter.
func groupID(c fiber.Ctx) (uuid.UUID, error) {
	return pathID(c, "group_id", model.ErrGroupNotFound)
}

// periodID parses the period_id path parameter.
func periodID(c fiber.Ctx) (uuid.UUID, error) {
	return pathID(c, "period_id", model.ErrPeriodNotFound)
}

// paymentID parses the payment_id path parameter.
func paymentID(c fiber.Ctx) (uuid.UUID, error) {
	return pathID(c, "payment_id", model.ErrPaymentNotFound)
}

// readUpload reads the multipart field "file". Services check the type by
// content; the declared type is ignored.
func readUpload(c fiber.Ctx) ([]byte, error) {
	if !strings.HasPrefix(string(c.Request().Header.ContentType()), fiber.MIMEMultipartForm) {
		return nil, model.ErrUnsupportedMediaType.WithDetail("Send the image as multipart/form-data in the field \"file\".")
	}
	fh, err := c.FormFile("file")
	if err != nil {
		return nil, model.NewValidationError(model.FieldError{Field: "file", Code: model.FieldRequired, Message: "This field is required."})
	}
	f, err := fh.Open()
	if err != nil {
		return nil, err
	}
	defer f.Close()
	// The body limit (at least UPLOAD_MAX_BYTES) bounds this read.
	return io.ReadAll(f)
}

// bindOptional binds a request body the spec marks optional; an empty body
// leaves out at its zero value.
func bindOptional(c fiber.Ctx, out any) error {
	if len(c.Body()) == 0 {
		return nil
	}
	return c.Bind().Body(out)
}
