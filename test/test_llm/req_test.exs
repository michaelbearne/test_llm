defmodule TestLlm.ReqTest do
  use ExUnit.Case

  alias TestLlm.Req, as: TestLlmReq

  describe "expect/1" do
    test "expect to create and cache response" do
      bypass = Bypass.open()
      model = "model-1"
      stub_key = "test-1"

      TestLlmReq.expect_response(key: stub_key, model: model, rerun: true)

      Bypass.expect_once(bypass, "POST", "/", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, JSON.encode!(%{"resp" => "Hi"}))
      end)

      assert %Req.Response{body: %{"resp" => "Hi"}} =
               Req.post!(TestLlm.Bypass.base_url(bypass), plug: TestLlmReq.plug())

      assert %{"resp" => "Hi"} = TestLlm.fetch_response(model, stub_key)
    end

    # needs the stub to be created to pass
    test "expect to return cached response" do
      bypass = Bypass.open()
      model = "model-1"
      stub_key = "test-2"

      TestLlmReq.expect_response(key: stub_key, model: model, rerun: false)

      assert %Req.Response{body: %{"resp" => "Hi"}} =
               Req.post!(TestLlm.Bypass.base_url(bypass), plug: TestLlmReq.plug())

      assert %{"resp" => "Hi"} = TestLlm.fetch_response(model, stub_key)
    end

    test "expect to create and cache mutiple responses" do
      bypass = Bypass.open()
      model = "model-1"
      stub_key_1 = "req-muti-test-1"
      stub_key_2 = "req-muti-test-2"

      TestLlmReq.expect_response(key: stub_key_1, model: model, rerun: true)
      TestLlmReq.expect_response(key: stub_key_2, model: model, rerun: true)

      count_ref = :counters.new(1, [])

      Bypass.expect(bypass, "POST", "/", fn conn ->
        hit = :counters.get(count_ref, 1) + 1
        :counters.add(count_ref, 1, 1)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, JSON.encode!(%{"resp" => "Hi Req hit #{hit}"}))
      end)

      assert %Req.Response{body: %{"resp" => "Hi Req hit 1"}} =
               Req.post!(TestLlm.Bypass.base_url(bypass),
                 decode_body: true,
                 plug: TestLlmReq.plug()
               )

      assert %Req.Response{body: %{"resp" => "Hi Req hit 2"}} =
               Req.post!(TestLlm.Bypass.base_url(bypass),
                 decode_body: true,
                 plug: TestLlmReq.plug()
               )

      assert %{"resp" => "Hi Req hit 1"} = TestLlm.fetch_response(model, stub_key_1)
      assert %{"resp" => "Hi Req hit 2"} = TestLlm.fetch_response(model, stub_key_2)
    end
  end

  describe "expect_stream_response/1" do
    test "expect response" do
      bypass = Bypass.open()

      model = "model-1"
      stub_key = "req-stream-test-1"

      TestLlmReq.expect_stream_response(key: stub_key, model: model, rerun: true)

      Bypass.expect_once(bypass, "POST", "/", fn conn ->
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

      fun = fn {:data, data}, {req, res} ->
        res = Req.Response.update_private(res, :chunks, [data], &[data | &1])
        {:cont, {req, res}}
      end

      # not sure why can't use :self for into when using plug
      assert %Req.Response{status: 200, private: %{chunks: chunks}} =
               Req.post!(TestLlm.Bypass.base_url(bypass), into: fun, plug: TestLlmReq.plug())

      # req test has no supports for chunks due to a limmitaion with plugs so returns the full payload as one chunk
      assert chunks == ["{\"chunk\":\"One\"}{\"chunk\":\"Two\"}"]
    end

    test "expect to return cached response" do
      bypass = Bypass.open()

      model = "model-1"
      stub_key = "req-stream-test-1"

      TestLlmReq.expect_stream_response(key: stub_key, model: model, rerun: false)

      fun = fn {:data, data}, {req, res} ->
        res = Req.Response.update_private(res, :chunks, [data], &[data | &1])
        {:cont, {req, res}}
      end

      # not sure why can't use :self for into when using plug
      assert %Req.Response{status: 200, private: %{chunks: chunks}} =
               Req.post!(TestLlm.Bypass.base_url(bypass), into: fun, plug: TestLlmReq.plug())

      # req test has no supports for chunks due to a limmitaion with plugs so returns the full payload as one chunk
      assert chunks == ["{\"chunk\":\"One\"}{\"chunk\":\"Two\"}"]
    end
  end
end
