defmodule TestLlm.ResponsesTracker do
  use Agent
  require Logger
  import TestLlm.Helpers, only: [base_dir: 0]

  @type t :: %__MODULE__{
          hits: MapSet.t()
        }

  defstruct hits: MapSet.new()

  def maybe_start() do
    case start() do
      {:ok, pid} ->
        setup_ex_unit_after_suite_cb()
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end

  # not a link as only want one to run for the whole test suite
  defp start() do
    Agent.start(fn -> %__MODULE__{hits: MapSet.new()} end, name: __MODULE__)
  end

  def hits() do
    Agent.get(__MODULE__, & &1).hits
  end

  def hit(file_path) do
    Agent.update(__MODULE__, fn %{hits: hits} = state ->
      %{state | hits: MapSet.put(hits, file_path)}
    end)
  end

  Code.ensure_loaded?(ExUnit)

  if function_exported?(ExUnit, :after_suite, 1) do
    defp setup_ex_unit_after_suite_cb do
      ExUnit.after_suite(fn %{
                              total: _total,
                              failures: failures,
                              excluded: _excluded,
                              skipped: _skipped
                            } ->
        hits = hits()
        maybe_show_responses_hits(hits)
        maybe_show_unused_responses(hits)
        maybe_remove_unused_responses(hits, failures)
      end)
    end
  else
    defp setup_ex_unit_after_suite_cb, do: nil
  end

  defp maybe_fetch_responses(responses_dir) do
    if File.exists?(responses_dir) do
      for model <- File.ls!(responses_dir),
          model_path = Path.join(responses_dir, model),
          response <- if(File.dir?(model_path), do: File.ls!(model_path), else: []) do
        Path.join(model_path, response)
      end
      |> MapSet.new()
    end
  end

  defp maybe_show_responses_hits(hits) do
    if System.get_env("TEST_LLM_SHOW_RESPONSES_HITS") && !Enum.empty?(hits) do
      IO.puts("Test LLM responses hits:")
      for hit <- hits, do: IO.puts(hit)
      IO.puts("\n")
    end
  end

  defp maybe_show_unused_responses(hits) do
    if System.get_env("TEST_LLM_SHOW_UNUSED_RESPONSES") && !Enum.empty?(hits) do
      responses_dir = Path.join(base_dir(), "responses")
      responses = maybe_fetch_responses(responses_dir)

      if responses do
        unused = MapSet.difference(responses, hits)

        IO.puts("Test LLM unused responses:")
        for resp <- unused, do: IO.puts(resp)
        IO.puts("\n")
      end
    end
  end

  defp maybe_remove_unused_responses(hits, failures) do
    if System.get_env("TEST_LLM_REMOVE_UNUSED_RESPONSES") &&
         !Enum.empty?(hits) do
      responses_dir = Path.join(base_dir(), "responses")
      responses = maybe_fetch_responses(responses_dir)

      if responses do
        unused = MapSet.difference(responses, hits)

        if failures == 0 do
          for resp <- unused do
            File.rm_rf!(resp)
            IO.puts(resp)
          end

          maybe_unused_dirs = unused |> Enum.map(&Path.dirname/1) |> Enum.uniq()

          for dir <- maybe_unused_dirs do
            case File.ls!(dir) do
              [] -> File.rm_rf!(dir)
              [".DS_Store"] -> File.rm_rf!(dir)
              _ -> nil
            end
          end

          IO.puts("Test LLM removed unused responses:")
        else
          IO.puts("Test LLM not removing unused responses as test failures:")
          for resp <- unused, do: IO.puts(resp)
        end

        IO.puts("\n")
      end
    end
  end
end
