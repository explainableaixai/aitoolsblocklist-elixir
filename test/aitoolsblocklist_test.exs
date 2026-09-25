defmodule AIToolsBlocklistTest do
  use ExUnit.Case

  test "constructs a client" do
    client = AIToolsBlocklist.Client.new("test")
    assert client.api_key == "test"
  end
end
