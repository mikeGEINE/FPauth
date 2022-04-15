# FPauth - user authentication for Dream

FPauth is an easy user authentication system for [OCaml Dream](https://github.com/aantron/dream) web-framework. 
The system allows to:
* Control authentication in web-session;
* Get authentication status for each request via `Dream.field`;
* Check user identity with strategies;
* Use built-in strategies or custom ones;
* Add all routes for authentication and strategies at once;
* Add your own representations of authentication events or use built-in;
* Use built-in handlers or write your own;
* Extract params for authentication from requests.

## Quick setup

In order to start using FPauth, in your project you should:
* Initialize the system with a model of user, which suffices `FPauth.Auth_sign.MODEL`. Basically it requires functions which define, how to put and restore your users in session (`serialize` and `deserialize`), how to find users from request params (`identificate`) and which strategies can be applied to a user (`applicable_strats`);
```OCaml
module Auth = FPauth.Make_Auth (User)
```

* Initialize strategies you are going to use to verify users' identities. 
There are some strategies in `FPauth_strategies`. `Password` can be used for password authentication, passwords are to be hashed with Argon2. `OTP` is a time-based OTP strategy, it contains routes for setting the strategy up for an already authenticated user. Strategies can have additional requirements for your models, as well as need some other modules.
```Ocaml
module Password = FPauth_strategies.Password.Make (User)
```

* Add `SessionManager` middleware after your session middleware;
```OCaml
let () = run ~interface:"0.0.0.0" ~port:8080
  @@ memory_sessions
  @@ Auth.SessionManager.auth_setup
```

* Insert FPauth routes into `Dream.router` middleware. Here you specify strategies used in the authentication process, the way params are extracted, responses on main authentication events. You can also specify the scope for authentication routes;
```OCaml
  @@ router [
      Auth.Router.call [(module Password)] ~responses:(module Responses) ~extractor:extractor ~scope:"/authentication"
  ]
```
Strategies and Responses modules are passed as first-class objects which suffice `FPauth.Auth_sign.STRATEGY` and `FPauth.Auth_sign.RESPONSES` signatures correspondingly. Extractor is a function which meets `FPauth.Static.Params.extractor` type.
  * In `FPauth_responses` you can find some default responses in JSON format (HTML is in progress);
  * In `FPauth.Static.Params` you can find some default extractors from JSON-requests' bodies or from query;
* Done! Your application can now authenticate users!

## Advanced Usage
It is possible to customize many aspects of the system workflow.
* You can install only the packages you actually need: 
  * `FPauth-core` contains SessionManager, Authenticator, Router, Variables, as well as Static module and signatures. These allow you to build your own workflow almost from the ground;
  * `FPauth-strategies` contains `Password` and `OTP` strategies. If you don't need them - you can choose not to have them 😉;
  * `FPauth-responses` contains some default responses on main authentication events;
* You can write your own Strategies, Responses and Params Extractors.
 