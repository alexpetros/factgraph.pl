# factgraph.pl

A single-file Prolog implementation of the [IRS Fact Graph](https://github.com/IRS-Public/fact-graph).

The purpose of this project is to strengthen my understanding the Fact Graph's semantics by reimplementing it.
At this time, it can parse the entire [Tax Withholding Estimator](https://github.com/IRS-Public/tax-withholding-estimator) Fact Dictionary.
It can also evaluate a variety of test cases, but some work remains before it can evaluate TWE's facts, mainly involving dates.

I recommend attempting to read `factgraph.pl` without syntax highlighting on, or at least syntax highlighting that is more restrained than GitHub's.
This implementation uses intermediate Prolog features, particularly [DCGs with semicontext notation](https://www.metalevel.at/prolog/dcg), but I am doing to my best to make is vibrationally accessible, so to speak;
it's worth at least taking a peak at the file even if you've never thought about Prolog before.

If you are unfamiliar with Prolog and would like to use this codebase as a reason to learn, I recommend ["The Power of Prolog"](https://www.metalevel.at/prolog) by Markus Triska and the accompanying videos.

## Setup

Requires [Scryer Prolog](https://www.scryer.pl/), including a [currently-unreleased fix](https://github.com/mthom/scryer-prolog/issues/3256) to the XML parsing library.
That means you have to install Scryer Prolog from source (which is very easy).
With the [Rust toolchain](https://rust-lang.org/) installed, navigate to a convenient directory and run the following commands:

```
git clone https://github.com/mthom/scryer-prolog/
cd scryer-prolog
cargo install --path .
```

Then, in a new shell, you should have the `scryer-prolog` command.
If you want to use the `just` command runner, you also need `just`.

```
cargo install just
```

## Usage

Main commands:

* `just` - open the top-level with `factgraph.pl` included
* `just test` - run the tests

Key predicates:

* `load_dict(Fp, D)` - load the Fact Dictionary at filepath `Fp`
* `load_graph(Fp, D, G)` - load the Fact Graph at filepath `Fp` with dictionary `D`
* `eval_path(D, G, Path)` - evaluate the fact `Path` with dictionary `D` and graph `G`

Example:

```prolog
% Evaluate the fact "/jobs"
?- load_dict("./test/collections.xml", D),
   load_graph("./test/collections.json", D, G),
   eval_path(D,G,"/jobs", V).
```

More example usages can be found in [`test.pl`](./test.pl).

## TODO

###

* Date types
* `<AddPayrollMonth>`
* Rational math
* Probably other subtle math issues with integers and dollars
* Testing against TWE scenarios

## Optimizations

* Remove cut from `<Switch>` implementation (I think this can be modeled as "true and all previous conditions are false")

## Out of scope

* Overly-specific FG types like TIN and Bank Account
* Semi-completeness
  * i.e. Placeholder values working but being "incomplete"
  * Although I suppose it could be easy to determine whether any placeholders are used in an evaluation
