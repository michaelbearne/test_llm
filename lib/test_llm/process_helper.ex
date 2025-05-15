defmodule TestLlm.ProcessHelper do
  def assert_mailbox_empty(opts \\ []) do
    aft = opts[:after] || opts[:a] || 0

    receive do
      message ->
        {:messages, rest} = Process.info(self(), :messages)
        messages = [message | rest]

        raise ExUnit.AssertionError,
          expr: "assert_mailbox_empty()",
          message:
            "\nThe process mailbox is not empty. #{length(messages)} messages. #{format_mailbox(messages, opts)}"
    after
      aft ->
        true
    end
  end

  def mailbox_messages() do
    {:messages, messages} = Process.info(self(), :messages)
    messages
  end

  def last_ten_mailbox_messages() do
    mailbox_messages() |> Enum.take(-10)
  end

  @indent "\n  "
  @max_mailbox_length 10
  def format_mailbox(messages, opts \\ []) do
    max_mailbox_length = opts[:max_mailbox_length] || @max_mailbox_length

    length = length(messages)

    mailbox =
      messages
      |> Enum.take(max_mailbox_length)
      |> Enum.map_join(@indent, &inspect/1)

    mailbox_message(length, @indent <> mailbox, max_mailbox_length)
  end

  defp mailbox_message(0, _mailbox, _max_mailbox_length), do: "\nThe process mailbox is empty."

  defp mailbox_message(length, mailbox, max_mailbox_length) when length > max_mailbox_length do
    "\nProcess mailbox:" <>
      mailbox <> "\nShowing only #{max_mailbox_length} of #{length} messages."
  end

  defp mailbox_message(_length, mailbox, _max_mailbox_length) do
    "\nProcess mailbox:" <> mailbox
  end
end
