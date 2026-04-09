:- use_module(library(lists)).
:- use_module('./factgraph.pl').

run :-
  println("Running tests"),
  (
    tests -> println("Tests passed!"), halt(0)
  ; println("Tests failed"), halt(1)
  ).

tests :-
  json_tests,
  arithmetic_tests,
  collection_tests,
  comparitor_tests,
  condition_tests,
  twe_facts.

json_tests :-
  println("json tests"),
  load_dict("./test/arithmetic.xml", D),
  load_graph("./test/arithmetic.json", D, G),
  eval_path(D, G, "/intA", 2),
  eval_path(D, G, "/booleanA", true),
  eval_path(D, G, "/dollarA", 2.5).

arithmetic_tests :-
  println("arithmetic tests"),
  load_dict("./test/arithmetic.xml", D),
  eval_path(D, [fact_value("/intA", int(2))], "/addTwo", 4),
  eval_path(D, [fact_value("/intA", int(2))], "/subtractTwo", 0),
  eval_path(D, [fact_value("/intA", int(2))], "/multiplyByFour", 8),
  eval_path(D, [fact_value("/intA", int(2))], "/divideByTwo", 1.0),
  eval_path(D, [fact_value("/intA", int(3))], "/modTwo", 1),
  eval_path(D, [fact_value("/dollarA", dollar(2.5))], "/round", 3),
  eval_path(D, [fact_value("/dollarA", dollar(2.4))], "/round", 2),
  eval_path(D, [fact_value("/dollarA", dollar(2))], "/round", 2),
  eval_path(D, [fact_value("/dollarA", dollar(2.6))], "/floor", 2),
  eval_path(D, [fact_value("/intA", int(2))], "/max", 2),
  true.

collection_tests :-
  println("collection tests"),
  load_dict("./test/collections.xml", D),
  load_graph("./test/collections.json", D, G),
  eval_path(D, G, "/jobs", Js), length(Js, 3),
  eval_path(D, G, "/jobs/#2a0c7011-4509-484f-a506-13f864cf64b2/income", 3000.0),
  eval_path(D, G, "/jobs/#2a0c7011-4509-484f-a506-13f864cf64b2/halfIncome", 1500.0),
  eval_path(D, G, "/jobs/#5ff49e28-7728-4424-9047-c444e0f01923/income", 6000.0),
  eval_path(D, G, "/numJobs", 3),
  eval_path(D, G, "/numJobsWithIncome", 2),
  % eval_path(D, G, "/numPensions", 0),
  eval_path(D, G, "/totalIncome", 9000.0),
  eval_path(D, G, "/maximumJobIncome", 6000.0),
  eval_path(D, G, "/highestPayingJob", "5ff49e28-7728-4424-9047-c444e0f01923"),
  eval_path(D, G, "/countHighestPayingJobOver1000", 1),
  eval_path(D, G, "/countHighestPayingJobOver9000", 0),
  true.

comparitor_tests :-
  println("comparitor tests"),
  load_dict("./test/arithmetic.xml", D),
  eval_path(D, [fact_value("/booleanA", boolean(true))], "/isTrue", true),
  eval_path(D, [fact_value("/booleanA", boolean(true))], "/isFalse", false),
  eval_path(D, [fact_value("/intA", int(2))], "/equalsTwo", true),
  eval_path(D, [fact_value("/intA", int(3))], "/equalsTwo", false),
  eval_path(D, [fact_value("/intA", int(2))], "/notTwo", false),
  eval_path(D, [fact_value("/intA", int(3))], "/notTwo", true),
  eval_path(D, [fact_value("/intA", int(1))], "/greaterThanTwo", false),
  eval_path(D, [fact_value("/intA", int(2))], "/greaterThanTwo", false),
  eval_path(D, [fact_value("/intA", int(3))], "/greaterThanTwo", true),
  eval_path(D, [fact_value("/intA", int(1))], "/lessThanTwo", true),
  eval_path(D, [fact_value("/intA", int(2))], "/lessThanTwo", false),
  eval_path(D, [fact_value("/intA", int(3))], "/lessThanTwo", false),
  eval_path(D, [fact_value("/intA", int(1))], "/greaterThanOrEqualToTwo", false),
  eval_path(D, [fact_value("/intA", int(2))], "/greaterThanOrEqualToTwo", true),
  eval_path(D, [fact_value("/intA", int(3))], "/greaterThanOrEqualToTwo", true),
  eval_path(D, [fact_value("/intA", int(1))], "/lessThanOrEqualToTwo", true),
  eval_path(D, [fact_value("/intA", int(2))], "/lessThanOrEqualToTwo", true),
  eval_path(D, [fact_value("/intA", int(3))], "/lessThanOrEqualToTwo", false),
  true.

condition_tests :-
  println("condition tests"),
  load_dict("./test/conditions.xml", D),
  eval_path(D, [fact_value("/input", int(2))], "/input", 2),
  eval_path(D, [], "/input", 0),
  eval_path(D, [fact_value("/override", boolean(true))], "/input", 100),
  eval_path(D, [fact_value("/input", int(2)), fact_value("/override", boolean(true))], "/input", 100),
  true.

twe_facts :-
  println("TWE facts test"),
  % This asserts that there is only one possible evaluation of the Fact Dictionary
  findall(Fs, load_fact_dir("./test/twe-facts/", Fs), [D]),
  load_graph("./test/fg-1.json", D, _),
  member(fact("/totalOwed", _, _, _, _), D).

println(S) :- format("~s~n", [S]).

