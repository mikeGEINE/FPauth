(**[TOTP] is a time-based One-Time Password strategy. User's identity is verified via a password which is limited for a limited time only.*)

(** Requires {b "totp_code" param}, otherwise skipped.*)

(**Name of the strategy.*)
val name : string

(**[MODEL] contains requirements for user model in order to use the strategy*)
module type MODEL =
  sig
    type t

    (**Retrieves secret for TOTP for the user*)
    val otp_secret : t -> string

    (**Checks if TOTP has already been setup*)
    val otp_enabled : t -> bool

    (**Sets TOTP secret during setup. Returns updated user.*)
    val set_otp_secret : Dream.request -> t -> string -> t Lwt.t

    (**Enables TOTP. Returns updated user.*)
    val set_otp_enabled : Dream.request -> t -> bool -> t Lwt.t
  end

(**[RESPONSES] contains data representations for certain events*)
module type RESPONSES =
  sig
    (**This response is used to display all kinds of errors*)
    val response_error : Base.Error.t -> Dream.response Lwt.t

    (**This response is used during TOTP setup. During this step users are provided with a secret, which he needs to put in his OTP-generator.*)
    val response_secret : string -> Dream.response Lwt.t

    (**This response informs users that their TOTP has been enabled*)
    val response_enabled : Dream.response Lwt.t
  end

(**[Make] creates a strategy for a provided model with provided responses.*)
module Make :
  functor (R : RESPONSES) (M : MODEL)
    (V : FPauth_core.Auth_sign.VARIABLES with type entity = M.t)
    ->
    sig
      type entity = M.t

      (**[call] is the main function of the strategy. It needs "totp_code" param, otherwise it is skipped. Verifies, that the code is correct for user's secret.*)
      val call :
        Dream.request ->
        entity -> entity FPauth_core.Static.StratResult.t Lwt.t

      (**[routes] provide these routes in "/totp" scope:
      - GET "/generate_secret" is the first step to enable TOTP. Generates a secret for a user. The user must be authenticated first. The user must have TOTP disabled.
      - POST "/finish_setup" is the second step to enable TOTP. Should recieve "totp_code" as param, verifies it and enables TOTP if it was correct.*)
      val routes : Dream.route

      (**See {!TOTP.name}*)
      val name : string
    end

(**Module with responses for TOTP in JSON format*)
module JSON_Responses : RESPONSES
