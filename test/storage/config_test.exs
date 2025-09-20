defmodule Storage.ConfigTest do
  use ExUnit.Case, async: true

  alias Storage.Config

  describe "default_service/0" do
    test "returns configured default service" do
      # Test with the default configuration from test_helper.exs
      assert Config.default_service() == :test_local
    end
  end

  describe "services/0" do
    test "returns configured services" do
      services = Config.services()
      assert is_map(services)
      assert Map.has_key?(services, :test_local)
    end
  end

  describe "service_config/1" do
    test "returns service configuration" do
      {module, config} = Config.service_config(:test_local)
      assert module == Storage.Services.Local
      assert Keyword.get(config, :root) == "/tmp/storage_test"
    end

    test "raises error for unknown service" do
      assert_raise ArgumentError, ~r/Service :unknown not configured/, fn ->
        Config.service_config(:unknown)
      end
    end
  end

  describe "service_module/1" do
    test "returns service module" do
      module = Config.service_module(:test_local)
      assert module == Storage.Services.Local
    end
  end

  describe "repo/0" do
    test "raises error when repo not configured" do
      # Since we haven't configured a repo in tests
      assert_raise RuntimeError, "Storage repo not configured", fn ->
        Config.repo()
      end
    end
  end
end