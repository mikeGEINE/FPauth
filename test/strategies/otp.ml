(*Testing OTP strategy*)
open Base
open Setup

module Entity = EntityOTP

module Auth = FPauth_core.Make_Auth(Entity)

module OtpResponses = struct
  let response_error err = 
    Dream.respond ("error : "^Error.to_string_hum err)

  let response_secret _ =
    Dream.respond ("secret : generated")

  let response_enabled =
    Dream.respond ("TOTP enabled : true")
end

module Otp = FPauth_strategies.TOTP

module Strategy = Otp.Make (OtpResponses) (Entity) (Auth.Variables)

let strategy : Auth.Authenticator.strategy = (module Strategy)

let user : Entity.t = {name = "test"}

let user_none : Entity.t = {name = "none"}

module Responses = struct
  open Dream
  let login_successful request = 
    let user = Option.value_exn (field request Auth.Variables.current_user) in
    respond ("user : "^ Entity.name user)

  let login_error request = 
    let err = field request (Auth.Variables.auth_error) |> Option.value ~default:(Error.of_string "Unknown error") in
    respond ("error : "^ Error.to_string_hum err)

  let logout request =
    match field request Auth.Variables.authenticated with
    | None -> respond ("error : No local")
    | Some auth -> respond ("auth : "^( auth |> Bool.to_string))
end

let fake_extractor lst _ = FPauth_core.Static.Params.of_assoc lst |> Lwt.return

let test_middlewares_call params handler = Dream.memory_sessions 
                                      @@ Auth.Session_manager.auth_setup 
                                      @@ FPauth_core.Static.Params.set_params ~extractor:(fake_extractor params) 
                                      handler

let put_session usr inner_handler requset = 
  let%lwt () = Dream.set_session_field requset "auth" (Entity.serialize usr) in
  inner_handler requset
let test_middlewares_handlers usr params = Dream.memory_sessions
                                      @@ put_session usr
                                      @@ Auth.Session_manager.auth_setup 
                                      @@ Dream.router [
                                        Auth.Router.call [strategy] ~responses:(module Responses) ~extractor:(fake_extractor params)
                                      ]
let test_middlewares_handlers_empty params = Dream.memory_sessions
                                      @@ Auth.Session_manager.auth_setup 
                                      @@ Dream.router [
                                        Auth.Router.call [strategy] ~responses:(module Responses) ~extractor:(fake_extractor params)
                                      ]

let test_handler user request  =
  match%lwt Strategy.call request user with
  |Authenticated usr -> Dream.respond ("name : "^ Entity.name usr)
  |Rescue err -> Dream.respond ("error : "^ Error.to_string_hum err)
  |Next -> Dream.respond "next"
  |Redirect resp -> resp

let tests = "OTP strategy", [
  "Normal call" -: begin fun () ->
    let req = Dream.request "" in
    let otp_code = Twostep.TOTP.code ~secret:(Entity.otp_secret ()) () in
    let response = Dream.test (test_middlewares_call [("otp_code", otp_code)] (test_handler user)) req 
    and expected = "name : test" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "User authenticated" expected
  end;

  "OTP disabled" -: begin fun () ->
    let req = Dream.request "" in
    let otp_code = Twostep.TOTP.code ~secret:(Entity.otp_secret ()) () in
    let response = Dream.test (test_middlewares_call [("otp_code", otp_code)] (test_handler user_none)) req 
    and expected = "next" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Skipped strategy" expected
  end;

  "No otp code" -: begin fun () ->
    let req = Dream.request "" in
    let response = Dream.test (test_middlewares_call [] (test_handler user)) req 
    and expected = "next" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Skipped strategy" expected
  end;

  "Incorrect otp" -: begin fun () ->
    let req = Dream.request "" in
    let otp_code = "lalala" in
    let response = Dream.test (test_middlewares_call [("otp_code", otp_code)] (test_handler user)) req 
    and expected = "error : One-time password is incorrect!" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Error raised" expected
  end;

  "Auth before otp setup" -: begin fun () ->
    let req = Dream.request ~target:"/otp/generate_secret" ~method_:`GET "" in
    let response = Dream.test (test_middlewares_handlers_empty []) req 
    and expected = "error : User should be authenticated first" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Error raised" expected
  end;

  "Otp generate secret" -: begin fun () ->
    let req = Dream.request ~target:"/otp/generate_secret" ~method_:`GET "" in
    let response = Dream.test (test_middlewares_handlers user_none []) req 
    and expected = "secret : generated" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "OTP secret presented" expected
  end;

  "Otp enabled for secret gen" -: begin fun () ->
    let req = Dream.request ~target:"/otp/generate_secret" ~method_:`GET "" in
    let response = Dream.test (test_middlewares_handlers user []) req 
    and expected = "error : OTP is already enabled" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "OTP is already enabled" expected
  end;

  "Auth before otp setup finish" -: begin fun () ->
    let req = Dream.request ~target:"/otp/finish_setup" ~method_:`POST "" in
    let response = Dream.test (test_middlewares_handlers_empty []) req 
    and expected = "error : User should be authenticated first" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Error raised" expected
  end;

  "Otp enabled for setup finish" -: begin fun () ->
    let req = Dream.request ~target:"/otp/finish_setup" ~method_:`POST "" in
    let response = Dream.test (test_middlewares_handlers user []) req 
    and expected = "error : OTP is already enabled" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "OTP is already enabled" expected
  end;

  "Correct otp to finish" -: begin fun () ->
    let req = Dream.request ~target:"/otp/finish_setup" ~method_:`POST "" in
    let otp_code = Twostep.TOTP.code ~secret:(Entity.otp_secret ()) () in
    let response = Dream.test (test_middlewares_handlers user_none [("otp_code", otp_code)]) req 
    and expected = "TOTP enabled : true" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Setup finished" expected
  end;

  "Inorrect otp to finish" -: begin fun () ->
    let req = Dream.request ~target:"/otp/finish_setup" ~method_:`POST "" in
    let otp_code = "lololo" in
    let response = Dream.test (test_middlewares_handlers user_none [("otp_code", otp_code)]) req 
    and expected = "error : One-time password is incorrect!" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Setup finished" expected
  end;

  "No otp to finish" -: begin fun () ->
    let req = Dream.request ~target:"/otp/finish_setup" ~method_:`POST "" in
    let response = Dream.test (test_middlewares_handlers user_none []) req 
    and expected = "error : \'OTP code\' param not found in request" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Error raised" expected
  end;
]

module Json_strat = Otp.Make (Otp.JSON_Responses) (Entity) (Auth.Variables)

let json_strat : Auth.Authenticator.strategy = (module Json_strat)

let json_test_middlewares usr params = Dream.memory_sessions
                                      @@ put_session usr
                                      @@ Auth.Session_manager.auth_setup 
                                      @@ Dream.router [
                                        Auth.Router.call [json_strat] ~responses:(module Responses) ~extractor:(fake_extractor params)
                                      ]

let json_tests = "OTP JSON responses tests", [
  "response_error" -: begin fun () ->
    let req = Dream.request ~target:"/otp/finish_setup" ~method_:`POST "" in
    let response = Dream.test (json_test_middlewares user []) req 
    and expected = "application/json" in
    Dream.header response "Content-Type"
    |> Option.value ~default:""
    |> Alcotest.(check string) "JSON recieved" expected
  end;

  "response_secret" -: begin fun () ->
    let req = Dream.request ~target:"/otp/generate_secret" ~method_:`GET "" in
    let response = Dream.test (json_test_middlewares user_none []) req 
    and expected = "application/json" in
    Dream.header response "Content-Type"
    |> Option.value ~default:""
    |> Alcotest.(check string) "JSON recieved" expected
  end;

  "response_error" -: begin fun () ->
    let req = Dream.request ~target:"/otp/finish_setup" ~method_:`POST "" in
    let otp_code = Twostep.TOTP.code ~secret:(Entity.otp_secret ()) () in
    let response = Dream.test (json_test_middlewares user [("otp_code", otp_code)]) req 
    and expected = "application/json" in
    Dream.header response "Content-Type"
    |> Option.value ~default:""
    |> Alcotest.(check string) "JSON recieved" expected
  end;
]