open Dream
open Base

module Make_Variables (M : Auth_sign.MODEL) : (Auth_sign.VARIABLES with type entity = M.t) = struct
  type entity = M.t

  let authenticated : bool field = new_field ()

  let current_user : entity field = new_field ()

  let auth_error : Error.t field = new_field ()
end