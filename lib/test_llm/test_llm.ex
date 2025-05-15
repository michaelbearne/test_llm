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
end
