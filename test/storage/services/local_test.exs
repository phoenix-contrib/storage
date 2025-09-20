defmodule Storage.Services.LocalTest do
  use ExUnit.Case, async: true

  alias Storage.Services.Local

  setup do
    # Create a temporary directory for testing
    tmp_dir = Path.join(System.tmp_dir!(), "storage_test_#{:rand.uniform(10000)}")
    File.mkdir_p!(tmp_dir)

    config = [root: tmp_dir]

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, config: config, tmp_dir: tmp_dir}
  end

  describe "put_file/3" do
    test "stores binary data", %{config: config, tmp_dir: tmp_dir} do
      key = "test.txt"
      data = "Hello, world!"

      assert :ok = Local.put_file(key, data, config)

      # Verify file was created
      file_path = Path.join(tmp_dir, key)
      assert File.exists?(file_path)
      assert File.read!(file_path) == data
    end

    test "stores file from path", %{config: config, tmp_dir: tmp_dir} do
      # Create source file
      source_file = Path.join(System.tmp_dir!(), "source.txt")
      File.write!(source_file, "source content")

      key = "destination.txt"
      file_data = %{path: source_file}

      assert :ok = Local.put_file(key, file_data, config)

      # Verify file was copied
      dest_path = Path.join(tmp_dir, key)
      assert File.exists?(dest_path)
      assert File.read!(dest_path) == "source content"

      # Cleanup
      File.rm!(source_file)
    end

    test "creates subdirectories as needed", %{config: config, tmp_dir: tmp_dir} do
      key = "subdir/nested/file.txt"
      data = "nested file"

      assert :ok = Local.put_file(key, data, config)

      file_path = Path.join(tmp_dir, key)
      assert File.exists?(file_path)
      assert File.read!(file_path) == data
    end
  end

  describe "get_file/2" do
    test "retrieves existing file", %{config: config, tmp_dir: tmp_dir} do
      key = "test.txt"
      data = "test content"

      # First store the file
      :ok = Local.put_file(key, data, config)

      # Then retrieve it
      assert {:ok, ^data} = Local.get_file(key, config)
    end

    test "returns error for non-existent file", %{config: config} do
      assert {:error, :enoent} = Local.get_file("nonexistent.txt", config)
    end
  end

  describe "delete_file/2" do
    test "deletes existing file", %{config: config, tmp_dir: tmp_dir} do
      key = "test.txt"
      data = "test content"

      # Store file first
      :ok = Local.put_file(key, data, config)
      file_path = Path.join(tmp_dir, key)
      assert File.exists?(file_path)

      # Delete file
      assert :ok = Local.delete_file(key, config)

      # Verify file is gone
      refute File.exists?(file_path)
    end

    test "returns ok for non-existent file", %{config: config} do
      # Deleting a non-existent file should return :ok (idempotent)
      assert :ok = Local.delete_file("nonexistent.txt", config)
    end
  end

  describe "url/3" do
    test "generates URL with default base", %{config: config} do
      key = "test.jpg"
      url = Local.url(key, config)
      assert url == "/storage/#{key}"
    end

    test "generates URL with custom base", %{config: config} do
      key = "test.jpg"
      opts = [base_url: "/files"]
      url = Local.url(key, config, opts)
      assert url == "/files/#{key}"
    end
  end

  describe "signed_url/3" do
    test "returns regular URL for local storage", %{config: config} do
      key = "test.jpg"
      assert {:ok, url} = Local.signed_url(key, config)
      assert url == "/storage/#{key}"
    end
  end
end