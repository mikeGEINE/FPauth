open Base
open FPauth_core.Static
open FPauth_core.Static.StratResult.Infix

let name = "TOTP"

module type MODEL = sig
  type t

  val otp_secret : t -> string

  val otp_enabled : t -> bool

  val set_otp_secret: Dream.request -> t -> string -> t Dream.promise

  val set_otp_enabled: Dream.request -> t -> bool -> t Dream.promise
end

module type RESPONSES = sig
  open Dream

  val response_error : request -> Error.t -> response promise

  val response_secret : request -> string -> response promise

  val response_enabled : request -> response promise 
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
    match Params.get_param_req "totp_code" request with
    | None -> Dream.log "\'totp_code\' is needed for TOTP authentication, skipping the strategy...";
      StratResult.Next
    | Some otp_code -> Authenticated otp_code

  let verify_otp user otp_code =
    let secret = M.otp_secret user in
    match Twostep.TOTP.verify ~secret:secret ~code:otp_code () with
    | false -> StratResult.Rescue (Error.of_string ("One-time password is incorrect!"))
    | true -> Authenticated user
    

  let call request user =
    is_enabled user >>== extract_otp request >>== verify_otp user |> Lwt.return

  let generate_secret request =
    match Dream.field request V.current_user with
    | None -> Error.of_string "User should be authenticated first" |> response_error request
    | Some user -> 
      match M.otp_enabled user with
      | true -> Error.of_string "OTP is already enabled" |> response_error request
      | false -> 
        let secret = Twostep.TOTP.secret () in 
        let%lwt updated_user = M.set_otp_secret request user secret in
        let%lwt () = V.update_current_user updated_user request in
        response_secret request secret

  let finish_setup request =
    match Dream.field request V.current_user with
    | None -> Error.of_string "User should be authenticated first" |> response_error request
    | Some user -> 
      match M.otp_enabled user with
      | true -> Error.of_string "OTP is already enabled" |> response_error request
      | false -> 
        match Params.get_param_req "totp_code" request with
        | None -> Error.of_string "\'TOTP code\' param not found in request" |> response_error request
        | Some otp_code -> 
          let secret = M.otp_secret user in
          match Twostep.TOTP.verify ~secret:secret ~code:otp_code () with
          | false -> Error.of_string "One-time password is incorrect!" |> response_error request
          | true -> 
            let%lwt updated_user = M.set_otp_enabled request user true in
            let%lwt () = V.update_current_user updated_user request in
            response_enabled request

  let routes = 
    Dream.scope "/totp" [] [
      Dream.get "/generate_secret" generate_secret;
      Dream.post "/finish_setup" finish_setup
    ]

  let name = name
end

module JSON_Responses : RESPONSES = struct
  let response_error _ err = 
    Dream.json ("{\"success\" : false, \n
    \"error\" : "^Error.to_string_mach err^"}")

  let response_secret _ secret =
    Dream.json ("{\"success\" : true, \n
            \"secret\" : \""^ secret ^"\" }")

  let response_enabled _ =
    Dream.json ("{\"TOTP enabled\" : true}")
end

(**This module contains such settings as app name for titles *)
module type HTML_settings = sig val app_name : string end

module Make_HTML_Responses (S : HTML_settings) : RESPONSES = struct
  let response_error _ err =
    let err_str = Error.to_string_mach err in
    TOTP_pages.error_tmpl ~app_name:S.app_name err_str |> Dream.html

  let response_secret request secret =
    let target = Dream.target request |> String.substr_replace_first ~pattern:"/generate_secret" ~with_:"/finish_setup" in
    TOTP_pages.secret_tmpl ~app_name:S.app_name request target secret |> Dream.html

  let response_enabled _ =
    TOTP_pages.finish_tmpl ~app_name:S.app_name () |> Dream.html
end

(**[make_responses ?app_name (Variables)] is a convinience function for creating HTML response module without {!HTML_settings}.
Returns first-class module.*)
let make_html_responses ?(app_name="FPauth") ()  =
  let module S = (struct let app_name = app_name end) in
  let module HTML = Make_HTML_Responses (S) in
  (module HTML : RESPONSES)