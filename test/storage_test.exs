defmodule StorageTest do
  use ExUnit.Case
  doctest Storage

  test "module exists and has basic functions" do
    assert function_exported?(Storage, :put_file, 2)
    assert function_exported?(Storage, :get_file, 1)
    assert function_exported?(Storage, :delete_file, 1)
  end
end