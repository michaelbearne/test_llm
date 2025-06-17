# https://just.systems/man/en/

test *ARGS:
  mix test {{ARGS}}

test-with-show-responses-hits *ARGS:
  TEST_LLM_SHOW_RESPONSES_HITS=1 mix test {{ARGS}}

test-with-show-unused-responses *ARGS:
  TEST_LLM_SHOW_UNUSED_RESPONSES=1 mix test {{ARGS}}

test-with-remove-unused-responses *ARGS:
  TEST_LLM_REMOVE_UNUSED_RESPONSES=1 mix test {{ARGS}}

publish:
  mix hex.publish

outdated:
  mix hex.outdated

remove-unused-deps:
  mix deps.clean --unused 
  mix deps.clean --unlock --unused