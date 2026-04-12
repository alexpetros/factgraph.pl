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
  eval_path(D, G, "/intA", int(2)),
  eval_path(D, G, "/booleanA", boolean(true)),
  eval_path(D, G, "/dollarA", dollar(2.5)).

arithmetic_tests :-
  println("arithmetic tests"),
  load_dict("./test/arithmetic.xml", D),
  eval_path(D, [fact_value("/intA", int(2))], "/addTwo", int(4)),
  eval_path(D, [fact_value("/intA", int(2))], "/subtractTwo", int(0)),
  eval_path(D, [fact_value("/intA", int(2))], "/multiplyByFour", int(8)),
  eval_path(D, [fact_value("/intA", int(2))], "/divideByTwo", int(1)),
  eval_path(D, [fact_value("/intA", int(3))], "/modTwo", int(1)),
  eval_path(D, [fact_value("/dollarA", dollar(2.5))], "/round", int(3)),
  eval_path(D, [fact_value("/dollarA", dollar(2.4))], "/round", int(2)),
  eval_path(D, [fact_value("/dollarA", dollar(2))], "/round", int(2)),
  eval_path(D, [fact_value("/dollarA", dollar(2.6))], "/floor", int(2)),
  eval_path(D, [fact_value("/intA", int(2))], "/max", int(2)),
  true.

collection_tests :-
  println("collection tests"),
  load_dict("./test/collections.xml", D),
  load_graph("./test/collections.json", D, G),
  eval_path(D, G, "/jobs", Js), length(Js, 3),
  eval_path(D, G, "/jobs/#2a0c7011-4509-484f-a506-13f864cf64b2/income", dollar(3000.0)),
  eval_path(D, G, "/jobs/#2a0c7011-4509-484f-a506-13f864cf64b2/halfIncome", int(1500)),
  eval_path(D, G, "/jobs/#5ff49e28-7728-4424-9047-c444e0f01923/income", dollar(6000.0)),
  eval_path(D, G, "/numJobs", int(3)),
  eval_path(D, G, "/numJobsWithIncome", int(2)),
  % eval_path(D, G, "/numPensions", int(0)),
  eval_path(D, G, "/totalIncome", int(9000)),
  eval_path(D, G, "/maximumJobIncome", int(6000)),
  eval_path(D, G, "/highestPayingJob", "5ff49e28-7728-4424-9047-c444e0f01923"),
  eval_path(D, G, "/countHighestPayingJobOver1000", int(1)),
  eval_path(D, G, "/countHighestPayingJobOver9000", int(0)),
  true.

comparitor_tests :-
  println("comparitor tests"),
  load_dict("./test/arithmetic.xml", D),
  eval_path(D, [fact_value("/booleanA", boolean(true))], "/isTrue", boolean(true)),
  eval_path(D, [fact_value("/booleanA", boolean(true))], "/isFalse", boolean(false)),
  eval_path(D, [fact_value("/intA", int(2))], "/equalsTwo", boolean(true)),
  eval_path(D, [fact_value("/intA", int(3))], "/equalsTwo", boolean(false)),
  eval_path(D, [fact_value("/intA", int(2))], "/notTwo", boolean(false)),
  eval_path(D, [fact_value("/intA", int(3))], "/notTwo", boolean(true)),
  eval_path(D, [fact_value("/intA", int(1))], "/greaterThanTwo", boolean(false)),
  eval_path(D, [fact_value("/intA", int(2))], "/greaterThanTwo", boolean(false)),
  eval_path(D, [fact_value("/intA", int(3))], "/greaterThanTwo", boolean(true)),
  eval_path(D, [fact_value("/intA", int(1))], "/lessThanTwo", boolean(true)),
  eval_path(D, [fact_value("/intA", int(2))], "/lessThanTwo", boolean(false)),
  eval_path(D, [fact_value("/intA", int(3))], "/lessThanTwo", boolean(false)),
  eval_path(D, [fact_value("/intA", int(1))], "/greaterThanOrEqualToTwo", boolean(false)),
  eval_path(D, [fact_value("/intA", int(2))], "/greaterThanOrEqualToTwo", boolean(true)),
  eval_path(D, [fact_value("/intA", int(3))], "/greaterThanOrEqualToTwo", boolean(true)),
  eval_path(D, [fact_value("/intA", int(1))], "/lessThanOrEqualToTwo", boolean(true)),
  eval_path(D, [fact_value("/intA", int(2))], "/lessThanOrEqualToTwo", boolean(true)),
  eval_path(D, [fact_value("/intA", int(3))], "/lessThanOrEqualToTwo", boolean(false)),
  true.

condition_tests :-
  println("condition tests"),
  load_dict("./test/conditions.xml", D),
  eval_path(D, [fact_value("/input", int(2))], "/input", int(2)),
  eval_path(D, [], "/input", int(0)),
  eval_path(D, [fact_value("/override", boolean(true))], "/input", int(100)),
  eval_path(D, [fact_value("/input", int(2)), fact_value("/override", boolean(true))], "/input", int(100)),
  eval_path(D, [], "/switch2", int(2)),
  eval_path(D, [fact_value("/override", boolean(true))], "/switch2", int(3)),
  eval_path(D, [fact_value("/override", boolean(false))], "/switch2", int(2)),
  true.

twe_facts :-
  println("TWE facts test"),
  % This asserts that there is only one possible evaluation of the Fact Dictionary
  findall(Fs, load_fact_dir("./test/twe-facts/", Fs), [D]),
  load_graph("./test/fg-1.json", D, _),
  member(fact("/totalOwed", _, _, _, _), D).

println(S) :- format("~s~n", [S]).

