defmodule TestLlm.BypassTest do
  use ExUnit.Case
  import TestLlm.ProcessHelper

  alias TestLlm.Bypass, as: TestLlmBypass

  describe "expect/1" do
    test "expect response" do
      bypass_original = Bypass.open()
      bypass_stub = Bypass.open()

      model = "model-1"
      stub_key = "bypass-test-1"

      original_base_url = TestLlm.Bypass.base_url(bypass_original)
      stub_base_url = TestLlm.Bypass.base_url(bypass_stub)

      TestLlmBypass.expect_response(
        key: stub_key,
        model: model,
        bypass: bypass_stub,
        original_base_url: original_base_url,
        rerun: true
      )

      Bypass.expect_once(bypass_original, "POST", "/", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, JSON.encode!(%{"resp" => "Hi Bypass"}))
      end)

      assert %Req.Response{body: %{"resp" => "Hi Bypass"}} =
               Req.post!(stub_base_url, decode_body: true)

      assert %{"resp" => "Hi Bypass"} = TestLlm.fetch_response(model, stub_key)
    end

    # needs the stub to be created to pass
    test "expect to return cached response" do
      bypass_original = Bypass.open()
      bypass_stub = Bypass.open()

      model = "model-1"
      stub_key = "bypass-test-1"

      original_base_url = TestLlm.Bypass.base_url(bypass_original)
      stub_base_url = TestLlm.Bypass.base_url(bypass_stub)

      TestLlmBypass.expect_response(
        key: stub_key,
        model: model,
        bypass: bypass_stub,
        original_base_url: original_base_url,
        rerun: false
      )

      assert %Req.Response{body: %{"resp" => "Hi Bypass"}} =
               Req.post!(stub_base_url, decode_body: true)

      assert %{"resp" => "Hi Bypass"} = TestLlm.fetch_response(model, stub_key)
    end

    test "expect multiple responses" do
      bypass_original = Bypass.open()
      bypass_stub = Bypass.open()

      model = "model-1"
      stub_key_1 = "bypass-test-multi-1"
      stub_key_2 = "bypass-test-multi-2"

      original_base_url = TestLlm.Bypass.base_url(bypass_original)
      stub_base_url = TestLlm.Bypass.base_url(bypass_stub)

      TestLlmBypass.expect_response([
        [
          key: stub_key_1,
          model: model,
          bypass: bypass_stub,
          original_base_url: original_base_url,
          rerun: true
        ],
        [
          key: stub_key_2,
          model: model,
          bypass: bypass_stub,
          original_base_url: original_base_url,
          rerun: true
        ]
      ])

      count_ref = :counters.new(1, [])

      Bypass.expect(bypass_original, "POST", "/", fn conn ->
        hit = :counters.get(count_ref, 1) + 1
        :counters.add(count_ref, 1, 1)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, JSON.encode!(%{"resp" => "Hi Bypass hit #{hit}"}))
      end)

      assert %Req.Response{body: %{"resp" => "Hi Bypass hit 1"}} =
               Req.post!(stub_base_url, decode_body: true)

      assert %Req.Response{body: %{"resp" => "Hi Bypass hit 2"}} =
               Req.post!(stub_base_url, decode_body: true)

      assert %{"resp" => "Hi Bypass hit 1"} = TestLlm.fetch_response(model, stub_key_1)
      assert %{"resp" => "Hi Bypass hit 2"} = TestLlm.fetch_response(model, stub_key_2)
    end

    # needs the stub to be created to pass
    test "expect multiple cached responses" do
      bypass_original = Bypass.open()
      bypass_stub = Bypass.open()

      model = "model-1"
      stub_key_1 = "bypass-test-multi-1"
      stub_key_2 = "bypass-test-multi-2"

      original_base_url = TestLlm.Bypass.base_url(bypass_original)
      stub_base_url = TestLlm.Bypass.base_url(bypass_stub)

      TestLlmBypass.expect_response([
        [
          key: stub_key_1,
          model: model,
          bypass: bypass_stub,
          original_base_url: original_base_url,
          rerun: false
        ],
        [
          key: stub_key_2,
          model: model,
          bypass: bypass_stub,
          original_base_url: original_base_url,
          rerun: false
        ]
      ])

      assert %Req.Response{body: %{"resp" => "Hi Bypass hit 1"}} =
               Req.post!(stub_base_url, decode_body: true)

      assert %Req.Response{body: %{"resp" => "Hi Bypass hit 2"}} =
               Req.post!(stub_base_url, decode_body: true)

      assert %{"resp" => "Hi Bypass hit 1"} = TestLlm.fetch_response(model, stub_key_1)
      assert %{"resp" => "Hi Bypass hit 2"} = TestLlm.fetch_response(model, stub_key_2)
    end
  end

  describe "expect_stream_response/1" do
    test "expect response" do
      bypass_original = Bypass.open()
      bypass_stub = Bypass.open()

      model = "model-1"
      stub_key = "bypass-stream-test-1"

      original_base_url = TestLlm.Bypass.base_url(bypass_original)
      stub_base_url = TestLlm.Bypass.base_url(bypass_stub)

      TestLlmBypass.expect_stream_response(
        key: stub_key,
        model: model,
        bypass: bypass_stub,
        original_base_url: original_base_url,
        rerun: true
      )

      Bypass.expect_once(bypass_original, "POST", "/", fn conn ->
        conn = Plug.Conn.put_resp_content_type(conn, "text/event-stream")
        conn = Plug.Conn.send_chunked(conn, 200)

        chunks = [
          JSON.encode!(%{"chunk" => "One"}),
          JSON.encode!(%{"chunk" => "Two"})
        ]

        Enum.reduce(chunks, conn, fn chunk, acc ->
          {:ok, conn} = Plug.Conn.chunk(acc, chunk)
          conn
        end)
      end)

      assert %Req.Response{status: 200} = Req.post!(stub_base_url, into: :self)

      assert_receive {_, {:data, "{\"chunk\":\"One\"}"}}
      assert_receive {_, {:data, "{\"chunk\":\"Two\"}"}}
      assert_receive {_, :done}

      assert_mailbox_empty()

      assert TestLlm.fetch_stream_response(model, stub_key) |> length() == 2
    end

    test "expect to return cached response" do
      bypass_original = Bypass.open()
      bypass_stub = Bypass.open()

      model = "model-1"
      stub_key = "bypass-stream-test-2"

      original_base_url = TestLlm.Bypass.base_url(bypass_original)
      stub_base_url = TestLlm.Bypass.base_url(bypass_stub)

      TestLlmBypass.expect_stream_response(
        key: stub_key,
        model: model,
        bypass: bypass_stub,
        original_base_url: original_base_url,
        rerun: false
      )

      assert %Req.Response{status: 200} = Req.post!(stub_base_url, into: :self)

      assert_receive {_, {:data, "{\"chunk\":\"One\"}"}}
      assert_receive {_, {:data, "{\"chunk\":\"Two\"}"}}
      assert_receive {_, :done}

      assert_mailbox_empty()

      assert TestLlm.fetch_stream_response(model, stub_key) |> length() == 2
    end
  end
end
