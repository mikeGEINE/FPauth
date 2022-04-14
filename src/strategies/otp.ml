open Base
open FPauth_core.Static
open FPauth_core.Static.StratResult.Infix

let name = "TOTP"

module type MODEL = sig
  type t

  (**Retrieves secret for TOTP for the user*)
  val otp_secret : t -> string

  (**Checks if TOTP has already been setup*)
  val otp_enabled : t -> bool

  (**Sets TOTP secret during setup. Returns updated user.*)
  val set_otp_secret: Dream.request -> t -> string -> t Dream.promise

  (**Enables TOTP. Returns updated user.*)
  val set_otp_enabled: Dream.request -> t -> bool -> t Dream.promise
end

(**[VIEWS] contains data representations for certain events*)
module type RESPONSES = sig
  open Dream

  val response_error : Error.t -> response promise

  val response_secret : string -> response promise

  val response_enabled : response promise 
end

module Make (R : RESPONSES) (M : MODEL) (V : FPauth_core.Auth_sign.VARIABLES with type entity = M.t)
: (FPauth_core.Auth_sign.STRATEGY with type entity = M.t) = struct
  open R
  
  type entity = M.t


  let is_enabled user = 
    match M.otp_enabled user with
    | false -> StratResult.Next
    | true -> Authenticated user

  let extract_otp request _ = 
    match Params.get_param_req "otp_code" request with
    | None -> Dream.log "\'otp_code\' is needed for TOTP authentication, skipping the strategy...";
      StratResult.Next
    | Some otp_code -> Authenticated otp_code

  let verify_otp user otp_code =
    let secret = M.otp_secret user in
    match Twostep.TOTP.verify ~secret:secret ~code:otp_code () with
    | false -> StratResult.Rescue (Error.of_string ("One-time password is incorrect!"))
    | true -> Authenticated user
    

  let call request user =
    is_enabled user >>== extract_otp request >>== verify_otp user |> Lwt.return

  let update_current_user request user =
    Dream.set_field request V.current_user user

  let generate_secret request =
    match Dream.field request V.current_user with
    | None -> Error.of_string "User should be authenticated first" |> response_error 
    | Some user -> 
      match M.otp_enabled user with
      | true -> Error.of_string "OTP is already enabled" |> response_error
      | false -> 
        let secret = Twostep.TOTP.secret () in 
        let%lwt updated_user = M.set_otp_secret request user secret in
        update_current_user request updated_user;
        response_secret secret

  let finish_setup request =
    match Dream.field request V.current_user with
    | None -> Error.of_string "User should be authenticated first" |> response_error 
    | Some user -> 
      match M.otp_enabled user with
      | true -> Error.of_string "OTP is already enabled" |> response_error
      | false -> 
        match Params.get_param_req "otp_code" request with
        | None -> Error.of_string "\'OTP code\' param not found in request" |> response_error
        | Some otp_code -> 
          let secret = M.otp_secret user in
          match Twostep.TOTP.verify ~secret:secret ~code:otp_code () with
          | false -> Error.of_string "One-time password is incorrect!" |> response_error
          | true -> 
            let%lwt updated_user = M.set_otp_enabled request user true in
            update_current_user request updated_user;
            response_enabled

  let routes = 
    Dream.scope "/otp" [] [
      Dream.get "/generate_secret" generate_secret;
      Dream.post "/finish_setup" finish_setup
    ]

  let name = name
end

module JSON_Responses : RESPONSES = struct
  let response_error err = 
    Dream.json ("{\"success\" : false, \n
    \"error\" : "^Error.to_string_mach err^"}")

  let response_secret secret =
    Dream.json ("{\"success\" : true, \n
            \"secret\" : \""^ secret ^"\" }")

  let response_enabled =
    Dream.json ("{\"TOTP enabled\" : true}")
end