:- use_module(library(lists)).
:- use_module(library(clpz)).
:- use_module(library(lambda)).
:- use_module('./factgraph.pl').

fg_test(json_tests, "./test/arithmetic.xml", "./test/arithmetic.json", [
  assert_fact("/intA", int(2)),
  assert_fact("/booleanA", boolean(true)),
  assert_fact("/dollarA", dollar(2.5))
]).

fg_test(collection_tests, "./test/collections.xml", "./test/collections.json", [
  assert_fact("/jobs/#2a0c7011-4509-484f-a506-13f864cf64b2/income", dollar(3000.0)),
  assert_fact("/jobs/#2a0c7011-4509-484f-a506-13f864cf64b2/halfIncome", int(1500)),
  assert_fact("/jobs/#5ff49e28-7728-4424-9047-c444e0f01923/income", dollar(6000.0)),
  assert_fact("/numJobs", int(3)),
  assert_fact("/numJobsWithIncome", int(2)),
  % eval_path(D, G, "/numPensions", int(0)),
  assert_fact("/totalIncome", int(9000)),
  assert_fact("/maximumJobIncome", int(6000)),
  assert_fact("/highestPayingJob", "5ff49e28-7728-4424-9047-c444e0f01923"),
  assert_fact("/countHighestPayingJobOver1000", int(1)),
  assert_fact("/countHighestPayingJobOver9000", int(0))
]).

fg_test(arithmetic_tests, "./test/arithmetic.xml", none, [
  assert_fact([fact_value("/intA", int(2))], "/addTwo", int(4)),
  assert_fact([fact_value("/intA", int(2))], "/subtractTwo", int(0)),
  assert_fact([fact_value("/intA", int(2))], "/multiplyByFour", int(8)),
  assert_fact([fact_value("/intA", int(2))], "/divideByTwo", int(1)),
  assert_fact([fact_value("/intA", int(3))], "/modTwo", int(1)),
  assert_fact([fact_value("/dollarA", dollar(2.5))], "/round", int(3)),
  assert_fact([fact_value("/dollarA", dollar(2.4))], "/round", int(2)),
  assert_fact([fact_value("/dollarA", dollar(2))], "/round", int(2)),
  assert_fact([fact_value("/dollarA", dollar(2.6))], "/floor", int(2)),
  assert_fact([fact_value("/intA", int(2))], "/max", int(2))
]).

fg_test(comparitor_tests, "./test/arithmetic.xml", none, [
  assert_fact([fact_value("/booleanA", boolean(true))], "/isTrue", boolean(true)),
  assert_fact([fact_value("/booleanA", boolean(true))], "/isFalse", boolean(false)),
  assert_fact([fact_value("/intA", int(2))], "/equalsTwo", boolean(true)),
  assert_fact([fact_value("/intA", int(3))], "/equalsTwo", boolean(false)),
  assert_fact([fact_value("/intA", int(2))], "/notTwo", boolean(false)),
  assert_fact([fact_value("/intA", int(3))], "/notTwo", boolean(true)),
  assert_fact([fact_value("/intA", int(1))], "/greaterThanTwo", boolean(false)),
  assert_fact([fact_value("/intA", int(2))], "/greaterThanTwo", boolean(false)),
  assert_fact([fact_value("/intA", int(3))], "/greaterThanTwo", boolean(true)),
  assert_fact([fact_value("/intA", int(1))], "/lessThanTwo", boolean(true)),
  assert_fact([fact_value("/intA", int(2))], "/lessThanTwo", boolean(false)),
  assert_fact([fact_value("/intA", int(3))], "/lessThanTwo", boolean(false)),
  assert_fact([fact_value("/intA", int(1))], "/greaterThanOrEqualToTwo", boolean(false)),
  assert_fact([fact_value("/intA", int(2))], "/greaterThanOrEqualToTwo", boolean(true)),
  assert_fact([fact_value("/intA", int(3))], "/greaterThanOrEqualToTwo", boolean(true)),
  assert_fact([fact_value("/intA", int(1))], "/lessThanOrEqualToTwo", boolean(true)),
  assert_fact([fact_value("/intA", int(2))], "/lessThanOrEqualToTwo", boolean(true)),
  assert_fact([fact_value("/intA", int(3))], "/lessThanOrEqualToTwo", boolean(false))
]).

fg_test(condition_tests, "./test/conditions.xml", none, [
  assert_fact([fact_value("/input", int(2))], "/input", int(2)),
  assert_fact([], "/input", int(0)),
  assert_fact([fact_value("/override", boolean(true))], "/input", int(100)),
  assert_fact([fact_value("/input", int(2)), fact_value("/override", boolean(true))], "/input", int(100)),
  assert_fact([], "/switch2", int(2)),
  assert_fact([fact_value("/override", boolean(true))], "/switch2", int(3)),
  assert_fact([fact_value("/override", boolean(false))], "/switch2", int(2))
]).

twe_facts :-
  println("TWE facts test"),
  % This asserts that there is only one possible evaluation of the Fact Dictionary
  findall(Fs, load_fact_dir("./test/twe-facts/", Fs), [D]),
  load_graph("./test/fg-1.json", D, _),
  member(fact("/totalOwed", _, _, _, _), D).

run :-
  findall(fg_test(N,DP,GP,As), fg_test(N,DP,GP,As), Ts),
  maplist(run_test, Ts, Resultss),
  append(Resultss, Results),
  tpartition(is_pass_t, Results, _, Failures),
  length(Failures, L),
  if_(L #= 0, println("✅ All tests passed!"), (println("❌ Tests failed"), halt(1))).

run_test(fg_test(Name, DPath, GPath, Assertions), Results) :-
  load_dict(DPath, D),
  if_(dif(GPath, none), load_graph(GPath, D, G), G = []),
  maplist(run_assertion(D, G), Assertions, Results),
  print_results_summary(Name, Results).

is_pass_t(Result, T) :- functor(Result, F, _), =(F, pass, T).
attempt_eval(D, G, Path, V) :-  eval_path(D, G, Path, V), !; V = incomplete.

run_assertion(D, G, assert_fact(Path, EV), Res) :-
  attempt_eval(D, G, Path, Actual),
  if_(=(Actual, EV), Res = pass(Path), Res = fail(Path, Actual, EV)).
run_assertion(D, G0, assert_fact(G1, Path, EV), Res) :-
  append(G0, G1, G),
  attempt_eval(D, G, Path, Actual),
  if_(=(Actual, EV), Res = pass(Path), Res = fail(Path, Actual, EV)).

failure_details(fail(Path, Actual, EV), S) :-
  phrase(format_("~s: ~q expected, ~q actual", [Path, Actual, EV]), S).
print_results_summary(Name, Results) :-
  tpartition(is_pass_t, Results, Passes, Failures),
  length(Passes, PL),
  length(Failures, FL),
  format("~a: ~d passed, ~d failed~n", [Name, PL, FL]),
  maplist(failure_details, Failures, Ss),
  maplist(println, Ss).

% term_expansion(fg_test(Name, DPath, GPath, Assertions), (Name :- Body)) :-
%   Body = run_test(DPath, GPath, Assertions, Results).

% writeln(S) :- write_term(S, [ double_quotes(true) ]).
println(S) :- format("~s~n", [S]).

