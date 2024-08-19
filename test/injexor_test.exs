defmodule InjexorTest do
  use ExUnit.Case, async: true

  import Injexor
  import Hammox

  setup :verify_on_exit!

  setup_all do
    Application.put_env(
      :injexor,
      InjexorTest.Inject.ExampleBehaviour,
      inject: InjexorTest.Inject.Example.Mock
    )

    Application.put_env(:injexor, :default, Mock)

    Hammox.defmock(InjexorTest.Inject.Example.Mock, for: InjexorTest.Inject.ExampleBehaviour)

    :ok
  end

  test "uses default mock" do
    defmodule DefaultMock do
      # AnotherBehaviour isn't defined in env so it should use the default and add Mock
      use Injexor,
        inject: [{InjexorTest.Inject.Example, InjexorTest.Inject.AnotherBehaviour}]

      def call() do
        InjexorTest.Inject.Example.call([])
      end
    end

    InjexorTest.Inject.Example.Mock
    |> expect(:call, fn [] -> :error end)

    assert :error == DefaultMock.call()
  end

  test "inject with full module" do
    defmodule InjectAll do
      use Injexor,
        inject: [{InjexorTest.Inject.Example, InjexorTest.Inject.ExampleBehaviour}]

      def call() do
        InjexorTest.Inject.Example.call([])
      end
    end

    InjexorTest.Inject.Example.Mock
    |> expect(:call, fn [] -> :error end)

    assert :error == InjectAll.call()
  end

  test "inject when piping" do
    defmodule Pipe do
      use Injexor,
        inject: [InjexorTest.Inject.Example]

      def call() do
        "test"
        |> String.downcase()
        |> InjexorTest.Inject.Example.call()
        |> String.downcase()
      end
    end

    InjexorTest.Inject.Example.Mock
    |> expect(:call, fn "test" -> "some content" end)

    assert "some content" = Pipe.call()
  end

  test "inject when using with" do
    defmodule With do
      use Injexor, inject: [InjexorTest.Inject.Example]

      def call() do
        with {:ok, content} <- InjexorTest.Inject.Example.call("test") do
          content
        end
      end
    end

    InjexorTest.Inject.Example.Mock
    |> expect(:call, fn "test" -> "some content" end)

    assert "some content" = With.call()
  end

  test "inject with alias" do
    defmodule InjectAllAlias do
      use Injexor, inject: [InjexorTest.Inject.Example]

      alias InjexorTest.Inject.Example

      def call() do
        Example.call("test")
      end
    end

    InjexorTest.Inject.Example.Mock
    |> expect(:call, fn "test" -> "some content" end)

    assert "some content" = InjectAllAlias.call()
  end

  test "inject with nested alias" do
    defmodule InjectNestedAlias do
      use Injexor, inject: [InjexorTest.Inject.Example]

      alias InjexorTest.Inject

      def call() do
        Inject.Example.call("test")
      end
    end

    InjexorTest.Inject.Example.Mock
    |> expect(:call, fn "test" -> "some content" end)

    assert "some content" = InjectNestedAlias.call()
  end

  test "@inject with full module" do
    defmodule Inject do
      use Injexor

      @inject InjexorTest.Inject.Example
      def call() do
        InjexorTest.Inject.Example.call("test")
      end
    end

    InjexorTest.Inject.Example.Mock
    |> expect(:call, fn "test" -> "some content" end)

    assert "some content" = Inject.call()
  end

  test "@inject with alias" do
    defmodule InjectAlias do
      use Injexor

      alias InjexorTest.Inject.Example

      @inject Example
      def call() do
        Example.call("test")
      end
    end

    InjexorTest.Inject.Example.Mock
    |> expect(:call, fn "test" -> "some content" end)

    assert "some content" = InjectAlias.call()
  end

  test "@inject with guard doesn't break guard" do
    defmodule GuardInject do
      use Injexor

      @inject InjexorTest.Inject.Example
      def call(string) when is_binary(string) do
        InjexorTest.Inject.Example.call("test")
      end
    end

    assert_raise FunctionClauseError, fn ->
      GuardInject.call(1)
    end
  end

  test "@inject doesn't impact other functions" do
    defmodule NoInject do
      use Injexor

      @inject InjexorTest.Inject.Example
      def call() do
        InjexorTest.Inject.Example.call("test")
      end

      def no_inject_call() do
        InjexorTest.Inject.Example.call("test")
      end
    end

    try do
      NoInject.no_inject_call()
    catch
      :exit, {:noproc, {:gen_server, :call, _args}} -> :ok
    end
  end

  test "unable to autodetect behaviours" do
    assert_raise RuntimeError, fn ->
      defmodule NoBehaviour do
        use Injexor, inject: [InjexorTest.Inject.ExampleNoBehaviour]

        def call() do
          InjexorTest.Inject.ExampleNoBehaviour.call("test")
        end
      end
    end
  end
end
