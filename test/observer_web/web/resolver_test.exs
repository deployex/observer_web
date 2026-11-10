defmodule Observer.Web.ResolverTest do
  use ExUnit.Case, async: true

  doctest Observer.Web.Resolver

  alias Observer.Web.AccessError
  alias Observer.Web.Resolver

  describe "can?/2" do
    test "allows every action under :all" do
      assert Resolver.can?(:kill_process, :all)
      assert Resolver.can?(:anything, :all)
    end

    test "denies every action under :read_only" do
      refute Resolver.can?(:kill_process, :read_only)
      refute Resolver.can?(:anything, :read_only)
    end

    test "consults the keyword list for fine grained access" do
      access = [kill_process: true, close_port: false]

      assert Resolver.can?(:kill_process, access)
      refute Resolver.can?(:close_port, access)
      refute Resolver.can?(:send_message, access)
    end

    test "fails closed for an access value it doesn't recognize" do
      refute Resolver.can?(:kill_process, {:forbidden, "/"})
      refute Resolver.can?(:kill_process, nil)
    end
  end

  describe "enforce_access!/2" do
    test "returns :ok when the action is permitted" do
      assert Resolver.enforce_access!(:kill_process, :all) == :ok
      assert Resolver.enforce_access!(:kill_process, kill_process: true) == :ok
    end

    test "raises AccessError when the action isn't permitted" do
      assert_raise AccessError, fn -> Resolver.enforce_access!(:kill_process, :read_only) end
      assert_raise AccessError, fn -> Resolver.enforce_access!(:kill_process, []) end
    end
  end
end
