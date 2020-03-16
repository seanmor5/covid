defmodule CovidTest do
  use ExUnit.Case
  doctest Covid

  test "greets the world" do
    assert Covid.hello() == :world
  end
end
