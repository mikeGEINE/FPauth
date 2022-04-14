open FPauth__core

(**[FPauth] is a library for easy yet customizable authentication in Dream web-applications*)

(**[Static] is a module containg static type definitions, which are not dependent on {!Auth_sign.MODEL}*)
module Static = Static

(**[Make_Auth] creates a module based on {!Auth_sign.MODEL}. Provides local variables, middlewares and authenticator 
to run authentication strategies.*)
module Make_Auth :
  functor (M : Auth_sign.MODEL) ->
    sig

      (**[Variables] contains types, functions and [local] variables based on {!Auth_sign.MODEL}.*) 
      module Variables : Auth_sign.VARIABLES with type entity = M.t

      (** [SessionManager] is a module that sets local variables from session for every request via {!Auth_sign.SESSIONMANAGER.auth_setup} middleware*)
      module SessionManager : Auth_sign.SESSIONMANAGER with type entity = M.t

      (** [Authenticator] contains functions for running {!FPauth.Auth_sign.STRATEGY} list and performing logouts*)
      module Authenticator : Auth_sign.AUTHENTICATOR with type entity = M.t

      (**[Router] creates routes, needed for authentication. Contains some basic handlers and joins them with routes from strategies.*)
      module Router :
        sig
        
        (**[call ?root strat_list responses extractor] creates routes for authentication and added to [Dream.router].

        Has some basic routes:

        - "/auth" is an entrypoint for authentication. Runs all [strategies] in order they were supplied in {!Auth_sign.AUTHENTICATOR.authenticate}. Handles the results and calls corresponding handlers from {!Auth_sign.RESPONSES}.
        - "/logout" completes logout with {!Authenticator.logout} and responses with {!Auth_sign.RESPONSES.logout}

        [extractor] defines how to extract params from requests for basic routes. See {!Static.Params.extractor}.
        
        [responses] define how to respond on these basic routes after handling authentication processes.
        
        [?root] defines the root for all authentication-related routes. Default is "/".*)
          val call :
            ?root:string ->
            Authenticator.strategy list ->
            responses:(module Auth_sign.RESPONSES) ->
            extractor:Static.Params.extractor -> Dream.route
        end
    end

(**[Auth_sign] is a module containig signatures for modules which can be implemented and integrated from outside the lib, as well as signatures for some inner modules.*)
module Auth_sign = Auth_sign
