(**[Router] is a module which contains handlers for authentication and creates routes for them.*)

open Dream
open Base

(**[Make] creates an instance of Router with all its dependencies*)
module Make  (M : Auth_sign.MODEL) 
              (A : Auth_sign.AUTHENTICATOR with type entity = M.t) 
              (V : Auth_sign.VARIABLES) : (Auth_sign.ROUTER with type entity = M.t) = struct

  type entity = M.t

  type strategy = (module Auth_sign.STRATEGY with type entity = entity)

  let login_handler (strat_list : A.strategy list) (module R : Auth_sign.RESPONSES) request =
    match%lwt A.authenticate strat_list request with
    | Authenticated -> R.login_successful request
    | Rescue-> R.login_error request
    | Redirect url -> url
  
  let logout_handler (module R : Auth_sign.RESPONSES) request =
    let%lwt () = A.logout request in
    R.logout request

  let strategy_routes strat_list =
    let rec extractor acc = function
    | [] -> acc
    | strat::strats -> let module S = (val strat : Auth_sign.STRATEGY with type entity = M.t) in
                        extractor ((S.routes)::acc) strats
    in
    extractor [] strat_list |> List.rev

  let call ?(root="/") ~responses ~extractor strat_list =  
    let strat_routes = strategy_routes strat_list in
    let all_routes = List.append [
      post "/auth" (login_handler strat_list responses);
      get "/auth" (login_handler strat_list responses);
      post "/logout" (logout_handler responses);
      get "/logout" (logout_handler responses);
    ] strat_routes in
    scope root [Static.Params.set_params ~extractor] all_routes
end
