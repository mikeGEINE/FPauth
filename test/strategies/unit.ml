(*Main test executable*)

Alcotest.run "FPauth__strategies" [Password.tests; Totp.tests; Totp.json_tests; Totp.html_tests]