module Static = FPauth_core.Static

module Auth_sign = FPauth_core.Auth_sign

module Make_Auth (M : Auth_sign.MODEL) = FPauth_core.Make_Auth (M)

module Strategies = FPauth_strategies

module Responses = FPauth_responses