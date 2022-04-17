(**[Static] is a module containing all FPauth features, which are not dependant on {!FPauth.Auth_sign.MODEL}*)

open Dream

(** [StratResult] defines results of strategies, as well as some helpful functions. *)
module StratResult :
  sig
    
    (**['a t] defines results of strategies.*)
    type 'a t =
        Authenticated of 'a     (**Entity has been authenticated successfully. Can also be used inside a strategy with bind like [Ok 'a] result. When returned to {!FPauth.Auth_sign.AUTHENTICATOR} stops authentication process.*)
      | Rescue of Base.Error.t    (**Authentication must be stopped immediately with an error.*)
      | Redirect of response Lwt.t    (**User should be redirected in accordance with [response]. [response promise] is meant to be created by [Dream.redirect]*)
      | Next    (**Next strategy from the list in {!FPauth.Auth_sign.AUTHENTICATOR} should be used.*)
    
    (**[bind r f] returns [f r] if [r] is {!Authenticated} and [r] if anything else*)
    val bind : 'a t -> ('a -> 'b t) -> 'b t

    (**Module with Infix operators for [StratResult]*)
    module Infix : 
    sig   
        (**Infix operator for {!FPauth.Static.StratResult.bind}*)
        val ( >>== ) : 'a t -> ('a -> 'b t) -> 'b t 
    end
  end

(**[AuthResult] is a result of full authentication process. Similar to {!StratResult}, but doesn't have some types which are meaningful only for strategies. 
 [Authenticated] and [Rescue] loose content as it is stored in [Dream.field] by the end of authentication*)
module AuthResult :
sig 
    type t = 
    Authenticated                       (**Entity has been authenticated successfully.*)
    | Rescue                            (**Authentication must be stopped immediately with an error.*)
    | Redirect of Dream.response Lwt.t   (**User should be redirected in accordance with [response]. [response promise] is meant to be created by [Dream.redirect]*)
end

(**[Params] stores params of a request, either all or only required for authentication*)
module Params :
sig
    type t

    (**[params request] returns {!t} option if params were previously extracted for the request by {!set_params} middleware.*)
    val params : request -> t option

    (**[extractor] is a type of function which turns requests into params *)
    type extractor = request -> t Lwt.t

    (**[get_param key params] searches for a given [key] in [params] and returns [Some str] if it is present or [None] if it is not.*)
    val get_param : string -> t -> string option
    
    (**[get_param_exn key params] is the same as {!get_param}, but returns an exeption if the [key] is not present *)
    val get_param_exn : string -> t -> string

    (**[get_param_req key request] is a shortcut for [params request >>= get_param key]. *)
    val get_param_req : string -> request -> string option

    (**[extract_query request] extracts all query params of a request and returns them as params*)
    val extract_query : extractor
    
    (**[extract_json request] extracts all pairs of keys and values of a JSON request. {b Content-Type} must be [application/json].*)
    val extract_json : extractor

    (**[extract_form request] extracts params from forms send with [Dream.csrf_tag]. {b Content-Type} must be [application/x-www-form-urlencoded].*)
    val extract_form : ?csrf:bool -> extractor

    (**[of_assoc lst] creates [t] from assoc lists*)
    val of_assoc : (string * string) list -> t

    (**[ser_params ~extractor] is a middleware which sets params for a request, extracting them using [~extractor].*)
    val set_params : extractor:extractor -> handler -> request -> response promise
end
