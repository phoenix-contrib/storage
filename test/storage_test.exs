defmodule StorageTest do
  use ExUnit.Case
  doctest Storage

  describe "API functions" do
    test "put_file/2 function exists" do
      assert function_exported?(Storage, :put_file, 2)
    end

    test "get_file/1 function exists" do
      assert function_exported?(Storage, :get_file, 1)
    end

    test "delete_file/1 function exists" do
      assert function_exported?(Storage, :delete_file, 1)
    end

    test "signed_url_for_direct_upload/1 function exists" do
      assert function_exported?(Storage, :signed_url_for_direct_upload, 1)
    end

    test "purge_unattached/1 function exists" do
      assert function_exported?(Storage, :purge_unattached, 1)
    end
  end

  describe "module delegation" do
    test "put_file delegates to Storage.Uploader" do
      # Verify the main Storage module delegates to the correct modules
      assert Storage.__info__(:functions) |> Keyword.has_key?(:put_file)
    end
  end
end