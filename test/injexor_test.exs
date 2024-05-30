defmodule InjexorTest do
  use ExUnit.Case, async: true

  import Injexor
  import Hammox

  setup :verify_on_exit!

  setup_all do
    Application.put_env(
      :my_app,
      InjexorTest.Inject.ExampleBehaviour,
      InjexorTest.Inject.Example.Mock
    )

    Hammox.defmock(InjexorTest.Inject.Example.Mock, for: InjexorTest.Inject.ExampleBehaviour)

    :ok
  end

  test "inject with full module" do
    defmodule InjectAll do
      use Injexor,
        otp_app: :my_app,
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
        otp_app: :my_app,
        inject: [InjexorTest.Inject.Example]

      def call() do
        "test"
        |> String.downcase()
        |> InjexorTest.Inject.Example.call()
        |> String.downcase()
      end
    end

    InjexorTest.Inject.Example.Mock
    |> expect(:call, fn "test" -> "ome content" end)

    assert "ome content" = Pipe.call()
  end

  test "inject when using with" do
    defmodule With do
      use Injexor, otp_app: :my_app, inject: [InjexorTest.Inject.Example]

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
      use Injexor, otp_app: :my_app, inject: [InjexorTest.Inject.Example]

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
      use Injexor, otp_app: :my_app, inject: [InjexorTest.Inject.Example]

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
      use Injexor, otp_app: :my_app

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
      use Injexor, otp_app: :my_app

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
      use Injexor, otp_app: :my_app

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
      use Injexor, otp_app: :my_app

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
end
