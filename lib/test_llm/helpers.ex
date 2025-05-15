defmodule TestLlm.Helpers do
  def file_path(key, model \\ "gpt-3.5-turbo") do
    Path.join([base_dir(), "responses", Slug.slugify(model), file_name(key)])
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
    "#{Slug.slugify(name, separator: "_")}_resp.stream4"
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
    # Keyword.fetch!(cfg, :base_dir)
  end
end
