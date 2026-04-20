/*
 * factgraph.pl - a single-file Fact Graph implementation, in Prolog
 *
 * Requires Scryer Prolog.
 *
 * Official IRS Fact Graph: https://github.com/IRS-Public/fact-graph
 * Execution model inspired by: https://www.metalevel.at/lisprolog/lisprolog.pl
 */
:- use_module(library(pio)).
:- use_module(library(clpz)).
:- use_module(library(charsio)).
:- use_module(library(debug)).
:- use_module(library(sgml)).
:- use_module(library(xpath)).
:- use_module(library(dcgs)).
:- use_module(library(dif)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(files)).
:- use_module(library(time)).
:- use_module(library(lambda)).
:- use_module(library(serialization/json)).

/* ----------------------------------------------------------------
 * Fact path resolution utilities
 * ---------------------------------------------------------------- */

path_segment([H|T]) --> [H], { [H] \= "/" }, path_segment(T).
path_segment([])    --> [].

item_id(Id)                  --> "#", path_segment(Id).
resolved_path(Coll, Sub, Id) --> seq(Coll), "/", item_id(Id), "/", seq(Sub).
canonical_path(Coll, Sub)    --> seq(Coll), "/*/", seq(Sub).
parent_path(Coll)            --> resolved_path(Coll, _, _) | canonical_path(Coll, _).
relative_path(Sub)           --> "../", seq(Sub).

path_parent_collection(Path, Parent) :- phrase(parent_path(Parent), Path).
relative_path_parent_resolved(RelPath, Parent, Resolved) :-
  phrase(relative_path(Sub), RelPath),
  phrase(resolved_path(Coll, _, Id), Parent),
  phrase(resolved_path(Coll, Sub, Id), Resolved).

% TODO see if these can be made less imperative
collection_id_path(Coll, Id, Path) :- append([Coll, "/#", Id], Path).
resolved_to_canonical(R, C) :-
  phrase(resolved_path(Coll, Sub, _), R),
  phrase(canonical_path(Coll, Sub), C).
canonical_to_resolved(C, Id, R) :-
  phrase(canonical_path(Coll, Sub), C),
  phrase(resolved_path(Coll, Sub, Id), R).

/* ----------------------------------------------------------------
 * Fact Dictionary Parser
 * ---------------------------------------------------------------- */

% Trimmed XML file has no whitespace-only string nodes and trims the rest
% It's much faster with the cut but look into taking it out
trim_xml([N|Ns]) --> { phrase(ws, N) }, trim_xml(Ns), !.
trim_xml([N|Ns]) --> { phrase(trim_str(S), N) }, [S], trim_xml(Ns).
trim_xml([element('',_,_)|Ns]) --> trim_xml(Ns). % These are comments
trim_xml([element(E, A, C)|Ns]) -->
  { dif('', E), phrase(trim_xml(C), Tc) },
  [element(E, A, Tc)],
  trim_xml(Ns).
trim_xml([]) --> [].

% Date parsing predicates
seql(Cs, L)    --> seq(Cs), { length(Cs, L) }.
day(YCs, MCs, DCs)  -->
  seql(YCs, 4), "-", seql(MCs, 2), "-", seql(DCs, 2).
  % { number_chars(Y, YCs), number_chars(M, MCs), number_chars(D, DCs) }.

% String parsing predicates
ws                    --> [W], { char_type(W, whitespace) }, ws.
ws                    --> [].
trim_str([H|T])       --> ws, seq([H|T]), { \+ char_type(H, whitespace) }, ws, call(eos), !.
trim_str([])          --> [].
eos([], []).

% Nonterminals to make XML parsing a little more elegant
element(Name, Cs)        --> [element(Name, _, Cs)].
element(Name, Attrs, Cs) --> [element(Name, Attrs, Cs)].

% Writable types
type(int)             --> element('Int',[]).
type(boolean)         --> element('Boolean',[]).
type(dollar)          --> element('Dollar',[]).
type(day)             --> element('Day',[]).
type(collection)      --> element('Collection',[]).
type(enum(Op))        --> element('Enum', [optionsPath=Op], _).
type_elem(Type)       --> ..., type(Type), ... .

% Values used in derived calculations

value(int(V))            --> element('Int', [S]), { number_chars(V, S) }.
value(dollar(V))         --> element('Dollar', [S]), { number_chars(V, S) }.
value(boolean(V))        --> element('Boolean', [S]), { atom_chars(V, S) }.
value(boolean(true))     --> element('True', []).
value(boolean(false))    --> element('False', []).
value(day(Y,M,D))        --> element('Day', [Cs]), { phrase(day(Y,M,D), Cs) }.
value(days(V))           --> element('Days', [S]), { number_chars(V, S) }.
value(rational(V))       --> element('Rational', [V]).
value(enum(V, Op))       --> element('Enum', [optionsPath=Op], [V]).
value(enumOpts(V))       --> element('EnumOptions', V).
value(today(V))          --> element('Today', [V]).
value(lastDayOfMonth(V)) --> element('LastDayOfMonth', [V]).

% Limits for writable facts
limit_exp(E)       --> ..., exp(E), ... .
limit(min(E))      --> element('Limit', [type="Min"], C), { phrase(limit_exp(E), C) }.
limit(max(E))      --> element('Limit', [type="Max"], C), { phrase(limit_exp(E), C) }.
limit_elem([E|Es]) --> limit(E), limit_elem(Es).
limit_elem([])     --> [].

placeholder(E)  --> ..., value(E), ... .

condition(E)        --> element('Condition', C), { exps(C, [E]) }.
default(E)          --> element('Default', C), { exps(C, [E]) }.
override(Cond, Def) --> condition(Cond), default(Def).

dependency(P)      --> element('Dependency', [path=P], []).

exps_l_r([L0, R0], L, R) :-
  L0 = element('Left', _, LC),
  R0 = element('Right', _, RC),
  exps(LC, [L]),
  exps(RC, [R]).

% Convenience predicates for recursive parsing of children
exps(C, Es) :- phrase(expressions(Es), C).

exp(switch(Es))   --> element('Switch', C), { exps(C, Es) }.
exp(case(W, T))   --> element('Case', C), { exps(C, [W, T]) }.
exp(E)            --> element('When', C), { exps(C, [E]) }.
exp(E)            --> element('Then', C), { exps(C, [E]) }.

exp(greaterOf(Es))  --> element('GreaterOf', C), { exps(C, Es) }.
exp(lesserOf(Es))   --> element('LesserOf', C), { exps(C, Es) }.

exp(not(E))          --> element('Not', C), { exps(C, [E]) }.
exp(equal(L, R))     --> element('Equal', C), { exps_l_r(C, L, R) }.
exp(notEqual(L, R))  --> element('NotEqual', C), { exps_l_r(C, L, R) }.
exp(all(Es))         --> element('All', C), { exps(C, Es) }.
exp(any(Es))         --> element('Any', C), { exps(C, Es) }.
exp(isComplete(E))   --> element('IsComplete', C), { exps(C, [E]) }.

exp(<(L, R))  --> element('LessThan',C), { exps_l_r(C, L, R) }.
exp(>(L, R))  --> element('GreaterThan',C), { exps_l_r(C, L, R) }.
exp(>=(L,R))  --> element('GreaterThanOrEqual',C), { exps_l_r(C, L, R) }.
exp(=<(L,R))  --> element('LessThanOrEqual',C), { exps_l_r(C, L, R) }.

exp(round(E))         --> element('Round',C), { exps(C, [E]) }.
exp(add(Es))          --> element('Add',C), { exps(C, Es) }.
exp(subtract(Es))     --> element('Subtract',C), { exps(C, Es) }.
exp(minuend(E))       --> element('Minuend',C), { exps(C, [E]) }.
exp(subtrahends(Es))  --> element('Subtrahends',C), { exps(C, Es) }.
exp(multiply(Es))     --> element('Multiply',C), { exps(C, Es) }.
exp(divide(Es))       --> element('Divide',C), { exps(C, Es) }.
exp(dividend(E))      --> element('Dividend',C), { exps(C, [E]) }.
exp(divisors(Es))     --> element('Divisors',C), { exps(C, Es) }.
exp(stepwiseMult(Es)) --> element('StepwiseMultiply',C), { exps(C, Es) }.
exp(multiplicand(Es)) --> element('Multiplicand',C), { exps(C, Es) }.
exp(rate(Es))         --> element('Rate',C), { exps(C, Es) }.
exp(ceiling(E))       --> element('Ceiling',C), { exps(C, [E]) }.
exp(floor(E))         --> element('Floor',C), { exps(C, [E]) }.
exp(maximum(E))       --> element('Maximum',C), { exps(C, [E]) }.
exp(minimum(E))       --> element('Minimum',C), { exps(C, [E]) }.
exp(modulo(L,R))      --> element('Modulo',[L0, R0]), { exps([L0], [L]), exps([R0], [R]) }.

exp(addPayrollMonths(Es))     --> element('AddPayrollMonths',C), { exps(C, Es) }.
exp(payrollMonthsBetween(Es)) --> element('PayrollMonthsBetween',C), { exps(C, Es) }.
exp(startDate(Es))            --> element('StartDate',C), { exps(C, Es) }.
exp(endDate(Es))              --> element('EndDate',C), { exps(C, Es) }.

% Collections
exp(index(E))           --> element('Index',C), { exps(C, [E]) }.
exp(indexOf(Es))        --> element('IndexOf',C), { exps(C, Es) }.
exp(collection(E))      --> element('Collection',C), { exps(C, [E]) }.
exp(collectionSum(E))   --> element('CollectionSum',C), { exps(C, [E]) }.
exp(collectionSize(E))  --> element('CollectionSize',C), { exps(C, [E]) }.
exp(count(Es))          --> element('Count',C), { exps(C, Es) }.
exp(filter(P, E))       --> element('Filter',[path=P],C), { exps(C, [E]) }.
exp(V)                  --> value(V).

exp(dependency(E))      --> dependency(E).
% u_exp(u_exp(N,A,C)) --> [element(N,A,C)], { *format("~q~n~n", [N]) }.

expressions([E|Es]) --> exp(E), expressions(Es).
% expressions([E|Es]) --> u_exp(E), expressions(Es).
expressions([])     --> [].

writable(C) -->
  {
    tpartition(name_element_t('Limit'), C, Ls, Es),
    phrase(type_elem(Type), Es),
    phrase(limit_elem(Limits), Ls)
  },
  [writable(Type, Limits)].

derived(C) -->
  % Removing whitespace-only nodes makes it easier to write the expression nonterminals
  % because I can do things like expect that a node only has one child
  { phrase(trim_xml(C), Es), phrase(expressions([E]), Es) },
  [derived(E)].

element_name([_|_], 'String').
element_name(element(N,_,_), N).
name_element_t(ExpectedName, E, T) :- element_name(E, N), =(N, ExpectedName, T).
has_child_element_t(Cs, Name, T) :- maplist(element_name, Cs, Ns), memberd_t(Name, Ns, T).

fact_description(C, "") :- has_child_element_t(C, 'Description', false).
fact_description(C, D) :- member(element('Description', _, [N]), C), phrase(trim_str(D), N).

fact_expression(C, Ex) :-
    if_(
      has_child_element_t(C, 'Derived'),
      ( member(element('Derived', _, E), C), phrase(derived(E), [Ex]) ),
      ( member(element('Writable', _, Wc), C), phrase(writable(Wc), [Ex]) )
    ).

fact_placeholder(C, none) :- has_child_element_t(C, 'Placeholder', false).
fact_placeholder(C, Pl) :-
  member(element('Placeholder', _, Pc), C),
  phrase(placeholder(Pl), Pc).

fact_override(C, none) :- has_child_element_t(C, 'Override', false).
fact_override(C, override(Cond, Def)) :-
    member(element('Override', _, Oc), C),
    phrase(trim_xml(Oc), Es),
    phrase(override(Cond, Def), Es).

fact_element(P, C) -->
  {
    fact_description(C, D),
    fact_expression(C, Ex),
    fact_placeholder(C, Pl),
    fact_override(C, Ov)
  },
  [fact(P, D, Ex, Pl, Ov)].

facts([element('Fact', [path=P], C)|Ns]) --> fact_element(P,C), facts(Ns).
facts([element('', _, _)|Ns]) --> facts(Ns).
facts([[_|_]|Fs]) --> facts(Fs).
facts([]) --> [].

/* ----------------------------------------------------------------
 * Fact Graph (JSON) parser
 * ---------------------------------------------------------------- */

extract_string(string(S),S).

type_item_value(int, number(V), int(V)).
type_item_value(boolean, boolean(V), boolean(V)).
type_item_value(dollar, string(S), dollar(V)) :- number_chars(V, S).
type_item_value(day, pairs(P), day(V)) :- member(string("date")-string(V), P).
type_item_value(date, pairs(P), date(V)) :- member(string("date")-string(V), P).
type_item_value(enum(_), pairs(P), enum(V)) :- member(string("value")-string(V), P).
type_item_value(collection, pairs(P), collection(V)) :-
  member(string("items")-list(StrValues), P),
  maplist(extract_string, StrValues, V).

graph(D, [fact_value(P,Val)|Fs]) -->
  [string(P)-pairs(Pairs)],
  {
    if_(memberd_t('#', P), resolved_to_canonical(P, Cp), P = Cp),
    member(fact(Cp,_,writable(Type,_),_, _), D),
    member(string("item")-Item, Pairs),
    type_item_value(Type, Item, Val)
  },
  graph(D, Fs).
graph(_,[]) --> [].

starts_with_t(S0, S, false) :- length(S0, L0), length(S, L), L #< L0.
starts_with_t(S0, S, T) :- length(S0, L), length(S1, L), append([S1, _], S), =(S0, S1, T).

not(false, true).
not(true, false).
is_meta_fact(string(P)-pairs(_), T) :- starts_with_t("/meta", P, I), not(I, T).
load_graph(Fp, D, G) :-
  phrase_from_file(json_chars(pairs(L0)), Fp),
  tfilter(is_meta_fact, L0, L),
  phrase(graph(D, G), L).

graph_path_value(G, P, V) :- member(fact_value(P, V), G).

/* ----------------------------------------------------------------
 * Evaluate
 * ---------------------------------------------------------------- */

% Relate types values to their "innter" arthmetic values
% This makes it more convenient to compare ints with decimals
arith_val(A, AV) :- A = dollar(AV); A = int(AV).
arith_vals(A, B, AV, BV) :- arith_val(A, AV), arith_val(B, BV).

arith_cast(RawA, int(A)) :- A is truncate(RawA), A =:= RawA.
arith_cast(RawA, dollar(RawA)) :- A is truncate(RawA), A =\= RawA.

% Reifed logic predicates
not_t(boolean(true), boolean(false)).
not_t(boolean(false), boolean(true)).

eq_t_(A, B, boolean(true)) :- A =:= B.
eq_t_(A, B, boolean(false)) :- A =\= B.
eq_t(boolean(AV), boolean(BV), T)  :- eq_t_(AV, BV, T).
eq_t(A, B, T) :- arith_vals(A, B, AV, BV), eq_t_(AV, BV, T).

all_t([], boolean(true)).
all_t([E|Es], T) :- ','(=(E, boolean(true)), all_t(Es), T).
any_t([], boolean(false)).
any_t([E|Es], T) :- ';'(=(E, boolean(true)), any_t(Es), T).

% Reified arthmetic predicates
lt_t(A, B, boolean(true))  :- arith_vals(A, B, AV, BV), AV < BV.
lt_t(A, B, boolean(false)) :- arith_vals(A, B, AV, BV), AV >= BV.
gt_t(A, B, boolean(true))  :- arith_vals(A, B, AV, BV), AV > BV.
gt_t(A, B, boolean(false)) :- arith_vals(A, B, AV, BV), AV =< BV.
neq_t(A, B, T)    :- eq_t(A, B, I), not_t(I, T).
gte_t(A, B, T)    :- lt_t(A, B, I), not_t(I, T).
lte_t(A, B, T)    :- gt_t(A, B, I), not_t(I, T).

a_add(A, B, V)         :- arith_vals(A, B, AV, BV), V0 is AV + BV, arith_cast(V0, V).
a_multiply(A, B, V)    :- arith_vals(A, B, AV, BV), V0 is AV * BV, arith_cast(V0, V).
a_divide(A, B, V)      :- arith_vals(A, B, AV, BV), V0 is BV / AV, arith_cast(V0, V).
a_subtract(A, B, V)    :- arith_vals(A, B, AV, BV), V0 is BV - AV, arith_cast(V0, V).
a_round(A, int(V))     :- arith_val(A, AV), V is floor(AV + 0.5).
a_ceiling(A, int(V))   :- arith_val(A, AV), V is ceiling(AV).
a_floor(A, int(V))     :- arith_val(A, AV), V is floor(AV).
a_modulo(A, B, int(V)) :- arith_vals(A, B, AV, BV), V is AV mod BV.
a_list_max(As, V)      :- maplist(arith_val, As, AVs), list_max(AVs, V0), arith_cast(V0, V).
a_list_min(As, V)      :- maplist(arith_val, As, AVs), list_min(AVs, V0), arith_cast(V0, V).
a_sum_list(As, V)      :- maplist(arith_val, As, AVs), sum_list(AVs, V0), arith_cast(V0, V).

eval_all([], [])         --> [].
eval_all([A|As], [B|Bs]) --> eval(A, B), eval_all(As, Bs).

eval(int(V), int(V))          --> [].
eval(dollar(V), dollar(V))    --> [].
eval(boolean(V), boolean(V))  --> [].
eval(enum(V, _), V)           --> [].
eval(collection(V), V)        --> []. % This is a <Writable> collection
eval(day(Y,M,D), day(Y,M,D))  --> [].
eval(days(V), days(V))        --> [].

% value(enumOpts(V))       --> [element('EnumOptions', _, V)].
% value(today(V))          --> [element('Today',_,[V])].
% value(lastDayOfMonth(V)) --> [element('LastDayOfMonth',_,[V])].

eval(not(T0), V)          --> eval(T0, T), { not_t(T, V) }.
eval(equal(L0, R0), V)    --> eval(L0, L), eval(R0, R), { eq_t(L, R, V) }.
eval(notEqual(L0, R0), V) --> eval(L0, L), eval(R0, R), { neq_t(L, R, V) }.
eval(<(L0, R0), V)        --> eval(L0, L), eval(R0, R), { lt_t(L, R, V) }.
eval(>(L0, R0), V)        --> eval(L0, L), eval(R0, R), { gt_t(L, R, V) }.
eval(>=(L0, R0), V)       --> eval(L0, L), eval(R0, R), { gte_t(L, R, V) }.
eval(=<(L0, R0), V)       --> eval(L0, L), eval(R0, R), { lte_t(L, R, V) }.
eval(greaterOf(Ts0), V)   --> eval_all(Ts0, Ts), { a_list_max(Ts, V) }.
eval(lesserOf(Ts0), V)    --> eval_all(Ts0, Ts), { a_list_min(Ts, V) }.

eval(add(Ts0), V)       --> eval_all(Ts0, Ts), { foldl(a_add, Ts, int(0), V) }.
eval(multiply(Ts0), V)  --> eval_all(Ts0, Ts), { foldl(a_multiply, Ts, int(1), V) }.
eval(round(T0), V)      --> eval(T0, T), { a_round(T, V) }.
eval(ceiling(T0), V)    --> eval(T0, T), { a_ceiling(T, V) }.
eval(floor(T0), V)      --> eval(T0, T), { a_floor(T, V) }.
eval(modulo(L0, R0), V) --> eval(L0, L), eval(R0, R), { a_modulo(L, R, V) }.

eval(divide([dividend(D0), divisors(Ds0)]), V) -->
  eval(D0, D),
  eval_all(Ds0, Ds),
  { foldl(a_divide, Ds, D, V) }.
eval(subtract([minuend(M0), subtrahends(Ss0)]), V) -->
  eval(M0, M),
  eval_all(Ss0, Ss),
  { foldl(a_subtract, Ss, M, V) }.

% Collections
eval(maximum(E), V)             --> eval(E, Vs), { a_list_max(Vs, V) }.
eval(minimum(E), V)             --> eval(E, Vs), { a_list_min(Vs, V) }.
eval(collectionSum(E), V)       --> eval(E, Vs), { a_sum_list(Vs, V) }.
eval(collectionSize(E), int(V)) --> eval(E, Vs), { length(Vs, V) }.
eval(count(T0s), int(V))        -->
  eval_all(T0s, T1s),
  { tfilter(=(boolean(true)), T1s, Vs), length(Vs, V) }.

eval(indexOf([collection(C0), index(I0)]), V) -->
  eval(C0, C), eval(I0, int(I)), { nth0(I, C, V) }.
% TODO this is probably wrong
eval(collection(T0), V) --> eval(T0, V).

eval(filter(CollPath, E), Vs), [s(D,G,Par)]  -->
  [s(D,G,Par)],
  {
    eval_path(D, G, CollPath, ItemIds),
    tfilter(maybe_eval_exp_in_filter(D, G, E, CollPath), ItemIds, Vs)
  }.

eval(switch(Cases), V), [s(D,G,Par)] -->
  [s(D,G,Par)],
  {
    memberd_t(case(Cond, Exp), Cases, true),
    phrase(eval(Cond, boolean(true)), [s(D,G,Par)], _),
    ! % Accept the first condition that evaluates to true
  },
  eval(Exp, V).

% Resolves dependencies inside collection filter paths,
% which have no leading "." or "/" (this interface could be improved)
eval(dependency(FilterPath), V), [s(D,G,CollectionItemPath)] -->
  [s(D,G,CollectionItemPath)],
  { FilterPath = [C|_], [C] \= ".", [C] \= "/" },
  {
    append([CollectionItemPath, "/", FilterPath], ResolvedPath),
    eval_path(D, G, ResolvedPath, V)
  }.
% Resolves canonical paths to list of all those facts
% i.e. <Dependency path="/jobs/*/income"> is a list of all incomes
eval(dependency(Path), Vs), [s(D,G,Par)] -->
  [s(D,G,Par)],
  {
    path_parent_collection(Path, CollPath),
    eval_path(D, G, CollPath, ItemIds),
    maplist(canonical_to_resolved(Path), ItemIds, ItemPaths),
    maybe_eval_paths(D, G, ItemPaths, V0s),
    filter_incomplete(V0s, Vs)
  }.
% Resolves all other dependencies
eval(dependency(Path), V), [s(D,G,Par)] -->
  [s(D,G,Par)],
  {
    ( RPath = Path ; relative_path_parent_resolved(Path, Par, RPath)),
    eval_path(D, G, RPath, V)
  }.

eval_path(D, G, RPath, Value) :-
  ( CPath = RPath ; resolved_to_canonical(RPath, CPath)),
  member(fact(CPath, _, Ex, Pl, Ov), D),
  % writeln(Ex),
  (
    % The override evaluation is a little nasty, and regrettably non-monotonic
    ( Ov = override(Cond, Def), phrase(eval(Cond, boolean(true)), [s(D,G,RPath)], _)) -> E = Def
    ; Ex = writable(_, _), graph_path_value(G, RPath, E) -> true
    ; Ex = derived(E) -> true
    ; E = Pl
  ),
  phrase(eval(E, Value), [s(D,G,RPath)], _).

eval_paths(D, G, Paths, Values) :- maplist(eval_path(D, G), Paths, Values).

% Evalute paths that might be incomplete
% Used for predicates that operate on collections, as well as <IsComplete>
filter_incomplete(P0s, Ps) :- tfilter(dif(incomplete), P0s, Ps).
maybe_eval_path(D, G, P, Value) :- ( eval_path(D, G, P, V) -> Value = V; Value = incomplete ).
maybe_eval_paths(D, G, Paths, Values) :- maplist(maybe_eval_path(D, G), Paths, Values).

% Evaluates to true or false, where incompletes are false
% Only used in <Filter> contexts
maybe_eval_exp_in_filter(D, G, E, CollPath, ItemId, Value) :-
  collection_id_path(CollPath, ItemId, CollectionItemPath),
  (
    phrase(eval(E, V), [s(D,G,CollectionItemPath)], _) ->
    V = boolean(Value)
  ; Value = false
  ).


/* ----------------------------------------------------------------
 * Usage
 * ---------------------------------------------------------------- */
load_dict(Fp, Facts) :-
  load_xml(file(Fp), Xml, []),
  member(element('FactDictionaryModule', _, Module), Xml),
  member(element('Facts', _, FactsElements), Module),
  phrase(facts(FactsElements), Facts).

% Get all the .xml files in ./facts
is_xml_file(Fp, false) :- length(Fp, L), L #< 4.
is_xml_file(Fp, T) :- length(Fp1, 4), append(_, [_|Fp1], Fp), =(Fp1, ".xml", T).
all_fact_files(DirPath, Fps) :-
  directory_files(DirPath, Files),
  tfilter(is_xml_file, Files, XmlFiles),
  maplist(append(DirPath), XmlFiles, Fps).

% Flattens the XML tree - useful for debugging
all_elements([element(N,_,C)|Es]) --> [N], all_elements(C), all_elements(Es).
all_elements([[_|_]|Es])          --> all_elements(Es).
all_elements([])                  --> [].

load_fact_dir(DirPath, Fs) :-
  all_fact_files(DirPath, Fps),
  maplist(load_dict, Fps, Fss),
  phrase(seqq(Fss), Fs).

% Load the facts so that they can be queried in the top-level
term_expansion(load_fact_dictionary, Fs) :- load_fact_dir("./twe-facts/", Fs).
% load_fact_dictionary.

writeln(S) :- format("~w~n", [S]).
