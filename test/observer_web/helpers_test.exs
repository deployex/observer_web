defmodule Observer.Web.HelpersTest do
  use ExUnit.Case, async: true

  alias Observer.Web.Helpers

  doctest Observer.Web.Helpers

  describe "parse_term/1" do
    test "rejects a map-update expression instead of crashing" do
      # `%{foo | bar: 1}` quotes to a 3-tuple ({:|, _, [left, right]}) nested inside the map's
      # pairs list - a shape literal_term? used to crash on by assuming every pair is a 2-tuple.
      assert :error = Helpers.parse_term("%{foo | bar: 1}")
    end

    test "rejects invalid UTF-8 instead of crashing" do
      assert :error = Helpers.parse_term(<<0xFF, 0xFE>>)
    end
  end
end
