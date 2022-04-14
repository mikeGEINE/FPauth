(*Tests for SessionManager*)

open Base
open Lwt.Syntax
open Setup

module SM = Auth.SessionManager

let test_handler request = 
  let auth = Dream.field request Auth.Variables.authenticated |> Option.value ~default:false |> Bool.to_string 
  and user = Dream.field request Auth.Variables.current_user |> Option.value ~default:user_none |> Entity.name 
  in        
  Dream.respond ("auth : "^auth^"; user : "^user)

let put_session value inner_handler requset = 
  let* () = Dream.set_session_field requset "auth" value in
  inner_handler requset

let tests = "FPauth.SessionManager: ", [
  "empty session" -: begin fun () ->
    let req = Dream.request "" in
    let response = Dream.test (Dream.memory_sessions @@ SM.auth_setup test_handler) req in
    let expected = "auth : false; user : none" in
    Dream.body response |> Lwt_main.run |> Alcotest.(check string) "OK no auth" expected
    end;

  "authenticated session" -: begin fun () ->
    let req = Dream.request "" in
    let response = Dream.test (Dream.memory_sessions 
                                @@ put_session (Entity.serialize user) 
                                @@ SM.auth_setup 
                                @@ test_handler) req in
    let expected = "auth : true; user : test" in
    Dream.body response |> Lwt_main.run |> Alcotest.(check string) "OK auth test user" expected
    end;

  "auth field empty" -: begin fun () ->
    let req = Dream.request "" in
    let response = Dream.test (Dream.memory_sessions 
                                @@ put_session "" 
                                @@ SM.auth_setup 
                                @@ test_handler) req in
    let expected = `Unauthorized |> Dream.status_to_string in
    Dream.status response |> Dream.status_to_string |> Alcotest.(check string) "Error unauthorized" expected
    end;

  "auth deserialization error" -: begin fun () ->
    let req = Dream.request "" in
    let response = Dream.test (Dream.memory_sessions 
                                @@ put_session (Entity.serialize user_none)  
                                @@ SM.auth_setup 
                                @@ test_handler) req in
    let expected = `Unauthorized |> Dream.status_to_string in
    Dream.status response |> Dream.status_to_string |> Alcotest.(check string) "Error unauthorized" expected
    end;
]