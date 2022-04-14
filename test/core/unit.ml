(*Main test executable*)

Alcotest.run "FPauth" [Static.strat_result; 
                        Static.params; 
                        Session_manager.tests;
                        Authenticator.tests;
                        Router.tests]