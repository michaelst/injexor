defmodule Injexor do
  @moduledoc """
  Injexor provides an easy way to replace modules based on behaviours
  for mocking during tests or stubbing in another module based on config.

  This allows go to definition and auto complete to continue to function for dev.

  Specified modules are only replaced in function calls that are defined as a callback.

  There are two ways to define an injected module, first is by using the `:inject` opt passed to `use`.
  It can be either a single module or a list.

  ```
  use Injexor, inject: MyApp.Repo
  use Injexor, inject: [MyApp.Repo, MyApp.Repo]
  ```

  You can also explicitly tell it what behaviour to use in the case where a module may have many.

  ```
  use Injexor, inject: {MyApp.Repo, MyApp.Repo.Behaviour}
  ```

  The other way is to define `@inject` attribute above a function def. `@inject` also accepts either
  a single module or a list. This should only be used when you want to affect a single function.

  ```
  use Injexor

  alias MyApp.Repo

  @inject Repo
  def get(id) do
    Repo.get(id)
  end
  ```

  Then you can call the module as normal in your code and use mox/hammox in your tests.

  For example for `use Injexor, inject: MyApp.Repo`, the macro will lookup the module
  to inject with `Application.get_env(:injexor, MyApp.Repo)[:inject]`.

  Example config

  ```
  config :injexor, MyApp.Repo, inject: MyApp.Repo.Mock
  ```

  You can altneratively setup a default that will be appended to all modules.

  ```
  config :injexor, :default, Mock
  ```

  If none of the above are set, the module itself will be used.
  """

  defmacro __using__(opts) do
    Module.put_attribute(__CALLER__.module, :inject_all, opts[:inject])

    quote do
      @on_definition Injexor.Hooks
      @before_compile Injexor.Hooks
    end
  end
end
