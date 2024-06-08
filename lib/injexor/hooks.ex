defmodule Injexor.Hooks do
  def __on_definition__(env, kind, name, args, guards, body) do
    definitions = Module.get_attribute(env.module, :definitions) || []
    arity = length(args)

    # we support passing a single module, or a list of modules
    inject = Module.get_attribute(env.module, :inject) |> to_list()

    # we delete the attribute so the next function doesn't receive it
    Module.delete_attribute(env.module, :inject)

    inject_all =
      Module.get_attribute(env.module, :inject_all)
      |> to_list()
      |> Enum.map(fn
        {:__aliases__, _opts, inject} ->
          Module.concat(inject)

        {{:__aliases__, _inject_opts, inject}, {:__aliases__, _behaviour_opts, behaviour}} ->
          {Module.concat(inject), Module.concat(behaviour)}
      end)

    injects = Enum.map(inject ++ inject_all, &inject(&1, env.aliases))

    definition = %{
      kind: kind,
      name: name,
      arity: arity,
      args: args,
      guards: guards,
      body: body,
      injects: injects
    }

    # decorators cause this function to be called again so we check if we already added it
    already_defined =
      Enum.any?(definitions, fn existing_definition ->
        definition.kind == existing_definition.kind and
          definition.name == existing_definition.name and
          definition.arity == existing_definition.arity and
          definition.args == existing_definition.args and
          definition.guards == existing_definition.guards
      end)

    unless already_defined do
      Module.put_attribute(
        env.module,
        :definitions,
        [definition | definitions]
      )
    end
  end

  defmacro __before_compile__(env) do
    aliases =
      env.aliases
      |> Enum.map(fn {alias_as, alias_module} -> {to_string(alias_as), alias_module} end)
      |> Map.new()

    otp_app = Module.get_attribute(env.module, :otp_app)

    definitions =
      Module.get_attribute(env.module, :definitions)
      # we need to reverse as the definitions were appended to the module attribute
      |> Enum.reverse()
      # we group by these attributes as we need to define a single defoverridable per function arity
      |> Enum.group_by(fn %{kind: kind, name: name, arity: arity} ->
        {kind, name, arity}
      end)
      |> Enum.map(fn {{kind, name, arity}, definitions} ->
        definitions = Enum.map(definitions, &process_definition(&1, otp_app, aliases))

        {kind, name, arity, definitions}
      end)

    for {kind, name, arity, definitions} <- definitions do
      quote do
        # define single defoverrideable per function arity
        defoverridable [{unquote(name), unquote(arity)}]

        # redefine each function with matching injects replaced
        unquote do
          for {call, body} <- definitions do
            quote do
              unquote(kind)(unquote(call), unquote(body))
            end
          end
        end
      end
    end
  end

  defp inject({inject, behaviour}, aliases) do
    # check to see if the inject is aliased because the ast will only have the aliased part
    inject =
      aliases
      |> Enum.find_value([inject], fn {alias_as, alias_module} ->
        inject == alias_module && [alias_as]
      end)
      |> Module.concat()

    {inject, behaviour}
  end

  defp inject(inject, aliases) do
    # check to see if the inject is aliased because the ast will only have the aliased part
    {inject, full_module} =
      aliases
      |> Enum.find_value({inject, inject}, fn {alias_as, alias_module} ->
        inject == alias_module && {alias_as, alias_module}
      end)

    {inject, behaviour(full_module)}
  end

  defp to_list(nil), do: []
  defp to_list(list) when is_list(list), do: list
  defp to_list(item), do: [item]

  defp process_definition(
         %{
           name: name,
           args: args,
           guards: guards,
           body: body,
           injects: injects
         },
         otp_app,
         aliases
       ) do
    call =
      if Enum.empty?(guards) do
        {name, [], args}
      else
        {:when, [], [{name, [], args} | guards]}
      end

    body =
      Macro.prewalk(body, fn
        {:|>, pipe_line,
         [
           piped_ast,
           {{:., _line0, [{:__aliases__, _counter, _module_parts}, _function]}, _line1, _args} =
               ast
         ]} ->
          inject_ast = inject_ast(ast, injects, otp_app, aliases, true)
          {:|>, pipe_line, [piped_ast, inject_ast]}

        {{:., _line0, [{:__aliases__, _counter, _module_parts}, _function]}, _line1, _args} = ast ->
          inject_ast(ast, injects, otp_app, aliases, false)

        other ->
          other
      end)

    {call, body}
  end

  defp inject_ast(ast, injects, otp_app, aliases, is_piping) do
    {{:., line0, [{:__aliases__, counter, module_parts}, function]}, line1, args} = ast
    arity = if is_piping, do: length(args) + 1, else: length(args)
    module = Module.concat(module_parts)
    full_module = module_from_alias(aliases, module)

    # we only match on function calls defined in the behaviour
    with {_inject, behaviour} <-
           Enum.find(injects, fn {inject, _behaviour} ->
             full_module == inject or module == inject
           end),
         inject_module_parts <- inject_module(otp_app, full_module, behaviour),
         true <- {function, arity} in behaviour.behaviour_info(:callbacks) do
      {{:., line0, [{:__aliases__, counter, inject_module_parts}, function]}, line1, args}
    else
      _false ->
        ast
    end
  end

  defp inject_module(otp_app, module, behaviour) do
    Application.get_env(otp_app, behaviour, module)
    |> Module.split()
    |> Enum.map(&String.to_atom/1)
  end

  defp behaviour(module) do
    Enum.find(module.__info__(:attributes), fn {key, _value} ->
      key == :behaviour
    end)
    |> case do
      {:behaviour, [behaviour]} ->
        behaviour

      {:behaviour, behaviours} ->
        raise """
        Unable to autodetect behaviour for module #{inspect(module)}.

        #{module} defines these behaviours: #{inspect(behaviours)}.

        Please specify the behaviour in the inject attribute:

        ```
        use Injexor,
          otp_app: :my_app,
          inject: [{Inject.Example, Inject.ExampleBehaviour}]
        ```
        """

      nil ->
        raise """
        #{inspect(module)} does not define any behaviours.

        Please specify the behaviour in the inject attribute:

        ```
        use Injexor,
          otp_app: :my_app,
          inject: [{Inject.Example, Inject.ExampleBehaviour}]
        ```
        """
    end
  end

  defp module_from_alias(aliases, module) do
    [first | rest] = Module.split(module)

    case Map.get(aliases, "Elixir." <> first) do
      nil -> module
      alias_module -> Module.concat([alias_module | rest])
    end
  end
end
