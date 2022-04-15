(**[FPauth_core] is a library for easy yet customizable authentication in Dream web-applications*)

(**[Static] is a module containg static type definitions, which are not dependent on {!Auth_sign.MODEL}*)
module Static = Static

module Variables = Variables
module Session_manager = Session_manager
module Authenticator = Authenticator
module Router = Router

(**[Make_Auth] creates a module based on {!Auth_sign.MODEL}. Provides local variables, middlewares and authenticator 
to run authentication strategies.*)
module Make_Auth :
  functor (M : Auth_sign.MODEL) ->
    sig

      (**[Variables] contains types, functions and [local] variables based on {!Auth_sign.MODEL}.*) 
      module Variables : Auth_sign.VARIABLES with type entity = M.t

      (** [SessionManager] is a module that sets local variables from session for every request via {!Auth_sign.SESSIONMANAGER.auth_setup} middleware*)
      module Session_manager : Auth_sign.SESSIONMANAGER with type entity = M.t

      (** [Authenticator] contains functions for running {!FPauth.Auth_sign.STRATEGY} list and performing logouts*)
      module Authenticator : Auth_sign.AUTHENTICATOR with type entity = M.t

      (**[Router] creates routes, needed for authentication. Contains some basic handlers and joins them with routes from strategies.*)
      module Router : Auth_sign.ROUTER with type entity = M.t
    end

(**[Auth_sign] is a module containig signatures for modules which can be implemented and integrated from outside the lib, as well as signatures for some inner modules.*)
module Auth_sign = Auth_sign
