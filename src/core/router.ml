open Dream
open Base

module Make  (M : Auth_sign.MODEL) 
                    (A : Auth_sign.AUTHENTICATOR with type entity = M.t) 
                    (V : Auth_sign.VARIABLES) = struct

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

  let call ?(root="/") strat_list ~responses ~extractor =  
    let strat_routes = strategy_routes strat_list in
    let all_routes = List.append [
      post "/auth" (login_handler strat_list responses);
      get "/logout" (logout_handler responses);
    ] strat_routes in
    scope root [Static.Params.set_params ~extractor] all_routes
end
