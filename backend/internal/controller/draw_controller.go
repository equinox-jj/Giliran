package controller

import (
	"bytes"
	"context"
	"errors"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/dto"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/internal/web"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
)

// DrawService is what DrawController needs from service.DrawService.
type DrawService interface {
	Get(ctx context.Context, groupID, periodID, userID uuid.UUID) (service.DrawView, error)
	Run(ctx context.Context, groupID, periodID, userID uuid.UUID, confirmIncomplete bool) (service.DrawView, error)
	Public(ctx context.Context, code string) (service.PublicDraw, error)
}

// DrawController serves a period's draw and the public verification of a
// drawn period. The group routes are behind middleware.Auth and the draw
// itself behind Idempotency; the public ones need no account.
type DrawController struct {
	draws DrawService
}

func NewDrawController(draws *service.DrawService) *DrawController {
	return &DrawController{draws: draws}
}

// Get handles GET /groups/{group_id}/periods/{period_id}/draw.
func (h *DrawController) Get(c fiber.Ctx) error {
	gid, pid, err := periodPath(c)
	if err != nil {
		return err
	}
	v, err := h.draws.Get(c.Context(), gid, pid, middleware.UserID(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewDraw(v))
}

// Run handles POST /groups/{group_id}/periods/{period_id}/draw.
func (h *DrawController) Run(c fiber.Ctx) error {
	gid, pid, err := periodPath(c)
	if err != nil {
		return err
	}
	var req dto.RunDrawRequest
	if err := bindOptional(c, &req); err != nil {
		return err
	}
	v, err := h.draws.Run(c.Context(), gid, pid, middleware.UserID(c), req.ConfirmIncomplete)
	if err != nil {
		return err
	}
	return response.Created(c, "/api/v1/groups/"+gid.String()+"/periods/"+pid.String()+"/draw", dto.NewDraw(v))
}

// Public handles GET /public/draws/{verification_code}.
func (h *DrawController) Public(c fiber.Ctx) error {
	code, err := verificationCode(c)
	if err != nil {
		return err
	}
	d, err := h.draws.Public(c.Context(), code)
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewPublicDraw(d))
}

// Page handles GET /v/{verification_code}, the Bukti Kocok page a shared
// result card links to. It shows the same data as Public.
func (h *DrawController) Page(c fiber.Ctx) error {
	var buf bytes.Buffer
	code, err := verificationCode(c)
	if err == nil {
		var d service.PublicDraw
		if d, err = h.draws.Public(c.Context(), code); err == nil {
			err = web.RenderDraw(&buf, drawPage(d))
		}
	}
	if errors.Is(err, model.ErrDrawNotFound) {
		buf.Reset()
		if err := web.RenderDrawNotFound(&buf); err != nil {
			return err
		}
		c.Status(fiber.StatusNotFound)
	} else if err != nil {
		return err
	}
	c.Set(fiber.HeaderContentType, fiber.MIMETextHTMLCharsetUTF8)
	return c.Send(buf.Bytes())
}

func drawPage(d service.PublicDraw) web.DrawPage {
	p := web.DrawPage{
		GroupName: d.GroupName, PeriodNo: d.PeriodNo, TotalPeriods: d.TotalPeriods, PeriodID: d.PeriodID.String(),
		Algorithm: d.Algorithm, IsRandom: d.Algorithm == model.DrawAlgorithmHMACSHA256V1,
		SeedHashPublishedAt: d.SeedHashPublishedAt, DrawnAt: d.DrawnAt,
		HashMatches: d.HashMatches, WinnerMatches: d.WinnerMatches,
		Winner:  web.DrawSlot{SlotNo: d.Winner.SlotNo, DisplayName: d.Winner.DisplayName, SlotID: d.Winner.SlotID.String(), IsWinner: true},
		JSONURL: "/api/v1/public/draws/" + d.VerificationCode,
	}
	if d.SeedHash != nil {
		p.SeedHash = *d.SeedHash
	}
	if d.Seed != nil {
		p.Seed = *d.Seed
	}
	for _, s := range d.EligibleSlots {
		p.EligibleSlots = append(p.EligibleSlots, web.DrawSlot{
			SlotNo: s.SlotNo, DisplayName: s.DisplayName, SlotID: s.SlotID.String(), IsWinner: s.SlotID == d.Winner.SlotID,
		})
	}
	return p
}

// periodPath parses the group_id and period_id path parameters.
func periodPath(c fiber.Ctx) (uuid.UUID, uuid.UUID, error) {
	gid, err := groupID(c)
	if err != nil {
		return uuid.Nil, uuid.Nil, err
	}
	pid, err := periodID(c)
	return gid, pid, err
}
