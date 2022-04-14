open Dream
open Base

module StratResult = struct
  type 'a t = 
  | Authenticated of 'a 
  | Rescue of Error.t
  | Redirect of response promise 
  | Next

  let bind r f =
    match r with
    | Authenticated x -> f x
    | Rescue err -> Rescue err
    | Next -> Next
    | Redirect url -> Redirect url

    module Infix = struct
      let (>>==) = bind
    end
end

module AuthResult = struct
  type t = 
  | Authenticated
  | Rescue
  | Redirect of response promise
end

module Params = struct
  (** [params] is a map of strings, which serves as a representation of data in a [request]*)
  type t = (string * string) list

  let params_field : t field = new_field ()

  let params request = field request params_field

  (**[extract_params] is a function which transforms [request] into [(string * string) list] and wraps it in promise. The list is than used for authentication*)
  type extractor = request -> t promise

  (** [get_param] tries to retrieve a value binded with [key] in [params]. Returns the value in an option*)
  let get_param key params = List.Assoc.find params ~equal:(String.equal) key

  (**[get_param_exn] behaves similar to {!get_param}, but returns an exeption if there is no a bind with the [key]*)
  let get_param_exn key params = List.Assoc.find_exn params ~equal:(String.equal) key

  let get_param_req key request = 
    match params request with
    |None -> None
    |Some prms -> get_param key prms

    let of_assoc (lst:(string * string) list) : t = lst

  (**[extract_query] is an example of {!extract_params} for working with query params of a request*)
  let extract_query request = all_queries request |> Lwt.return

  (**[extract_json] is an example of {!extract_params} for working with json-body requests*)
  let extract_json request = 
    let rec val_to_str acc = function
      | (k, v) :: t -> val_to_str ((k, Yojson.Safe.Util.to_string v)::acc) t
      | [] -> acc
    in
    let content = header request "Content-Type" in
    match content with
    | Some "application/json" ->
      let%lwt body' = body request in
      Yojson.Safe.from_string body' |> Yojson.Safe.Util.to_assoc |> val_to_str [] |> Lwt.return 
    | _ -> of_assoc [] |> Lwt.return
  

  let set_params ~(extractor:extractor) (inner_handler : Dream.handler) request = 
    let%lwt extracted = extractor request in
    set_field request params_field extracted;
    inner_handler request
end
