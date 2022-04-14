(*Setting up testing env*)
open Base

(* operator for making quick tests *)
let (-:) key f = Alcotest.test_case key `Quick f

(*Mock of a model*)
module Entity = struct
  type t = {name:string}

  let serialize ent = ent.name

  let deserialize str = 
    if String.equal str "test" then
      Result.Ok {name=str}
    else
      Result.Error (Error.of_string "Wrong name!")

  let identificate request =
    match FPauth.Static.Params.get_param_req "name" request with
    | None -> Lwt.return_error (Error.of_string "No param \'name\' in request")
    | Some "test1" -> Lwt.return_error (Error.of_string "Wrong name")
    | Some name -> Lwt.return_ok {name}

  let applicable_strats _ = ["Test"]

  let name ent = ent.name
end

let user_none : Entity.t = {name = "none"}

let user : Entity.t = {name = "test"}

module Auth = FPauth.Make_Auth(Entity)

module Strategy = struct
  open FPauth.Static

  type entity = Entity.t

  let call request user =
    let result =
      match Params.get_param_req "pass" request with
      | None -> StratResult.Next
      | Some "redirect" -> StratResult.Redirect (Dream.redirect request "/")
      | Some pass -> 
        if String.equal ("test") (pass) then
          StratResult.Authenticated user
        else
          StratResult.Rescue (Error.of_string "Wrong pass")
    in
    Lwt.return result

  let routes = Dream.no_route

  let name = "Test"
end

module ChangeNameStrat = struct
  type entity = Strategy.entity

  let call = Strategy.call

  let routes = Strategy.routes

  let name = "Not test"
end
