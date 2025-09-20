ExUnit.start()

# Configure test repo if needed
Application.put_env(:storage, :default_service, :test_local)
Application.put_env(:storage, :services, %{
  test_local: {Storage.Services.Local, root: "/tmp/storage_test"}
})