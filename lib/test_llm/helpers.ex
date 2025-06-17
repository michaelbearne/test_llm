defmodule TestLlm.Helpers do
  def extract_model_name(request_path) do
    request_path |> Path.split() |> List.last() |> String.split(":", parts: 2) |> List.first()
  end

  def replace_model_resp(prompt, key, resp) when is_atom(prompt) do
    path = to_file_path(prompt, key)
    dir = Path.dirname(path)
    unless File.exists?(dir), do: File.mkdir_p!(dir)
    File.write!(path, Jason.encode!(resp, pretty: true))
  end

  def to_file_path(prompt, key) when is_binary(key) do
    Path.join([__DIR__, folder_name(prompt), file_name(key)])
  end

  def to_file_path(prompt, key) when is_list(key) do
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

  def to_folder_path(prompt, key) when is_binary(key) do
    Path.join([__DIR__, folder_name(prompt), folder_name(key)])
  end

  def base_dir do
    Application.fetch_env!(:test_llm, :base_dir)
  end

  def write_resp(path, resp) do
    dir = Path.dirname(path)
    unless File.exists?(dir), do: File.mkdir_p!(dir)
    File.write!(path, Jason.encode!(resp, pretty: true))
  end

  def file_path(key, model) do
    Path.join([base_dir(), "responses", Slug.slugify(model), file_name(key)])
  end

  def stream_file_path(key, model) do
    Path.join([base_dir(), "responses", Slug.slugify(model), stream_file_name(key)])
  end
end
