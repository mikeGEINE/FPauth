(*Testing Password strategy*)
open Base
open Setup

module Entity = EntityPassword

module Password = FPauth__strategies.Password

module Strategy = Password.Make (Entity)

let user : Entity.t = {name = "test"}

let user_none : Entity.t = {name = "none"}

let user_rand : Entity.t = {name= "rand"}

module Auth = FPauth.Make_Auth(Entity)

let fake_extractor lst _ = FPauth.Static.Params.of_assoc lst |> Lwt.return

let test_middlewares params handler = Dream.memory_sessions 
                                      @@ Auth.SessionManager.auth_setup 
                                      @@ FPauth.Static.Params.set_params ~extractor:(fake_extractor params) 
                                      handler

let test_handler user request  =
  match%lwt Strategy.call request user with
  |Authenticated usr -> Dream.respond ("name : "^ Entity.name usr)
  |Rescue err -> Dream.respond ("error : "^ Error.to_string_hum err)
  |Next -> Dream.respond "next"
  |Redirect resp -> resp

let tests = "Password strategy", [
  "Normal call" -: begin fun () ->
    let req = Dream.request "" in
    let response = Dream.test (test_middlewares [("password", "12345678")] (test_handler user)) req 
    and expected = "name : test" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Correct password" expected
  end;

  "No password in params" -: begin fun () ->
    let req = Dream.request "" in
    let response = Dream.test (test_middlewares [] (test_handler user)) req 
    and expected = "next" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Skipped the strategy" expected
  end;

  "No encrypted password" -: begin fun () ->
    let req = Dream.request "" in
    let response = Dream.test (test_middlewares [("password", "12345678")] (test_handler user_none)) req 
    and expected = "error : No encrypted password for the user" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Can't get encrypted password" expected
  end;

  "Wrong password hash" -: begin fun () ->
    let req = Dream.request "" in
    let response = Dream.test (test_middlewares [("password", "12345678")] (test_handler user_rand)) req 
    and expected = "error : Decoding failed" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Argon2 error" expected
  end;

  "Wrong password recieved" -: begin fun () ->
    let req = Dream.request "" in
    let response = Dream.test (test_middlewares [("password", "11111111")] (test_handler user)) req 
    and expected = "error : Incorrect password!" in
    Dream.body response
    |> Lwt_main.run
    |> Alcotest.(check string) "Wrong password" expected
  end;
]