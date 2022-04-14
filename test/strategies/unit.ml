(*Main test executable*)

Alcotest.run "FPauth__strategies" [Password.tests; Otp.tests; Otp.json_tests]