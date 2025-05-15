defmodule TestLlm.Bypass do
  def open, do: Bypass.open()

  def base_url(%Bypass{port: port}) do
    "http://localhost:#{port}"
  end

  def expect_response(key) when is_binary(key) do
    expect_response(key: key)
  end

  def expect_response(opts) when is_list(opts) do
    key = Keyword.fetch!(opts, :key)
    rerun = Keyword.get(opts, :rerun, false)

    wrapperFn = fn conn ->
      model =
        conn.request_path
        |> Path.split()
        |> List.last()
        |> String.split(":", parts: 2)
        |> List.first()

      file_path = Path.join([base_dir(), "responses", Slug.slugify(model), file_name(key)])

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

        resp = Req.post!(URI.to_string(url), body: body, headers: conn.req_headers)
        write_resp(file_path, resp.body)

        Req.Test.json(conn, resp.body)
      end
    end

    Req.Test.expect(__MODULE__, wrapperFn)
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
      model =
        model ||
          conn.request_path
          |> Path.split()
          |> List.last()
          |> String.split(":", parts: 2)
          |> List.first()

      file_path = Path.join([base_dir(), "responses", Slug.slugify(model), stream_file_name(key)])

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

  def write_resp(path, resp) do
    dir = Path.dirname(path)
    unless File.exists?(dir), do: File.mkdir_p!(dir)
    File.write!(path, Jason.encode!(resp, pretty: true))
  end

  def model_resp(prompt, key) when is_atom(prompt) do
    to_file_path(prompt, key) |> File.read!()
  end

  def model_resp_as_json(prompt, key) when is_atom(prompt) do
    model_resp(prompt, key) |> JSON.decode!()
  end

  def model_resps_as_json(prompt, key) when is_atom(prompt) do
    path = to_folder_path(prompt, key)

    if File.dir?(path) do
      path
      |> File.ls!()
      |> Enum.map(fn file_name ->
        Path.join(path, file_name) |> File.read!() |> JSON.decode!()
      end)
    else
      raise "Path is not dir #{path}"
    end
  end

  def replace_model_resp(prompt, key, resp) when is_atom(prompt) do
    path = to_file_path(prompt, key)
    dir = Path.dirname(path)
    unless File.exists?(dir), do: File.mkdir_p!(dir)
    File.write!(path, Jason.encode!(resp, pretty: true))
  end

  defp to_file_path(prompt, key) when is_binary(key) do
    Path.join([__DIR__, folder_name(prompt), file_name(key)])
  end

  defp to_file_path(prompt, key) when is_list(key) do
    {file_name, sub_folders} = List.pop_at(key, -1)
    Path.join([__DIR__, folder_name(prompt), folder_name(sub_folders), file_name(file_name)])
  end

  def file_name(name) do
    "#{Slug.slugify(name, separator: "_")}_resp.json"
  end

  def stream_file_name(name) do
    "#{Slug.slugify(name, separator: "_")}_resp.stream"
  end

  def folder_name(names) when is_list(names) do
    Enum.map(names, &folder_name/1)
  end

  def folder_name(name) when is_atom(name) do
    name |> Atom.to_string() |> folder_name()
  end

  def folder_name(name) when is_binary(name) do
    Slug.slugify(name, separator: "_")
  end

  defp to_folder_path(prompt, key) when is_binary(key) do
    Path.join([__DIR__, folder_name(prompt), folder_name(key)])
  end

  defp base_dir do
    Application.fetch_env!(:test_llm, :base_dir)
  end

  def send_chunked_resp(conn, chunks) when is_list(chunks) do
    conn = Plug.Conn.put_resp_content_type(conn, "text/event-stream")
    conn = Plug.Conn.send_chunked(conn, 200)

    Enum.reduce(chunks, conn, fn resp, acc ->
      {:ok, conn} = Plug.Conn.chunk(acc, resp)
      conn
    end)
  end

  def send_chunked_resp(conn, resp) when is_binary(resp) do
    conn = Plug.Conn.put_resp_content_type(conn, "text/event-stream")
    conn = Plug.Conn.send_chunked(conn, 200)
    chunks = String.split(resp, "chunk::")

    Enum.reduce(chunks, conn, fn resp, acc ->
      {:ok, conn} = Plug.Conn.chunk(acc, resp)
      conn
    end)
  end
end
