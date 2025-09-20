defmodule Storage.BlobTest do
  use ExUnit.Case, async: true

  alias Storage.Blob

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        key: "test-key.jpg",
        filename: "test.jpg",
        content_type: "image/jpeg",
        service_name: "local",
        byte_size: 1024,
        checksum: "abc123"
      }

      changeset = Blob.changeset(%Blob{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = Blob.changeset(%Blob{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).key
      assert "can't be blank" in errors_on(changeset).filename
    end

    test "invalid changeset with zero byte_size" do
      attrs = %{
        key: "test-key.jpg",
        filename: "test.jpg", 
        content_type: "image/jpeg",
        service_name: "local",
        byte_size: 0
      }

      changeset = Blob.changeset(%Blob{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).byte_size
    end
  end

  describe "image?/1" do
    test "returns true for image content types" do
      blob = %Blob{content_type: "image/jpeg"}
      assert Blob.image?(blob)

      blob = %Blob{content_type: "image/png"}
      assert Blob.image?(blob)
    end

    test "returns false for non-image content types" do
      blob = %Blob{content_type: "application/pdf"}
      refute Blob.image?(blob)

      blob = %Blob{content_type: "text/plain"}
      refute Blob.image?(blob)
    end
  end

  describe "video?/1" do
    test "returns true for video content types" do
      blob = %Blob{content_type: "video/mp4"}
      assert Blob.video?(blob)

      blob = %Blob{content_type: "video/webm"}
      assert Blob.video?(blob)
    end

    test "returns false for non-video content types" do
      blob = %Blob{content_type: "image/jpeg"}
      refute Blob.video?(blob)
    end
  end

  describe "human_size/1" do
    test "formats bytes correctly" do
      assert Blob.human_size(500) == "500 bytes"
      assert Blob.human_size(1024) == "1.0 KB"
      assert Blob.human_size(1048576) == "1.0 MB"
      assert Blob.human_size(1073741824) == "1.0 GB"
    end

    test "formats blob byte_size correctly" do
      blob = %Blob{byte_size: 2048}
      assert Blob.human_size(blob) == "2.0 KB"
    end
  end

  # Helper function to extract errors from changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end