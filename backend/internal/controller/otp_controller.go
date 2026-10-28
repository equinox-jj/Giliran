package controller

import (
	"context"
	"net/netip"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"github.com/equinox-jj/Giliran/backend/internal/dto"
	"github.com/equinox-jj/Giliran/backend/internal/model"
	"github.com/equinox-jj/Giliran/backend/internal/service"
	"github.com/equinox-jj/Giliran/backend/pkg/middleware"
	"github.com/equinox-jj/Giliran/backend/pkg/response"
)

// OTPService is what OTPController needs from service.OTPService.
type OTPService interface {
	Request(ctx context.Context, in service.OTPStart) (service.OTPChallenge, error)
	Resend(ctx context.Context, otpID uuid.UUID, caller *service.Caller) (service.OTPChallenge, error)
	Verify(ctx context.Context, otpID uuid.UUID, in service.OTPVerify, caller *service.Caller) (service.OTPResult, error)
}

// OTPController serves /auth/email/otp: signing in, resetting a forgotten
// PIN and changing the email, each with an emailed code. Every route is
// behind middleware.OptionalAuth; only change_email needs the token.
type OTPController struct {
	otp OTPService
}

func NewOTPController(otp *service.OTPService) *OTPController {
	return &OTPController{otp: otp}
}

// Request handles POST /auth/email/otp.
func (h *OTPController) Request(c fiber.Ctx) error {
	var req dto.EmailOtpRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	ch, err := h.otp.Request(c.Context(), service.OTPStart{
		Purpose: model.OTPPurpose(req.Purpose),
		Email:   req.Email,
		Device: service.Device{
			Name:     req.DeviceName,
			Platform: model.DevicePlatform(req.DevicePlatform),
			FCMToken: req.FCMToken,
		},
		PIN:    req.PIN,
		IP:     clientIP(c),
		Caller: caller(c),
	})
	if err != nil {
		return err
	}
	return response.Accepted(c, dto.NewEmailOtpChallenge(ch))
}

// Resend handles POST /auth/email/otp/{otp_id}/resend.
func (h *OTPController) Resend(c fiber.Ctx) error {
	id, err := otpID(c)
	if err != nil {
		return err
	}
	ch, err := h.otp.Resend(c.Context(), id, caller(c))
	if err != nil {
		return err
	}
	return response.Accepted(c, dto.NewEmailOtpChallenge(ch))
}

// Verify handles POST /auth/email/otp/{otp_id}/verify.
func (h *OTPController) Verify(c fiber.Ctx) error {
	id, err := otpID(c)
	if err != nil {
		return err
	}
	var req dto.EmailOtpVerifyRequest
	if err := c.Bind().Body(&req); err != nil {
		return err
	}
	res, err := h.otp.Verify(c.Context(), id, service.OTPVerify{
		Code:               req.Code,
		PIN:                req.PIN,
		NewPIN:             req.NewPIN,
		NewPINConfirmation: req.NewPINConfirmation,
	}, caller(c))
	if err != nil {
		return err
	}
	return response.OK(c, dto.NewEmailOtpResult(res))
}

// caller is the signed-in account behind an OptionalAuth route, or nil.
func caller(c fiber.Ctx) *service.Caller {
	userID, ok := middleware.UserIDOpt(c)
	if !ok {
		return nil
	}
	return &service.Caller{UserID: userID, SessionID: middleware.SessionID(c)}
}

// clientIP is the requester's address (behind the trusted proxy, the one it
// forwarded), or nil when it does not parse.
func clientIP(c fiber.Ctx) *netip.Addr {
	ip, err := netip.ParseAddr(c.IP())
	if err != nil {
		return nil
	}
	ip = ip.Unmap()
	return &ip
}
