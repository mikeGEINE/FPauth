open Dream
open Base

module type MODEL = sig
  type t

  val name : t -> string
end

module Make (M : MODEL) (Variables : FPauth.Auth_sign.VARIABLES with type entity = M.t) : (FPauth.Auth_sign.RESPONSES) = struct
  
  let login_successful request = 
    let user = Option.value_exn (field request Variables.current_user) in
    json ("{\"success\" : true, \n
            \"user\" : \""^ M.name user ^"\" }")
  
  
  let login_error request = 
    let err = field request (Variables.auth_error) |> Option.value ~default:(Error.of_string "Unknown error") in
    json ("{\"success\" : false, \n
      \"error\" : "^ Error.to_string_mach err ^"}")

  let logout request =
    match field request Variables.authenticated with
    | None -> json ("{\"error\" : \"No local\"}")
    | Some auth -> json ("{
      \"auth\" : "^( auth |> Bool.to_string)^"}")
end
