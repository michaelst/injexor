# Injexor

Injexor provides an easy way to replace modules based on behaviours
for mocking during tests or stubbing in another module based on
config for different environments.

See the docs for full instructions: https://hexdocs.pm/injexor

## Installation

The package can be installed by adding `injexor` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:injexor, "~> 1.0.0"}
  ]
end
```

## Example test configuration:

- test.exs

    ```elixir
    config :injexor, default: Mock # adds Mock on the end of all modules by default

    # or you can alternatively register injects manually
    config :injexor, MyApp.MyBehaviour, inject: MyApp.Mock
    ```

- test_helper.exs

    ```elixir
    Hammox.defmock(MyApp.Mock, for: MyApp.MyBehaviour)
    ```

- lib/my_app.ex

    ```elixir
    defmodule MyApp do
      @behaviour MyApp.MyBehaviour

      def deploy_context() do
        Application.fetch_env!(:my_app, :deploy_context)
      end
    end
    ```

- lib/my_app/my_behaviour.ex

    ```elixir
    defmodule  MyApp.MyBehaviour do
      @callback deploy_context() :: atom()
    end
    ```

- lib/my_app/module.ex

    ```elixir
    defmodule MyApp.Module do
      use Injexor, inject: [MyApp]

      def my_function do
        # you can now use mox/hammox to stub/expect this function to test the different paths
        if MyApp.deploy_context() == "production" do
          # do something
        else
          # do something else
        end
      end
    end
    ```
