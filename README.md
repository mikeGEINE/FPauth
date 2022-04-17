# FPauth - user authentication for Dream

[![Coverage Status](https://coveralls.io/repos/github/mikeGEINE/FPauth/badge.svg?branch=coveralls)](https://coveralls.io/github/mikeGEINE/FPauth?branch=coveralls)

FPauth is an easy user authentication system for [OCaml Dream](https://github.com/aantron/dream) web-framework.
![FPauth code example](docs/code-example.svg)

The main idea behind the system is that user authentication is done via running sets of Strategies, and when one of them succeeds, user is considered to be authenticated. Authentication status is controlled by a middleware standing downstream of session middleware.
 
The system allows to:
* Control authentication in web-session;
* Get authentication status for each request via `Dream.field`;
* Check user identity with strategies;
* Use built-in strategies or custom ones;
* Add all routes for authentication and strategies at once;
* Add your own representations of authentication events or use built-in;
* Use built-in handlers or write your own;
* Extract params for authentication from requests.

Docs can be found [here](https://mikegeine.github.io/FPauth/).

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

* Add `Session_manager` middleware after your session middleware;
```OCaml
let () = run
  @@ memory_sessions
  @@ Auth.Session_manager.auth_setup
```

* Insert FPauth routes into `Dream.router` middleware. Here you specify strategies used in the authentication process, the way params are extracted, responses on main authentication events. You can also specify the scope for authentication routes;
```OCaml
  @@ router [
      Auth.Router.call [(module Password)] ~responses:(module Responses) ~extractor:extractor ~scope:"/authentication"
  ]
```
Strategies and Responses modules are passed as first-class objects which suffice `FPauth.Auth_sign.STRATEGY` and `FPauth.Auth_sign.RESPONSES` signatures correspondingly. Extractor is a function which meets `FPauth.Static.Params.extractor` type.
  * In `FPauth_responses` you can find some default responses in JSON and HTML format;
  * In `FPauth.Static.Params` you can find some default extractors from JSON-requests' bodies, forms or from query;
* Done! Your application can now authenticate users!

## Advanced Usage
It is possible to customize many aspects of the system workflow.
* You can install only the packages you actually need: 
  * `FPauth-core` contains Session_manager, Authenticator, Router, Variables, as well as Static module and signatures. These allow you to build your own workflow almost from the ground;
  * `FPauth-strategies` contains `Password` and `OTP` strategies. If you don't need them - you can choose not to have them 😉;
  * `FPauth-responses` contains some default responses on main authentication events;
* You can write your own Strategies, Responses and Params Extractors.
 