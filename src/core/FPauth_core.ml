module Static = Static

module Variables = Variables
module Session_manager = Session_manager
module Authenticator = Authenticator
module Router = Router


module Make_Auth (M : Auth_sign.MODEL) = struct

  module Variables = Variables.Make (M)

  module Session_manager = Session_manager.Make (M) (Variables)

  module Authenticator = Authenticator.Make (M) (Variables)

  module Router = Router.Make (M) (Authenticator) (Variables)
end

module Auth_sign = Auth_sign