(*Testing Static*)
open FPauth_core.Static
open Base
open Setup

let stratresult_pp pp_val formatter s =
  let open Fmt in
  match s with
  | StratResult.Authenticated smth -> pf formatter "Authenticated: "; pp_val formatter smth
  | Rescue err -> pf formatter "Rescue: "; Error.pp formatter err
  | Next -> pf formatter "Next"
  | Redirect _ -> pf formatter "Redirect"

let stratresult_eq eq a b =
  match a, b with
  | StratResult.Authenticated a_v, StratResult.Authenticated b_v -> eq a_v b_v
  | Rescue a_err, Rescue b_err -> Error.equal a_err b_err
  | Next, Next -> true
  | Redirect a_prom, Redirect b_prom -> 
    let a_resp, b_resp = Lwt_main.run (Lwt.both a_prom b_prom) in
    let pair_equal eq a b = eq (fst a) (fst b) && eq (snd a) (snd b) in
    List.equal (pair_equal String.equal) (Dream.all_headers a_resp) (Dream.all_headers b_resp)
  | _ -> false

let stratresult_string = 
  Alcotest.testable (stratresult_pp String.pp) (stratresult_eq String.equal)

let strat_result = "FPauth.Static: StratResult", [
  "bind_authenticated" -: begin fun () ->
    let auth = StratResult.Authenticated "first" in
    let res_func prev = StratResult.Authenticated (prev^" correct") in
    let expected = StratResult.Authenticated "first correct"
    in
    StratResult.bind auth res_func |> Alcotest.(check stratresult_string) "authenticated" expected
  end;

  "bind_rescue" -: begin fun () ->
    let auth = StratResult.Rescue (Error.of_string "test_error") in
    let res_func prev = StratResult.Authenticated (prev^" correct") in
    let expected = StratResult.Rescue (Error.of_string "test_error")
    in
    StratResult.bind auth res_func |> Alcotest.(check stratresult_string) "rescue" expected
  end;

  "bind_next" -: begin fun () ->
    let auth = StratResult.Next in
    let res_func prev = StratResult.Authenticated (prev^" correct") in
    let expected = StratResult.Next
    in
    StratResult.bind auth res_func |> Alcotest.(check stratresult_string) "next" expected
  end;

  "bind_redirect" -: begin fun () ->
    let auth = StratResult.Redirect (Dream.redirect (Dream.request "") "/test_url") in
    let res_func prev = StratResult.Authenticated (prev^" correct") in
    let expected = StratResult.Redirect (Dream.redirect (Dream.request "") "/test_url")
    in
    StratResult.bind auth res_func |> Alcotest.(check stratresult_string) "redirect" expected
  end
]

let params = "FPauth.Static: Params", [
  "params in field" -: begin fun () ->
    let req = Dream.request "" in
    let fake_extractor _ = Params.of_assoc [("key", "value")] |> Lwt.return in
    let handler request = 
      let param = Params.get_param_req "key" request in
      Dream.respond ~headers:[("key", Option.value param ~default:"")] ""
    in
    let response = Dream.test (Params.set_params ~extractor:(fake_extractor) handler) req in
    let header = Dream.headers response "key" in
    let expected = ["value"] in
    header |> Alcotest.(check (list string)) "params in field" expected
  end;

  "no param found" -: begin fun () ->
    let req = Dream.request "" in
    let handler request = 
      let param = Params.get_param_req "key" request in
      Dream.respond ~headers:[("key", Option.value param ~default:"")] ""
    in
    let response = Dream.test handler req in
    let header = Dream.headers response "key" in
    let expected = [""] in
    header |> Alcotest.(check (list string)) "no param in field" expected
  end;

  "get param exn" -: begin fun () ->
    let params = Params.of_assoc [("key", "value")] in
    let expected = "value" in
    params |> Params.get_param_exn "key" |> Alcotest.(check string) "get_param_exn" expected
  end;

  "query param extractor" -: begin fun () ->
    let req = Dream.request ~target:"/?key=value" "" in
    let params = Params.extract_query req |> Lwt_main.run in
    let expected = Some "value" in
    params |> Params.get_param "key" |> Alcotest.(check (option string)) "extract_query" expected
  end;

  "json param extractor" -: begin fun () ->
    let req = Dream.request ~headers:[("Content-Type", "application/json")] "{\"key\" : \"value\"}" in
    let params = Params.extract_json req |> Lwt_main.run in
    let expected = Some "value" in
    params |> Params.get_param "key" |> Alcotest.(check (option string)) "extract_json" expected
  end;

  "json param extractor with unsupported content" -: begin fun () ->
    let req = Dream.request  "" in
    let params = Params.extract_json req |> Lwt_main.run in
    let expected = None in
    params |> Params.get_param "key" |> Alcotest.(check (option string)) "extract_json" expected
  end;
]