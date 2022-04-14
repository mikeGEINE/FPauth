open FPauth_core

module Static = Static

module Make_Auth (M : Auth_sign.MODEL) = struct

  module Variables = Variables.Make_Variables (M)

  module SessionManager = Session_manager.Make_SessionManager (M) (Variables)

  module Authenticator = Authenticator.Make_Authenticator (M) (Variables)

  module Router = Router.Make (M) (Authenticator) (Variables)
end

module Auth_sign = Auth_sign