defmodule TestLlm.Bypass do
  import TestLlm.Helpers

  def open, do: Bypass.open()

  def base_url(%Bypass{port: port}) do
    "http://localhost:#{port}"
  end

  def expect_response(key) when is_binary(key) do
    expect_response(key: key)
  end

  # bypass can't track the order of the expect like req so needs to be manged as a list
  def expect_response([first, next | rest]) when is_list(first) do
    cb = fn -> expect_response([next | rest]) end
    expect_response(Keyword.put(first, :cb, cb))
  end

  def expect_response([opts]) when is_list(opts) do
    expect_response(opts)
  end

  def expect_response(opts) when is_list(opts) do
    bypass = Keyword.fetch!(opts, :bypass)
    original_base_url = Keyword.fetch!(opts, :original_base_url)
    key = Keyword.fetch!(opts, :key)
    rerun = Keyword.get(opts, :rerun, false)
    model = Keyword.get(opts, :model)
    move_to_next_response_cb = Keyword.get(opts, :cb)

    wrapperFn = fn conn ->
      model = model || extract_model_name(conn.request_path)
      file_path = file_path(key, model)

      if !rerun && File.exists?(file_path) do
        resp = File.read!(file_path)
        move_to_next_response_cb && move_to_next_response_cb.()
        send_resp(conn, resp)
      else
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        original_base_uri = URI.parse(original_base_url)

        url = %URI{
          scheme: original_base_uri.scheme,
          host: original_base_uri.host,
          port: original_base_uri.port,
          path: conn.request_path,
          query: conn.query_string
        }

        resp = Req.post!(URI.to_string(url), body: body, headers: conn.req_headers)
        write_resp(file_path, resp.body)
        move_to_next_response_cb && move_to_next_response_cb.()
        send_resp(conn, resp.body)
      end
    end

    Bypass.expect(bypass, wrapperFn)
  end

  def expect_stream_response(key) when is_binary(key) do
    expect_stream_response(key: key)
  end

  def expect_stream_response([first, next | rest]) when is_list(first) do
    cb = fn -> expect_stream_response([next | rest]) end
    expect_stream_response(Keyword.put(first, :cb, cb))
  end

  def expect_stream_response([opts]) when is_list(opts) do
    expect_stream_response(opts)
  end

  def expect_stream_response(opts) when is_list(opts) do
    key = Keyword.fetch!(opts, :key)
    bypass = Keyword.fetch!(opts, :bypass)
    original_base_url = Keyword.fetch!(opts, :original_base_url)
    rerun = Keyword.get(opts, :rerun, false)
    model = Keyword.get(opts, :model)
    move_to_next_response_cb = Keyword.get(opts, :cb)

    wrapperFn = fn conn ->
      model = model || extract_model_name(conn.request_path)
      file_path = stream_file_path(key, model)

      if !rerun && File.exists?(file_path) do
        resp = File.read!(file_path)
        move_to_next_response_cb && move_to_next_response_cb.()
        send_chunked_resp(conn, resp)
      else
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        original_base_uri = URI.parse(original_base_url)

        url = %URI{
          scheme: original_base_uri.scheme,
          host: original_base_uri.host,
          port: original_base_uri.port,
          path: conn.request_path,
          query: conn.query_string
        }

        file_pid = File.open!(file_path, [:write, :binary])

        fun = fn {:data, data}, {req, res} ->
          IO.binwrite(file_pid, "chunk::" <> data)
          res = Req.Response.update_private(res, :chunks, [data], &[data | &1])
          {:cont, {req, res}}
        end

        resp =
          Req.post!(URI.to_string(url),
            body: body,
            headers: [{"Content-Type", "application/json"}],
            into: fun
          )

        File.close(file_pid)

        chunks = Req.Response.get_private(resp, :chunks, []) |> Enum.reverse()
        move_to_next_response_cb && move_to_next_response_cb.()
        send_chunked_resp(conn, chunks)
      end
    end

    Bypass.expect(bypass, wrapperFn)
  end

  def get_stream_response_chunks(model, key) do
    file_path = Path.join([base_dir(), "responses", Slug.slugify(model), stream_file_name(key)])
    resp = File.read!(file_path)
    String.split(resp, "chunk::")
  end

  def send_resp(conn, resp) when is_binary(resp) or is_map(resp) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(200, if(is_binary(resp), do: resp, else: JSON.encode!(resp)))
  end

  defp send_chunked_resp(conn, chunks) when is_list(chunks) do
    conn = Plug.Conn.put_resp_content_type(conn, "text/event-stream")
    conn = Plug.Conn.send_chunked(conn, 200)

    Enum.reduce(chunks, conn, fn resp, acc ->
      {:ok, conn} = Plug.Conn.chunk(acc, resp)
      conn
    end)
  end

  defp send_chunked_resp(conn, resp) when is_binary(resp) do
    conn = Plug.Conn.put_resp_content_type(conn, "text/event-stream")
    conn = Plug.Conn.send_chunked(conn, 200)
    chunks = String.split(resp, "chunk::")

    Enum.reduce(chunks, conn, fn resp, acc ->
      {:ok, conn} = Plug.Conn.chunk(acc, resp)
      conn
    end)
  end
end
