(*Tests for Router*)

open Base
open Lwt.Syntax
open Setup
open FPauth_core

module R = Auth.Router

let strategy : Auth.Authenticator.strategy = (module Strategy)

let fake_extractor lst _ = Static.Params.of_assoc lst |> Lwt.return

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

let test_middlewares params = Dream.memory_sessions 
                                      @@ Auth.SessionManager.auth_setup 
                                      @@ Dream.router [
                                        R.call [strategy] ~responses:(module Responses) ~extractor:(fake_extractor params)
                                      ]

let tests = "FPauth.Router: ", [
  "Login successful" -: begin fun () ->
    let req = Dream.request ~target:"/auth" ~method_:`POST "" in
    let response = Dream.test (test_middlewares [("name", "test"); ("pass", "test")]) req in
    let expected = "user : test" in
    Dream.body response 
    |> Lwt_main.run 
    |> Alcotest.(check string) "Used auth route for successful authentication" expected
  end;

  "Login unsuccessful" -: begin fun () ->
    let req = Dream.request ~target:"/auth" ~method_:`POST "" in
    let response = Dream.test (test_middlewares [("name", "test1"); ("pass", "test")]) req in
    let expected = "error : Wrong name" in
    Dream.body response 
    |> Lwt_main.run 
    |> Alcotest.(check string) "Used auth route for unsuccessful authentication" expected
  end;

  "Login redirected" -: begin fun () ->
    let req = Dream.request ~target:"/auth" ~method_:`POST "" in
    let response = Dream.test (test_middlewares [("name", "test"); ("pass", "redirect")]) req in
    let expected = `See_Other |> Dream.status_to_string in
    Dream.status response 
    |> Dream.status_to_string
    |> Alcotest.(check string) "Used auth route for successful authentication" expected
  end;

  "Logout" -: begin fun () ->
    let req = Dream.request ~target:"/logout" "" in
    let put_session value inner_handler requset = 
      let* () = Dream.set_session_field requset "auth" value in
      inner_handler requset in
    let response = Dream.test (Dream.memory_sessions 
      @@ put_session (Entity.serialize user) 
      @@ Auth.SessionManager.auth_setup
      @@ Dream.router [R.call [strategy] ~responses:(module Responses) ~extractor:(fake_extractor [])]) 
      req in
    let expected = "auth : false" in
    Dream.body response 
    |> Lwt_main.run 
    |> Alcotest.(check string) "Authentication reset" expected
    end;
]