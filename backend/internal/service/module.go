package service

import "go.uber.org/fx"

// Module provides every service.
var Module = fx.Module("service", fx.Provide(
	NewAuthz, NewActivity, NewAuthService, NewPINService, NewProfileService,
	NewGroupService, NewMemberService, NewLeaveService, NewOwnershipService,
	NewPeriodService, NewPaymentService, NewIdempotencyService, NewDrawService, NewPayoutService,
))
