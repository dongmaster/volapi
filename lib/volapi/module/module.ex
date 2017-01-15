defmodule Volapi.Module do
  defmacro __using__(module_name) do
    quote bind_quoted: [module_name: module_name] do
      use GenServer
      import Volapi.Module

      @module_name module_name
      @before_compile Volapi.Module

      init_attrs()

      def start_link(opts \\ []) do
        {:ok, _pid} = GenServer.start_link(__MODULE__, :ok, [])
      end

      defoverridable start_link: 1

      def init(:ok) do
        require Logger
        Logger.debug("Started module: #{@module_name}")
        :pg2.join(:modules, self())
        :global.register_name(__MODULE__, self())
        :ets.insert(:modules, {@module_name, self()})

        #GenServer.cast(self(), :register_chat_handler)
        #GenServer.cast(self(), :register_file_handler)

        Process.register(self, __MODULE__)
        module_init()
        {:ok, []}
      end

      defoverridable init: 1

      def module_init() do
      end

      defoverridable module_init: 0

      def on_message(msg) do
      end

      defoverridable on_message: 1

      defp get_name_from_message(message) do
        case message do
          %Volapi.Chat{} ->
            message.message
          # get rid of this fucking garbage jesus christ just change it to Volapi.File
          %Volapi.File.Archive{} ->
            message.file_name
          %Volapi.File.Audio{} ->
            message.file_name
          %Volapi.File.Document{} ->
            message.file_name
          %Volapi.File.Image{} ->
            message.file_name
          %Volapi.File.Other{} ->
            message.file_name
          %Volapi.File.Video{} ->
            message.file_name
        end
      end


      #def handle_cast(message, state) do
      #  IO.inspect message
      #  IO.inspect state
      #  on_message(message)
      #  {:noreply, state}
      #end

      # Allows Volapi.Module.Supervisor to find our module.
      defmodule Volapi_Module do
      end
    end
  end

  defmacro __before_compile__(env) do
    quote do
      def handle_cast({:msg, message}, state) do
        on_message(message)
        {:noreply, state}
      end

      def handle_cast({:file, message}, state) do
        on_message(message)
        {:noreply, state}
      end

      def handle_cast({:timeout, message}, state) do
        on_message(message)
        {:noreply, state}
      end

      def handle_cast(_, state) do
        {:noreply, state}
      end

      def blah() do
        IO.puts "blah"
      end
    end
  end


  defmacro init_attrs do
    Module.register_attribute __CALLER__.module,
      :match_docs, accumulate: true, persist: true

    Module.register_attribute __CALLER__.module,
      :handler_impls, accumulate: true, persist: true

    Module.register_attribute __CALLER__.module,
      :handlers, accumulate: true, persist: true
  end




  defmacro handle("chat", do: body) do
    quote do
      def handle_cast({:msg, %Volapi.Chat{} = var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro handle("file", do: body) do
    quote do
      def handle_cast({:file, var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro handle("timeout", do: body) do
    quote do
      def handle_cast({:timeout, var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro match_all(function, opts \\ []) do
    add_handler_impl(function, __CALLER__.module, [])
    func_exec_ast = quote do: unquote(function)(var!(message))

    func_exec_ast
  end

  defmacro match_re(re, function, opts \\ []) do
    add_handler_impl(function, __CALLER__.module, [])

    func_exec_ast = quote do: unquote(function)(var!(message))

    func_exec_ast
    |> add_re_matcher(re)
  end


  defp add_re_matcher(body, re) do
    quote do
      m = get_name_from_message(var!(message))
      case Regex.named_captures(unquote(re), m) do
        nil -> :ok
        res -> unquote(body)
      end
    end
  end


  defmacro match(match, function, opts \\ [])

  defmacro match(match_str, function, opts) when is_bitstring(match_str) do
    make_match(match_str, function, opts, __CALLER__.module)
  end

  defmacro match(match_list, function, opts) when is_list(match_list) do
    for match <- match_list, do: make_match(match, function, opts, __CALLER__.module)
  end

  defp make_match(match_str, function, opts, module) do
    add_handler_impl(function, module, get_var_list(match_str))

    match_group = Keyword.get(opts, :match_group, "[a-zA-Z0-9]+")

    gen_match_func_call(function)
    |> add_captures(match_str, match_group)
  end

  defp gen_match_func_call(function) do
    quote do
      unquote(function)(var!(message), res)
    end
  end

  defp get_var_list(match_str) do
    String.split(match_str)
    |> Enum.reduce([], fn(part, acc) ->
      case String.first(part) do
        "::" -> [String.lstrip(part, ?:)|acc]
        ":" -> [String.lstrip(part, ?:)|acc]
        "~" -> [String.lstrip(part, ?~)|acc]
        _ -> acc
      end
    end)
  end

  defp add_captures(body, match_str, match_group) do
    re = match_str |> extract_vars(match_group) |> Macro.escape
    quote do
      m = get_name_from_message(var!(message))
      case Regex.named_captures(unquote(re), m) do
        nil ->
          :ok
        res -> unquote(body)
      end
    end
  end

  defp extract_vars(match_str, match_group) do
    parts = String.split(match_str)
    l = for part <- parts, do: gen_part(part, match_group)
    expr = "^#{Enum.join(l, " ")}$"
    Regex.compile!(expr)
  end

  defp gen_part(part, match_group) do
    case part do
      "::" <> param ->
        Regex.escape(":" <> param)
      ":" <> param ->
        # Check for embedded regex capture
        case Regex.named_captures(~r/(?<name>[a-zA-Z0-9]+)\((?<re>.+)\)/, param) do
          %{"name" => name, "re" => re} -> "(?<#{name}>#{re})"
          nil -> "(?<#{param}>#{match_group})"
        end
      "~" <> param -> "(?<#{param}>.+)"
      text -> Regex.escape(text)
    end
  end


  defp add_handler_impl(name, module, vars) do
    Module.put_attribute(module, :handlers, {name, vars})
  end
end
