module Static = FPauth__core.Static

module Make_Auth (M : FPauth__core.Auth_sign.MODEL) = struct

  module Variables = FPauth__core.Variables.Make_Variables (M)

  module SessionManager = FPauth__core.Session_manager.Make_SessionManager (M) (Variables)

  module Authenticator = FPauth__core.Authenticator.Make_Authenticator (M) (Variables)

  module Router = FPauth__core.Router.Make (M) (Authenticator) (Variables)
end

module Auth_sign = FPauth__core.Auth_sign