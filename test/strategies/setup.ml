(*Setting up testing env*)
open Base

(* operator for making quick tests *)
let (-:) key f = Alcotest.test_case key `Quick f

(* This module helps with password hashing *)
module Encryptor = struct
  open Base

  type params = {
    time_cost: int;
    memory_cost_kiB: int;
    parallelism: int;
    hash_len: int;
    salt_len: int;
  }

  (* Recommended parameters
  https://argon2-cffi.readthedocs.io/en/stable/api.html#argon2.PasswordHasher *)
  let recommend_params = {
    time_cost = 2;
    memory_cost_kiB = 100 * 1024;  (*100MiB*)
    parallelism = 8;
    hash_len = 16;
    salt_len = 16;
  }

  let hash ?(params=recommend_params) password = 
    let {
      time_cost;
      memory_cost_kiB;
      parallelism;
      hash_len;
      salt_len;
    } = params in

    let salt = Dream.random(16) in

    let encoded_len =
      Argon2.encoded_len 
        ~t_cost:time_cost 
        ~m_cost:memory_cost_kiB
        ~parallelism
        ~salt_len
        ~hash_len
        ~kind:Argon2.ID 
    in
    let encoded =
      Argon2.ID.hash_encoded
        ~t_cost:time_cost
        ~m_cost:memory_cost_kiB
        ~parallelism
        ~pwd:password
        ~salt
        ~hash_len
        ~encoded_len
    in match encoded with
    | Ok enc -> Ok (Argon2.ID.encoded_to_string enc)
    | Error e -> Error e
end


(*Mock of a model for Password strat*)
module EntityPassword = struct
  type t = {name:string}

  let serialize ent = ent.name

  let deserialize str = 
    if String.equal str "test" then
      Result.Ok {name=str}
    else
      Result.Error (Error.of_string "Wrong name!")

  let identificate request =
    match FPauth_core.Static.Params.get_param_req "name" request with
    | None -> Lwt.return_error (Error.of_string "No param \'name\' in request")
    | Some "test1" -> Lwt.return_error (Error.of_string "Wrong name")
    | Some name -> Lwt.return_ok {name}

  let applicable_strats _ = [FPauth_strategies.Password.name]

  let name ent = ent.name

  let encrypted_password user = 
    match name user with
    | "none" -> None
    | "test" -> begin
      match Encryptor.hash "12345678" with
      |Ok str -> Some str
      |Error _ -> None
    end;
    | _ -> Some "randomstring"
end

(*Mock of a model for OTP strat*)
module EntityOTP = struct
  type t = {name:string}

  let serialize ent = ent.name

  let deserialize str = Result.Ok {name=str}

  let identificate request =
    match FPauth_core.Static.Params.get_param_req "name" request with
    | None -> Lwt.return_error (Error.of_string "No param \'name\' in request")
    | Some "test1" -> Lwt.return_error (Error.of_string "Wrong name")
    | Some name -> Lwt.return_ok {name}

  let applicable_strats _ = [FPauth_strategies.Otp.name]

  let name ent = ent.name

  let otp_secret _ = "AAAA BBBB CCCC DDDD"

  let otp_enabled user =
    match name user with
    | "test" -> true
    | _ -> false

  let set_otp_secret _ user secret =
    {name=(user.name ^ secret)} |> Lwt.return

  let set_otp_enabled _ user enabled =
    {name=(user.name ^ (Bool.to_string enabled))} |> Lwt.return
end

module Make_Auth (Entity : FPauth_core.Auth_sign.MODEL) = struct
  module Variables = FPauth_core.Variables.Make_Variables (Entity)

  module SessionManager = FPauth_core.Session_manager.Make_SessionManager (Entity) (Variables)

  module Authenticator = FPauth_core.Authenticator.Make_Authenticator (Entity) (Variables)

  module Router = FPauth_core.Router.Make (Entity) (Authenticator) (Variables)
end
