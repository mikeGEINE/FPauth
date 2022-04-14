open Base
open Dream
open Lwt.Syntax

(** [Make_SessionManager] is a functor for creating modules of middlewares for various entities matching {!Auth.MODEL}*)
module Make_SessionManager (M : Auth_sign.MODEL) (V :Auth_sign.VARIABLES with type entity = M.t) : (Auth_sign.SESSIONMANAGER with type entity = M.t) = struct

    type entity = M.t
    (** [set_helpers] sets field variables for a request an manages authentication status in case if [auth] is in a session.
    - If [serialized] is empty, then [Error Error.t] is returned, as it is abnormal situation.
    - If {!M.deserialize} ended up with an [Error Error.t], then authentication is incomplete and {!auth_session_error} is set with the sting.
    - If {!M.deserialize} ended with [Ok M.t], then authentication is considered successful and {!current_user} is set.*)
    let set_helpers serialized request =
      if String.equal serialized "" then 
        Error (Error.of_string "Auth session field is empty")
      else match M.deserialize serialized with 
        | Ok ent ->
          set_field request V.authenticated true;
          set_field request V.current_user ent;
          Ok request
        | Error err -> 
          Error err

    (** [auth_setup] tries to extract [auth] string from session and determine the status of authentication.
    If there is no [auth], then there were no authentication. 
    If [auth] exisits, than {!set_helpers} checks it and manages authentication status. If something is wrong with a session, 
    [Error Error.t] is returned, and in this case session is invalidated, error is logged and 401 is sent.
    If session is ok, [Ok request] is recived, and that requested is passed on. *)
    let auth_setup (inner_handler : handler) (request : request) =
      match session "auth" request with
      | None -> set_field request V.authenticated false; inner_handler request
      | Some serialized -> 
        match set_helpers serialized request with
        | Ok req -> inner_handler req
        | Error err -> 
          Dream.error (fun log -> Error.to_string_mach err |> log ~request "Session auth error: %s");
          let* () = request |> invalidate_session
        in 
          respond ~status:`Unauthorized ""
end
