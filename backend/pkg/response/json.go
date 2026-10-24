// Package response writes every HTTP response body: the {"data": ...}
// envelope for success and RFC 9457 problem+json for errors (PRD §11.6).
package response

import "github.com/gofiber/fiber/v3"

// envelope is the success body. Meta and Message are omitted when unset.
type envelope struct {
	Data    any    `json:"data"`
	Meta    any    `json:"meta,omitempty"`
	Message string `json:"message,omitempty"`
}

// CursorMeta is the meta of cursor-paginated lists such as the activity log.
type CursorMeta struct {
	NextCursor *string `json:"next_cursor"`
	HasMore    bool    `json:"has_more"`
}

// OK replies 200 with data in the envelope.
func OK(c fiber.Ctx, data any) error {
	return c.Status(fiber.StatusOK).JSON(envelope{Data: data})
}

// Created replies 201 with a Location header pointing at the new resource.
func Created(c fiber.Ctx, location string, data any) error {
	c.Set(fiber.HeaderLocation, location)
	return c.Status(fiber.StatusCreated).JSON(envelope{Data: data})
}

// NoContent replies 204 with no body.
func NoContent(c fiber.Ctx) error {
	return c.NoContent()
}

// List replies 200 with items and an optional meta. A nil slice is sent as
// [] so clients never see "data": null.
func List[T any](c fiber.Ctx, items []T, meta any) error {
	if items == nil {
		items = []T{}
	}
	return c.Status(fiber.StatusOK).JSON(envelope{Data: items, Meta: meta})
}
