defmodule Volapi.Module do
  @moduledoc """
  Module which provides functionality used for creating Volapi modules.


  When this module is used, it will create wrapper functions which allow it to be automatically registered as a module and include all macros. It can be included with:
  `use Kaguya.Module, "module name here"`


  Once this is done, the module will start automatically and you will be able to use `handle`, `defh`, and other macros.


  Modules can be loaded and unloaded using `Volapi.Util.loadModule`, `Volapi.Util.unloadModule`,
  and `Volapi.Util.reloadModule` (This has not actually been implemented yet. Placeholder documentaion).


  Modules also provide three hooks for certain events that you may want to react to.
  These are `module_init()`, `module_load()`, and `module_unload()`. Init will be run when the bot
  starts, and the load/unload functions are run whenever a module is loaded or unloaded.
  """

  defmacro __using__(module_name) do
    quote bind_quoted: [module_name: module_name] do
      use GenServer
      import Volapi.Module

      @module_name module_name
      @task_table String.to_atom("#{@module_name}_tasks")
      @before_compile Volapi.Module

      init_attrs()

      def start_link(opts \\ []) do
        {:ok, _pid} = GenServer.start_link(__MODULE__, :ok, opts)
      end

      defoverridable start_link: 1

      def init(:ok) do
        require Logger
        Logger.log :debug, "Started module #{@module_name}!"
        :pg2.join(:modules, self)
        :ets.insert(:modules, {@module_name, self})
        :ets.new(@task_table, [:set, :public, :named_table, {:read_concurrency, true}, {:write_concurrency, true}])
        Process.register(self, __MODULE__)
        module_init()
        {:ok, []}
      end

      defoverridable init: 1

      def handle_cast(:unload, state) do
        require Logger
        :pg2.leave(:modules, self)
        module_unload()
        Logger.log :debug, "Unloaded module #{@module_name}!"
        {:noreply, state}
      end

      def handle_cast(:load, state) do
        require Logger
        :pg2.join(:modules, self)
        module_load()
        Logger.log :debug, "Loaded module #{@module_name}!"
        {:noreply, state}
      end

      def module_init do
      end

      defoverridable module_init: 0

      def module_load do
      end

      defoverridable module_load: 0

      def module_unload do
      end

      defoverridable module_unload: 0

      def on_message(msg) do
      end

      defoverridable on_message: 1

      # Used to scan for valid modules on start
      defmodule Volapi_Module do
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def handle_cast({_, message}, state) do
        on_message(message)
        {:noreply, state}
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

  @doc """
  Defines a group of matchers which will handle all messages of the corresponding event.
  ## Example
  ```
  handle "chat" do
    match "hi", :hiHandler
    match "hey", :heyHandler
  end
  ```
  In the example, chat messages that are equal to "hi" or "hey" (without quotes) will be matched against `:hiHandler` and `:heyHandler`

  The available options for `handle` are:
  - chat
  - file
  - file_delete
  - timeout
  - user_count
  - logged_in
  - is_owner
  - connect
  """
  defmacro handle("chat", do: body) do
    quote do
      def handle_cast({:msg, %Volapi.Message.Chat{} = var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro handle("file", do: body) do
    quote do
      def handle_cast({:file, %Volapi.Message.File{} = var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro handle("file_delete", do: body) do
    quote do
      def handle_cast({:file_delete, var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro handle("timeout", do: body) do
    quote do
      def handle_cast({:timeout, %Volapi.Message.Timeout{} = var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro handle("user_count", do: body) do
    quote do
      def handle_cast({:user_count, var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro handle("logged_in", do: body) do
    quote do
      def handle_cast({:logged_in, var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro handle("is_owner", do: body) do
    quote do
      def handle_cast({:is_owner, var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro handle("connect", do: body) do
    quote do
      def handle_cast({:connect, var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro handle("config", do: body) do
    quote do
      def handle_cast({:config, var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  defmacro handle("config_raw", do: body) do
    quote do
      def handle_cast({:config_raw, var!(message)}, state) do
        on_message(var!(message))
        unquote(body)
        {:noreply, state}
      end
    end
  end

  @doc """
  Defines a matcher which always calls its corresponding
  function. Example: `match_all :pingHandler`
  The available options are:
  * async - runs the matcher asynchronously when this is true
  * uniq - ensures only one version of the matcher can be running per channel.
  Should be used with async: true.
  """
  defmacro match_all(function, opts \\ []) do
    add_handler_impl(function, __CALLER__.module, [])
    func_exec_ast = quote do: unquote(function)(var!(message), %{})
    uniq? = Keyword.get(opts, :uniq, false)
    overrideable? = Keyword.get(opts, :overrideable, false)

    func_exec_ast
    |> check_async(Keyword.get(opts, :async, false))
    |> check_unique(function, uniq?, overrideable?)
  end

  @doc """
  Defines a matcher which will match a regex againt the trailing portion
  of an IRC message. Example: `match_re ~r"me|you", :meOrYouHandler`
  The available options are:
  * async - runs the matcher asynchronously when this is true
  * uniq - ensures only one version of the matcher can be running per channel.
  Should be used with async: true.
  """
  defmacro match_re(re, function, opts \\ []) do
    add_handler_impl(function, __CALLER__.module, [])

    func_exec_ast = quote do: unquote(function)(var!(message), res)

    uniq? = Keyword.get(opts, :uniq, false)
    overrideable? = Keyword.get(opts, :overrideable, false)

    func_exec_ast
    |> check_async(Keyword.get(opts, :async, false))
    |> check_unique(function, uniq?, overrideable?)
    |> add_re_matcher(re)
  end

  defp add_re_matcher(body, re) do
    quote do
      m = Volapi.Util.get_text_from_message(var!(message))
      case Regex.named_captures(unquote(re), m) do
        nil -> :ok
        res -> unquote(body)
      end
    end
  end

  @doc """
  Defines a matcher which will match a string defining
  various capture variables against the trailing portion
  of an IRC message.
  ## Example
  ```
  handle "PRIVMSG" do
    match "!rand :low :high", :genRand, match_group: "[0-9]+"
    match "!join :channel([#&][a-zA-Z0-9]+)", :joinChannel"
    match ["!say ~msg", "!s ~msg"], :sayMessage
  end
  ```
  In this example, the genRand function will be called
  when a user sends a message to a channel saying something like
  `!rand 0 10`. If both parameters are strings, the genRand function
  will be passed the messages, and a map which will look like `%{low: 0, high: 10}`.
  Additionally the usage of a list allows for command aliases, in the second match.
  The second match well find channel joining messages, using an embedded regex to
  validate a channel. These embedded regexs will override the match_group value
  and should be used when you need to match multiple parameters which will not
  accept the same regex. That or if you just don't feel like writing `match_group: ""`.
  Available match string params are `:param` and `~param`. The former
  will match a specific space separated parameter, whereas the latter matches
  an unlimited number of characters.
  Match can also be called with a few different options. Currently there are:
  * match_group - Default regex which is used for matching in the match string. By default
  it is `[a-zA-Z0-9]+`
  * async - Whether or not the matcher should be run synchronously or asynchronously.
  By default it is false, but should be set to true if await_resp is to be used.
  * uniq - When used with the async option, this ensures only one version of the matcher
  can be running at any given time. The uniq option can be either channel level or nick level,
  specified with the option :chan or :nick.
  * uniq_overridable - This is used to determine whether or not a unique match can be overriden
  by a new match, or if the new match should exit and allow the previous match to continue running.
  By default it is true, and new matches will kill off old matches.
  """
  defmacro match(match, function, opts \\ [])

  defmacro match(match_str, function, opts) when is_bitstring(match_str) do
    make_match(match_str, function, opts, __CALLER__.module)
  end

  defmacro match(match_list, function, opts) when is_list(match_list) do
    for match <- match_list, do: make_match(match, function, opts, __CALLER__.module)
  end

  defp make_match(match_str, function, opts, module) do
    add_handler_impl(function, module, get_var_list(match_str))

    uniq? = Keyword.get(opts, :uniq, false)
    overrideable? = Keyword.get(opts, :overrideable, false)
    async? = Keyword.get(opts, :async, false)
    match_group = Keyword.get(opts, :match_group, "[a-zA-Z0-9]+")

    gen_match_func_call(function)
    |> check_unique(function, uniq?, overrideable?)
    |> check_async(async?)
    |> add_captures(match_str, match_group)
  end

  defp get_var_list(match_str) do
    String.split(match_str)
    |> Enum.reduce([], fn(part, acc) ->
      case String.first(part) do
        "\\:" -> [String.lstrip(part, ?:)|acc]
        ":" -> [String.lstrip(part, ?:)|acc]
        "~" -> [String.lstrip(part, ?~)|acc]
        _ -> acc
      end
    end)
  end

  defp add_handler_impl(name, module, vars) do
    Module.put_attribute(module, :handlers, {name, vars})
  end

  defp get_match_var_num(match_str) do
    String.split(match_str)
    |> Enum.reduce(0, fn part, acc ->
      case String.first(part) do
        ":" -> acc + 1
        _ -> acc
      end
    end)
  end

  defp gen_match_func_call(function) do
    quote do
      unquote(function)(var!(message), res)
    end
  end

  defp check_unique(body, function, use_uniq?, overrideable?)

  defp check_unique(body, _function, false, _overrideable), do: body

  defp check_unique(body, function, uniq_type, overrideable?) do
    id_string = get_unique_table_id(function, uniq_type)
    create_unique_match(body, id_string, overrideable?)
  end

  defp get_unique_table_id(function, type) do
    fun_string = Atom.to_string(function)
    case type do
      true -> quote do: "#{unquote(fun_string)}_#{chan}_#{nick}"
      :chan -> quote do: "#{unquote(fun_string)}_#{chan}"
      :nick -> quote do: "#{unquote(fun_string)}_#{chan}_#{nick}"
    end
  end

  defp create_unique_match(body, id_string, overrideable?)

  defp create_unique_match(body, id_string, true) do
    quote do
      [chan] = var!(message).args
      %{nick: nick} = var!(message).user

      case :ets.lookup(@task_table, unquote(id_string)) do
        [{_fun, pid}] ->
          Process.exit(pid, :kill)
          :ets.delete(@task_table, unquote(id_string))
        [] -> nil
      end
      :ets.insert(@task_table, {unquote(id_string), self})
      unquote(body)
      :ets.delete(@task_table, unquote(id_string))
    end
  end

  defp create_unique_match(body, id_string, false) do
    quote do
      [chan] = var!(message).args
      %{nick: nick} = var!(message).user
       case :ets.lookup(@task_table, unquote(id_string)) do
        [{_fun, pid}] -> nil
        [] ->
          :ets.insert(@task_table, {unquote(id_string), self})
          unquote(body)
          :ets.delete(@task_table, unquote(id_string))
      end
    end
  end

  defp check_async(body, async?)

  defp check_async(body, true) do
    quote do
      Task.start fn ->
        unquote(body)
      end
    end
  end

  defp check_async(body, false), do: body

  defp add_captures(body, match_str, match_group) do
    re = match_str |> extract_vars(match_group) |> Macro.escape
    quote do
      m = Volapi.Util.get_text_from_message(var!(message))
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
      "\\:" <> param ->
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

  @doc """
  Convenience macro for defining handlers. It injects the variable `message` into
  the environment allowing macros like `reply` to work automatically. It additionally
  detects various map types as arguments and is able to differentiate between maps
  which destructure Kaguya messages, vs. the match argument.
  For example:
  ```
  # This handler matches all calls to it.
  defh some_handler do
    ...
  end
  # This handler matches the IRC message struct's nick param.
  defh some_other_handler(%{user: %{nick: nick}}) do
    ...
  end
  # This handler matches the given match argument's value.
  defh some_other_handler(%{"match_arg" => val) do
    ...
  end
  # This handler matches the given match argument's value and the IRC message's nick.
  # Note that the order of these two maps in the arguments DOES NOT MATTER.
  # The macro will automatically detect which argument is mapped to which type of input for you.
  defh some_other_handler(%{user: %{nick: nick}, %{"match_arg" => val) do
    ...
  end
  ```
  """
  defmacro defh({name, _line, nil}, do: body) do
    args = quote do: [var!(message), var!(args)]
    make_defh_func(name, args, body)
  end

  defmacro defh({name, _line, [arg]}, do: body) do
    args =
      case get_map_type(arg) do
        :msg_map -> quote do: [var!(message) = unquote(arg), var!(args)]
        :arg_map -> quote do: [var!(message), var!(args) = unquote(arg)]
      end
    make_defh_func(name, args, body)
  end

  defmacro defh({name, _line, [arg1, arg2]}, do: body) do
    args =
      case {get_map_type(arg1), get_map_type(arg2)} do
        {:msg_map, :arg_map} -> quote do: [var!(message) = unquote(arg1), var!(args) = unquote(arg2)]
        {:arg_map, :msg_map} -> quote do: [var!(args) = unquote(arg1), var!(message) = unquote(arg2)]
      end
    make_defh_func(name, args, body)
  end

  # Maintain legacy compat in a few situations with old defh
  defp get_map_type({:_, _, _}) do
    :msg_map
  end
  defp get_map_type(qmap) do
    {:%{}, _line, kvs} = qmap
    keys = Enum.map(kvs, fn {key, _val} -> key end)
    case {Enum.all?(keys, &is_atom/1), Enum.all?(keys, &is_bitstring/1)} do
      {true, false} -> :msg_map
      {false, true} -> :arg_map
      _ -> raise "Maps in defh must be all atoms for a message, or all strings for arguments!"
    end
  end

  defp make_defh_func(name, args, body) do
    quote do
      def unquote(name)(unquote_splicing(args)) do
        unquote(body)
        # Suppress unused var warning
        var!(message)
        var!(args)
      end
    end
  end

  @doc """
  Enforces certain constraints around a block. This will replace
  the validate macro.
  ## Example:
  ```
  def is_me(msg), do: true
  def not_ignored(msg), do: true
  handle "PRIVMSG" do
    enforce [:is_me, :not_ignored] do
      match "Hi", :someHandler
    end
    enforce :is_me do
      match "Bye", :someOtherHandler
    end
  ```
  """
  defmacro enforce(validators, do: body) when is_list(validators) do
    enforce_rec(validators, body)
  end

  defmacro enforce(validator, do: body) do
    enforce_rec([validator], body)
  end

  def enforce_rec([{m, v}], body) do
    quote do
      if apply(unquote(m), unquote(v), [var!(message)]) do
        unquote(body)
      end
    end
  end

  def enforce_rec([{m, v} | rest], body) do
    nb =
      quote do
        if apply(unquote(m), unquote(v), [var!(message)]) do
          unquote(body)
        end
      end

    enforce_rec(rest, nb)
  end

  def enforce_rec([v], body) do
    quote do
      if unquote(v)(var!(message)) do
        unquote(body)
      end
    end
  end

  def enforce_rec([v|rest], body) do
    nb =
      quote do
        if unquote(v)(var!(message)) do
          unquote(body)
        end
      end

    enforce_rec(rest, nb)
  end

  @doc """
  Sends a response to the sender of the PRIVMSG with a given message.
  Example: `reply "Hi"`
  """
  defmacro reply(response) do
    quote do
      room = var!(message).room
      Volapi.Client.Sender.send_message(unquote(response), room)
    end
  end

  @doc """
  Sends a response to the sender of the PRIVMSG with a given message via a private message.
  Example: `reply_me "Hi"`
  """
  defmacro reply_me(response) do
    quote do
      room = var!(message).room
      Volapi.Client.Sender.send_message(unquote(response), :me, room)
    end
  end

  @doc """
  Sends a response to the sender of the PRIVMSG with a given message via a private message.
  Example: `reply_admin "Hi"`
  """
  defmacro reply_admin(response) do
    quote do
      room = var!(message).room
      Volapi.Client.Sender.send_message(unquote(response), :admin, room)
    end
  end

  @doc """
  Waits for an irc user to send a message which matches the given match string,
  and returns the resulting map. The user(s) listened for, channel listened for,
  timeout, and match params can all be tweaked. If the matcher times out,
  the variables new_message and resp will be set to nil, otherwise they will
  contain the message and the parameter map respectively for use.
  You must use await_resp in a match which has the asnyc: true
  flag enabled or the module will time out.
  ## Example
  ```
  def handleOn(message, %{"target" => t, "repl" => r}) do
    reply "Fine."
    {msg, _resp} = await_resp t
    if msg != nil do
      reply r
    end
  end
  ```
  In this example, the bot will say "Fine." upon the function being run,
  and then wait for the user in the channel to say the target phrase.
  On doing so, the bot responds with the given reply.
  await_resp also can be called with certain options, these are:
  * match_group - regex to be used for matching parameters in the given string.
  By default this is `[a-zA-Z0-9]+`
  * nick - the user whose nick will be matched against in the callback. Use :any
  to allow for any nick to be matched against. By default, this will be the nick
  of the user who sent the currently processed messages
  * chan - the channel to be matched against. Use :any to allow any channel to be matched
  against. By default this is the channel where the currently processed message was sent from.
  * timeout - the timeout period for a message to be matched, in milliseconds. By default it is
  60000, or 60 seconds.
  """
  defmacro await_resp(match_str, opts \\ []) do
    match_group = Keyword.get(opts, :match_group, "[a-zA-Z0-9]+")
    timeout = Keyword.get(opts, :timeout, 60000)
    quote bind_quoted: [opts: opts, timeout: timeout, match_str: match_str, match_group: match_group] do
      nick = Keyword.get(opts, :nick, var!(message).user.nick)
      [def_chan] = var!(message).args
      chan = Keyword.get(opts, :chan, def_chan)
      Kaguya.Module.await_resp(match_str, chan, nick, timeout, match_group)
    end
  end

  @doc """
  Actual function used to execute await_resp. The macro should be preferred
  most of the time, but the function can be used if necessary.
  """
  def await_resp(match_str, chan, nick, timeout, match_group) do
    has_vars? = match_str |> get_var_list |> length > 0

    match_fun = get_match_fun(match_str, chan, nick, match_group, has_vars?)

    try do
      GenServer.call(Kaguya.Module.Core, {:add_callback, match_fun}, timeout)
    catch
      :exit, _ -> GenServer.cast(Kaguya.Module.Core, {:remove_callback, self})
      {nil, nil}
    end
  end

  defp get_match_fun(match_str, chan, nick, match_group, has_vars?)

  defp get_match_fun(match_str, chan, nick, match_group, true) do
    re = match_str |> extract_vars(match_group)
    fn msg ->
      if (msg.args == [chan] or chan == :any) and (msg.user.nick == nick or nick == :any) do
        case Regex.named_captures(re, msg.trailing) do
          nil -> false
          res -> {true, {msg, res}}
        end
      else
        false
      end
    end
  end

  defp get_match_fun(match_str, chan, nick, _match_group, false) do
    fn msg ->
      if match_str == msg.trailing and (msg.args == [chan] or chan == :any) and (msg.user.nick == nick or nick == :any) do
        {true, {msg, nil}}
      else
        false
      end
    end
  end
end
