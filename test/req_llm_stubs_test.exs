defmodule TestLlm.Req do
  use ExUnit.Case
  doctest ReqLlmStubs

  test "greets the world" do
    assert ReqLlmStubs.hello() == :world
  end
end
