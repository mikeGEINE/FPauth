open Base
open FPauth_core.Static


let name = "password"
module type MODEL = sig
  (** Some representation of an entity to be authenticated *)
  type t

  (** [encrypted_password] retrieves password of an entity in an encrypted form*)
  val encrypted_password: t -> string option
end

module Make (M : MODEL) : (FPauth_core.Auth_sign.STRATEGY with type entity = M.t) = struct

  open StratResult
  open StratResult.Infix

  type entity = M.t
  let get_password request =
    match Params.get_param_req "password" request with
    | None -> Dream.log "\'password\' is needed for Password authentication, skipping the strategy..."; Next
    | Some password -> Authenticated password

  let check_password user password =
    match M.encrypted_password user with 
    | None -> Rescue (Error.of_string "No encrypted password for the user")
    | Some encoded ->
      match Argon2.verify ~encoded ~pwd:password ~kind:Argon2.ID with
      | Error Argon2.ErrorCodes.VERIFY_MISMATCH -> Rescue (Error.of_string "Incorrect password!")
      | Error err ->  Rescue (Error.of_string (Argon2.ErrorCodes.message err))
      | Ok _ -> Authenticated user


  (**[call] is a main function of a strategy, which authenticates the user by "login" and "password" querry params*)
  let call request user = 
    get_password request >>== check_password user |> Lwt.return

  let routes = Dream.no_route

  (* takes name from outside the functor*)
  let name = name
end

