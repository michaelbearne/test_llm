defmodule TestLlm do
  import TestLlm.Helpers

  def fetch_response(model, keys) when is_list(keys) do
    for key <- keys do
      file_path(key, model)
      |> File.read!()
      |> JSON.decode!()
    end
  end

  def fetch_response(model, key) do
    file_path(key, model)
    |> File.read!()
    |> JSON.decode!()
  end

  def fetch_stream_response(model, key) do
    stream_file_path(key, model)
    |> File.read!()
    |> String.split("chunk::")
    |> Enum.reject(&(&1 == ""))
  end

  # not sure needed
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
end
