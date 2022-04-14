(*Main test executable*)

Alcotest.run "FPauth-core" [Static.strat_result; 
                        Static.params; 
                        Session_manager.tests;
                        Authenticator.tests;
                        Router.tests]