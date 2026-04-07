FG_FILE := "./factgraph.pl"
TEST_FILE := "./test.pl"

fg:
  scryer-prolog {{ FG_FILE }}

test:
  scryer-prolog {{ TEST_FILE }} -g run -t halt

twe-xpath query:
  find ./test/twe-facts -name '*.xml' | xargs xpath -e {{ query }}
