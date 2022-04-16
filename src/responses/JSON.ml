(**This module contains responses for basic FPauth events in JSON format.*)

open Dream
open Base

module Make (Variables : FPauth_core.Auth_sign.VARIABLES) : (FPauth_core.Auth_sign.RESPONSES) = struct
  
  let login_successful request = 
    let auth = Option.value_exn (field request Variables.authenticated) |> Bool.to_string in
    json ("{\"authenticated\" : "^ auth ^" }")
  
  
  let login_error request = 
    let err = field request (Variables.auth_error) |> Option.value ~default:(Error.of_string "Unknown error") |> Error.to_string_mach 
    and auth = Option.value_exn (field request Variables.authenticated) |> Bool.to_string in
    json ("{\"auth\" : "^ auth ^", \n
      \"error\" : "^ err ^"}")

  let logout request =
    match field request Variables.authenticated with
    | None -> json ("{\"error\" : \"No local\"}")
    | Some auth -> json ("{
      \"auth\" : "^( auth |> Bool.to_string)^"}")
end
