(**[Authenticator] is module which provides functions both for authentication and logout*)

open Base
open Dream
open Static

(**[Make] creates an instance of {!Auth_sign.AUTHENTICATOR} for a given model and variables*)
module Make (M : Auth_sign.MODEL) (V : Auth_sign.VARIABLES with type entity = M.t ) : (Auth_sign.AUTHENTICATOR with type entity = M.t) = struct
  
  type entity = M.t

  (** [strategy] is a function that tries to authenticate an entity*)
  type strategy = (module Auth_sign.STRATEGY with type entity = entity)

  module type Strategy = Auth_sign.STRATEGY with type entity = entity

  let set_authenticated request = 
    set_field request V.authenticated true;
    request

  (**[auth] is a recursive function for running strategies and verifying*)
  let rec auth (lst : strategy list) request ent : AuthResult.t promise =
    match lst with
    | [] -> set_field request V.auth_error (Error.of_string "End of strategy list");
            Lwt.return AuthResult.Rescue
    | (module S : Strategy)::strats -> 
      match%lwt S.call request ent with
      | Next -> auth strats request ent
      | Authenticated ent -> 
        let%lwt () =
        request |> set_authenticated |> V.update_current_user ent in
        Lwt.return AuthResult.Authenticated
      | Rescue err -> set_field request V.auth_error err;
                      Lwt.return AuthResult.Rescue
      | Redirect url -> Lwt.return (AuthResult.Redirect url)


  let name_in_list names (module S : Strategy) =
    List.exists names ~f:(String.equal S.name)

  let filter_strategies (strats: strategy list) names =
    List.filter strats ~f:(name_in_list names)

  (** [authenticate] runs all strategies from the list until one of them succeeds. 
  Sets session and field variables. Returns a promise. *)
  let authenticate (lst : strategy list) request =
    match%lwt M.identificate request with
    | Error err ->  set_field request V.auth_error err;
    Lwt.return AuthResult.Rescue
    | Ok ent -> 
      let filtered_strats = M.applicable_strats ent |> filter_strategies lst in
      auth filtered_strats request ent

  (** [logout] clears [auth] session field and sets {V.authenticated} to [false], making session unauthenticated.
  Note: the function does NOT modify {!V.current_user}. It will be set to [None] only for the next request.*)
  let logout request =
    set_field request V.authenticated false;
    request |> invalidate_session
end