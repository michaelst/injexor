defmodule Injexor do
  @moduledoc """
  Injexor provides an easy way to replace modules based on behaviours
  for mocking during tests or stubbing in another module based on config.

  This allows go to definition and auto complete to continue to function for dev.

  Specified modules are only replaced in function calls that are defined as a callback.

  There are two ways to define an injected module, first is by using the `:inject` opt passed to `use`.
  It can be either a single module or a list.

  ```
  use Injexor, otp_app: :my_app, inject: MyApp.Repo
  use Injexor, otp_app: :my_app, inject: [MyApp.Repo, MyApp.Repo]
  ```

  You can also explicitly tell it what behaviour to use in the case where a module may have many.

  ```
  use Injexor, otp_app: :my_app, inject: {MyApp.Repo, MyApp.Repo.Behaviour}
  ```

  The other way is to define `@inject` attribute above a function def. `@inject` also accepts either
  a single module or a list. This should only be used when you want to affect a single function.

  ```
  use Injexor, otp_app: :my_app

  alias MyApp.Repo

  @inject Repo
  def get(id) do
    Repo.get(id)
  end
  ```

  Then you can call the module as normal in your code and use mox/hammox in your tests.

  `otp_app` is used to look up the module to inject in.

  For example for `use Injexor, otp_app: :my_app, inject: MyApp.Repo`, the macro will lookup the module
  to inject with `Application.get_env(:my_app, MyApp.Repo)`. In testing this will default to
  `MyApp.Team.Mock` if not specified in config, otherwise the default is the module itself.
  """

  defmacro __using__(opts) do
    Module.put_attribute(__CALLER__.module, :inject_all, opts[:inject])
    Module.put_attribute(__CALLER__.module, :otp_app, opts[:otp_app])

    quote do
      @on_definition Injexor.Hooks
      @before_compile Injexor.Hooks
    end
  end
end
