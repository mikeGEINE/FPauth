(*Tests for Authenticator*)

open Base
open Lwt
open Lwt.Syntax
open Setup
open FPauth_core.Static

module A = Auth.Authenticator

let strategy : Auth.Authenticator.strategy = (module Strategy)

let wrong_strat : Auth.Authenticator.strategy = (module ChangeNameStrat)

let fake_extractor lst _ = Params.of_assoc lst |> Lwt.return

let test_middlewares params handler = Dream.memory_sessions 
                                      @@ Auth.Session_manager.auth_setup 
                                      @@ Params.set_params ~extractor:(fake_extractor params) 
                                      handler

let respond request = function
  |AuthResult.Authenticated -> 
    let user = Dream.field request Auth.Variables.current_user |> Option.value ~default:user_none in
    "name : "^(Entity.name user) |> Dream.respond
  | Rescue -> 
    let error = Dream.field request Auth.Variables.auth_error |>Option.value ~default:(Error.of_string "no error") in
    "error : "^(Error.to_string_hum error) |> Dream.respond
  | Redirect response -> Lwt_main.run response |> Dream.status |> Dream.status_to_string |> Dream.respond

let authenticate_test params expected message =
  let req = Dream.request "" in
  let handler requset = A.authenticate [strategy] requset >>= respond requset in
  let response = Dream.test (test_middlewares params handler) req in
  let expected = expected in
  Dream.body response 
  |> Lwt_main.run 
  |> Alcotest.(check string) message expected

let tests = "FPauth.Authenticator: ", [
  "Normal auth" -: begin fun () ->
    let params = [("name", "test"); ("pass", "test")] 
    and expected = "name : test"
    and message = "Authenticated test"
    in authenticate_test params expected message 
  end;

  "Failed identification" -: begin fun () ->
    let params = [("name", "test1"); ("pass", "test")] 
    and expected = "error : Wrong name"
    and message = "Failed to identificate user test1"
    in authenticate_test params expected message 
  end;

  "Failed authentication" -: begin fun () ->
    let params = [("name", "test"); ("pass", "test1")]
    and expected = "error : Wrong pass"
    and message = "Failed to authenticate with wrong pass"
    in authenticate_test params expected message 
  end;

  "Skipping strategy" -: begin fun () ->
    let params = [("name", "test")]
    and expected = "error : End of strategy list"
    and message = "Skipped all strategies"
    in authenticate_test params expected message 
  end;

  "Redirect from strategy" -: begin fun () ->
    let params = [("name", "test"); ("pass", "redirect")]
    and expected = `See_Other |> Dream.status_to_string
    and message = "Redirected"
    in authenticate_test params expected message 
  end;

  "Filtering non-applicable strat" -: begin fun () ->
    let req = Dream.request "" in
    let handler requset = A.authenticate [wrong_strat] requset >>= respond requset in
    let response = Dream.test (test_middlewares [("name", "test"); ("pass", "test")]  handler) req in
    let expected = "error : End of strategy list" in
    Dream.body response 
    |> Lwt_main.run 
    |> Alcotest.(check string) "Filtered all strategies" expected
  end;

  "Logout" -: begin fun () ->
    let req = Dream.request "" in
    let put_session value inner_handler requset = 
      let* () = Dream.set_session_field requset "auth" value in
      inner_handler requset in
    let test_handler request = 
      let auth req = Dream.field req Auth.Variables.authenticated |> Option.value ~default:false |> Bool.to_string 
      in        
      let* () = A.logout request in
      Dream.respond ("auth : "^auth request) in
    let response = Dream.test (Dream.memory_sessions 
      @@ put_session (Entity.serialize user) 
      @@ Auth.Session_manager.auth_setup 
      @@ test_handler) req in
    let expected = "auth : false" in
    Dream.body response 
    |> Lwt_main.run 
    |> Alcotest.(check string) "Authentication reset" expected
    end;
]