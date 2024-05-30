defmodule InjexorTest.Inject.Example do
  @behaviour InjexorTest.Inject.ExampleBehaviour

  @impl true
  def call(_opts) do
    :ok
  end
end
