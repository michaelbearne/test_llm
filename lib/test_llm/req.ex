defmodule TestLlm.Req do
  import TestLlm.Helpers

  alias TestLlm.ResponsesTracker

  @receive_timeout :timer.minutes(4)

  def plug, do: {Req.Test, __MODULE__}

  def expect_response(key) when is_binary(key) do
    expect_response(key: key)
  end

  def expect_response(opts) when is_list(opts) do
    key = Keyword.fetch!(opts, :key)
    rerun = Keyword.get(opts, :rerun, false)
    model = Keyword.get(opts, :model)

    {:ok, _pid} = ResponsesTracker.maybe_start()

    wrapperFn = fn conn ->
      model = model || extract_model_name(conn.request_path)
      file_path = file_path(key, model)
      ResponsesTracker.hit(file_path)

      if !rerun && File.exists?(file_path) do
        resp = File.read!(file_path)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Req.Test.text(resp)
      else
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        url = %URI{
          host: conn.host,
          path: conn.request_path,
          port: conn.port,
          query: conn.query_string,
          scheme: Atom.to_string(conn.scheme)
        }

        resp =
          Req.post!(URI.to_string(url),
            body: body,
            headers: conn.req_headers,
            receive_timeout: @receive_timeout
          )

        write_resp(file_path, resp.body)
        Req.Test.json(conn, resp.body)
      end
    end

    Req.Test.expect(__MODULE__, wrapperFn)
  end

  def expect_stream_response(key) when is_binary(key) do
    expect_stream_response(key: key)
  end

  def expect_stream_response(opts) when is_list(opts) do
    key = Keyword.fetch!(opts, :key)
    rerun = Keyword.get(opts, :rerun, false)
    model = Keyword.get(opts, :model)

    {:ok, _pid} = ResponsesTracker.maybe_start()

    wrapperFn = fn conn ->
      model = model || extract_model_name(conn.request_path)

      file_path = stream_file_path(key, model)
      ResponsesTracker.hit(file_path)

      if !rerun && File.exists?(file_path) do
        resp = file_path |> File.read!()
        send_chunked_resp(conn, resp)
      else
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        url = %URI{
          host: conn.host,
          path: conn.request_path,
          port: conn.port,
          query: conn.query_string,
          scheme: Atom.to_string(conn.scheme)
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
        send_chunked_resp(conn, chunks)
      end
    end

    Req.Test.expect(__MODULE__, wrapperFn)
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
