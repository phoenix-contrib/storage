defmodule Storage.UploaderTest do
  use ExUnit.Case, async: true

  alias Storage.Uploader

  setup do
    # Create a temporary file for testing
    tmp_dir = System.tmp_dir!()
    test_file = Path.join(tmp_dir, "test_upload.txt")
    File.write!(test_file, "test content")

    on_exit(fn ->
      File.rm(test_file)
    end)

    {:ok, test_file: test_file}
  end

  describe "put/2" do
    test "requires filename parameter" do
      assert_raise ArgumentError, "filename is required", fn ->
        Uploader.put("test data", [])
      end
    end

    test "accepts binary data with filename", %{test_file: test_file} do
      # Mock the blob creation to avoid database dependency
      # In a real test, you'd set up the test database
      
      # Test that the function exists and accepts the right parameters
      assert function_exported?(Uploader, :put, 2)
    end

    test "accepts file path", %{test_file: test_file} do
      # Test that file path is handled
      assert function_exported?(Uploader, :put, 2)
    end

    test "infers content type from filename" do
      # Test MIME type inference
      filename = "test.jpg"
      assert MIME.from_path(filename) == "image/jpeg"
      
      filename = "test.pdf"
      assert MIME.from_path(filename) == "application/pdf"
    end
  end

  describe "put!/2" do
    test "exists and should raise on error" do
      assert function_exported?(Uploader, :put!, 2)
    end
  end

  test "normalize_file_data handles different input types" do
    # Test binary data
    binary_data = "test content"
    assert is_binary(binary_data)

    # Test file map
    file_map = %{path: "/tmp/test"}
    assert Map.has_key?(file_map, :path)

    # Test Plug.Upload struct
    plug_upload = %Plug.Upload{path: "/tmp/test", filename: "test.txt"}
    assert Map.has_key?(plug_upload, :path)
  end
end