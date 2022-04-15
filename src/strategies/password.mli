(**[Password] is a simple authentication strategy which verifies identity via provided in params password.*)

(**Name of the strategy.*)
val name : string

(**[MODEL] contains requirements for user model in order to use the strategy*)
module type MODEL = sig 
    type t 

    (**[encrypted_password] is a string of hashed password, against which a given password will be verified. Argon2 is used for verification.*)
    val encrypted_password : t -> string option 
end

(**[Make] creates a strategy for a provided model.*)
module Make :
  functor (M : MODEL) ->
    sig
      type entity = M.t

      (**[call] is a main function of a strategy, which authenticates the user by "password" param. 
      The param is verified against a hashed password with Argon2.*)
      val call :
        Dream.request ->
        entity -> entity FPauth_core.Static.StratResult.t Lwt.t

      (**This strategy has no routes and returns [Dream.no_route]*)
      val routes : Dream.route

      (**See {!Password.name}*)
      val name : string
    end
