# TestLlm

TestLlm provides helpers to easily stub LLM responses with [Req.Test](https://hexdocs.pm/req/Req.Test.html) or with [Bypass](https://hex.pm/packages/bypass)

When building with LLM's I find it easier to test with real outputs from prompts. TestLlm enables easy stubbing of the request by automatically generating and saving the response in the configured fixtures directory on the first request then on subsequent requests the saved response will be used. 

To rerun the request and update the saved response pass rerun: true as an opt to the expect_response or expect_stream_response function.

TestLlm supports streamed and unstreamed requests. It is recommended to use Bypass for streamed requests as Req.Test does not support chunking back the response and will just return the full response after all chunks are received.

## Installation

```elixir
def deps do
  [
    {:test_llm, "~> 0.1.0"}
  ]
end
```

## Setup the fixtures folder

In your test_helper.exs

```elixir
Application.put_env(
  :test_llm,
  :base_dir,
  Path.join([__DIR__, "support", "fixtures", "llm"])
)
```

## Examples

  **Req**

  ```elixir
  TestLlm.Req.expect_response(key: "test-1", model: "o3-mini-2025-01-31")
  Req.post!("https://llm.path", plug: TestLlmReq.plug())


  # with a rerun
  TestLlm.Req.expect_stream_response(key: "test-1", model: "o3-mini-2025-01-31", rerun: true)
  Req.post!("https://llm.base/llm/model", plug: TestLlmReq.plug())
  ```

  **Bypass**

  ```elixir
  bypass = Bypass.open()
  bypass_base_url = TestLlm.Bypass.base_url(bypass)
  llm_base_url = "https://llm.base"

  TestLlm.Bypass.expect_response(key: "test-1", model: "o3-mini-2025-01-31", bypass: bypass, original_base_url: llm_base_url)
  Req.post!("#{bypass_base_url}/llm/model")

  # With a rerun
  TestLlm.Bypass.expect_stream_response(key: "test-1", model: "o3-mini-2025-01-31", bypass: bypass, original_base_url: llm_base_url, rerun: true)
  Req.post!("#{bypass_base_url}/llm/model")

  # With multiple expects this will expect each one in order
  TestLlm.Bypass.expect_stream_response([
    [
      key: "stream-1",
      bypass: bypass,
      original_base_url: llm_base_url
    ],
    [
      key: "stream-2",
      bypass: bypass,
      original_base_url: llm_base_url
    ],
  ])
  ```

## Run tests with responses tracking

### Shows the responses used after a test suits run

Useful for showing which response fixtures were used during the test run.

```sh
TEST_LLM_SHOW_RESPONSES_HITS=1 mix test 
```

### Shows the unused responses after a test suits run

```sh
TEST_LLM_SHOW_UNUSED_RESPONSES=1 mix test
```

### Removes the unused responses after a test suits run

Useful for cleaning up unused response fixtures which are no longer used.

```sh
TEST_LLM_SHOW_UNUSED_RESPONSES=1 mix test test 
```
