defmodule SearchAggregator.SettingsTest do
  use ExUnit.Case, async: true

  test "loads runtime settings yaml with defaults" do
    settings = SearchAggregator.Settings.load_file!("test/support/fixtures/settings.yaml")

    assert settings["general"]["instance_name"] == "Test SearchAggregator"
    assert settings["search"]["result_limit"] == 5
    assert settings["search"]["max_limit"] == 7
    assert settings["browser_simulator"]["enabled"] == false
    assert [%{"name" => "wikipedia", "mode" => "http"}] = settings["engines"]
  end
end
