defmodule TestLlm.Req do
  @receive_timeout :timer.minutes(4)

  def plug, do: {Req.Test, __MODULE__}

  def expect(fun) when is_function(fun, 1) do
    wrapperFn = fn conn ->
      fun.(conn)
    end

    Req.Test.expect(__MODULE__, wrapperFn)
  end

  def expect(fixture) when is_atom(fixture) do
    # todo
    wrapperFn = fn _conn ->
      nil
    end

    Req.Test.expect(__MODULE__, wrapperFn)
  end

  def expect_response(key) when is_binary(key) do
    expect_response(key: key)
  end

  def expect_response(opts) when is_list(opts) do
    key = Keyword.fetch!(opts, :key)
    rerun = Keyword.get(opts, :rerun, false)
    model = Keyword.get(opts, :model)

    wrapperFn = fn conn ->
      model =
        model ||
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

    wrapperFn = fn conn ->
      model =
        conn.request_path
        |> Path.split()
        |> List.last()
        |> String.split(":", parts: 2)
        |> List.first()

      file_path = Path.join([base_dir(), "responses", Slug.slugify(model), file_name(key)])

      if !rerun && File.exists?(file_path) do
        resp = file_path |> File.read!() |> JSON.decode!()
        dbg(resp)

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

        resp = Req.post!(URI.to_string(url), body: body, headers: conn.req_headers)
        write_resp(file_path, resp.body)

        Req.Test.json(conn, resp.body)
      end
    end

    Req.Test.expect(__MODULE__, wrapperFn)
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

  def send_chunked_resp(conn, resp) when is_list(resp) do
    conn = Plug.Conn.put_resp_content_type(conn, "text/event-stream")
    conn = Plug.Conn.send_chunked(conn, 200)

    Enum.reduce(resp, conn, fn
      resp, acc when is_binary(resp) ->
        dbg(resp)
        {:ok, conn} = Plug.Conn.chunk(acc, resp)
        conn

      resp, acc when is_map(resp) ->
        dbg(resp)
        {:ok, conn} = Plug.Conn.chunk(acc, JSON.encode!(resp) <> "\n")
        conn
    end)
  end
end
