open Base
open Dream

(** [MODEL] is a signature for modules handling authenticable entities*)
module type MODEL = sig
  (** Some representation of an entity to be authenticated *)
  type t

  (** [serialize] is to make a [string] from [t] to store in a session between requests. It should represent entity
in a way allowing to regain it later with {!val:deserialize}*)
  val serialize : t -> string

  (** [deserialize] is to make [t] from [string] to use it in handlers. The [string] should be created by {!val:serialize}.
  Returns: [Ok t] if deserialization was successful or [Error string] if an error occured*)
  val deserialize : string -> (t, Error.t) Result.t

  (**[identificate] is to define which user is trying to authenticate. Retrieves its representation or returns an error*)
  val identificate : request -> (t, Error.t) Result.t promise

  (**[applicable_strats] returns a list of strats which can be applied to the whole [MODEL] or to certain {!t}.
  Strings are to be the same as {!STRATEGY.name} *)
  val applicable_strats : t -> string list
end

(** [SESSIONMANAGER] is a signature for a functor producing modules for controlling sessions and
authentications of entities with type {!MODEL.t}*)
module type SESSIONMANAGER = sig
  (** type [entity] is a type of authenticatable entity equal to {!MODEL.t}*)
  type entity
  
  (**[auth_setup] is a middleware which controlls session, setups [field] variables and helper functions for downstream handlers*)
  val auth_setup : middleware
end

(**[STRATEGY] is a module which contains functions for entity authentications in a certain method, as well as supporting routes and functions*)
module type STRATEGY = sig
  
  type entity

  (**[call] is a core function of a strategy. It determines ways of authenticating an entity*)
  val call : request -> entity -> entity Static.StratResult.t Lwt.t

  (**[routes] defines some additional routes to handlers of a strategy if they are needed. Can contain multiple routes using [Dream.scope]*)
  val routes : route

  (**[name] is a name of the STRATEGY. Used to define wether the strat can be applied to a certain entity.*)
  val name : string
end

(** [AUTHENTICATOR] is a signature for a functor to create authenticators of various entities over various strategies (See {!STRATEGY})*)
module type AUTHENTICATOR = sig
  (** type [entity] is a type of authenticatable entity equal to {!MODEL.t}*)
  type entity

  (** [strategy] is a function that authenticates an entity from a request.*)
  type strategy = (module STRATEGY with type entity = entity)

  (**[authenticate] runs several authentication strategies for a request and defines, whether overall authentication was successful or not*)
  val authenticate : strategy list -> request -> Static.AuthResult.t promise

  (**[logout] invalidates session, which resets authentication status to [false]*)
  val logout : Dream.request -> unit Lwt.t
end

(** [VARIABLES] is a module containing field variables based on {!MODEL}*)
module type VARIABLES = sig
  (** type [entity] is a type of authenticatable entity equal to {!MODEL.t}*)
  type entity

  (** [authenticated] is a variable valid for a single request, indicates if authentication has been previously completed.
  Should be set in {!SESSIONMANAGER.auth_setup}*)
  val authenticated : bool field

  (**[current_user] is a variable valid for a single request, holds an authenticated entity from a session.
    Should be set in {!SESSIONMANAGER.auth_setup}*)
  val current_user : entity field

  (** [auth_error] is a field with error which occured during any stage of authentication*)
  val auth_error : Error.t field
end

(** [RESPONSES] is a module which defines how the library should represent some basic events*)
module type RESPONSES = sig
  (**[login_successful] is triggered when authentication has been successful*)
  val login_successful : request -> response promise

  (**[login_error] is triggered if there was any kind of failure during authentication*)
  val login_error : request -> response promise

  (**[logout] is triggered after authentication has been reset*)
  val logout : request -> response promise
end
