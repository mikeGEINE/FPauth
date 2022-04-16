(**This module contains responses for basic FPauth events in HTML format.*)

open Base
open Dream

(**This module contains such settings as app name for titles *)
module type HTML_settings = sig val app_name : string end

(**[Make] creates HTML responses module with all required rependencies*)
module Make (V : FPauth_core.Auth_sign.VARIABLES) (S : HTML_settings) : FPauth_core.Auth_sign.RESPONSES = struct
  let login_successful req =
    let auth = Option.value_exn (field req V.authenticated) in
    Html_pages.login_successful_tmpl ~app_name:S.app_name auth |> html

  let login_error req =
    let err = Option.value_exn (field req V.auth_error) |> Error.to_string_mach in
    Html_pages.login_error_tmpl ~app_name:S.app_name err |> html

  let logout req =
    let auth = Option.value_exn (field req V.authenticated) in
    Html_pages.logout_tmpl ~app_name:S.app_name auth |> html
end

(**[make_responses ?app_name (Variables)] is a convinience function for creating HTML response module without {!HTML_settings}.
Returns first-class module.*)
let make_responses ?(app_name="FPauth") (module V : FPauth_core.Auth_sign.VARIABLES)  =
  let module S = (struct let app_name = app_name end) in
  let module HTML = Make (V) (S) in
  (module HTML : FPauth_core.Auth_sign.RESPONSES)