
-module(tcp_server_listener).
-behaviour(gen_server).
-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-record(state, {lsock}).

start_link(Port) ->
  io:format("tcp server listener start ~n"),
  gen_server:start_link({local, ?MODULE}, ?MODULE, [Port], []).

init([Port]) ->
  process_flag(trap_exit, true),
  Opts = [binary, {packet, 0}, {reuseaddr, true},
           {keepalive, true}, {backlog, 30}, {active, false}],
  State =
  case gen_tcp:listen(Port, Opts) of
    {ok, LSock} ->
      start_server_listener(LSock),
      #state{lsock = LSock};
    _Other ->
      throw({error, {could_not_listen_on_port, Port}}),
      #state{}
  end,
    {ok, State}.

handle_call(_Request, _From, State) ->
  io:format("tcp server listener call ~p~n", [_Request]),
  {reply, ok, State}.

handle_cast({tcp_accept, Pid}, State) ->
  io:format("tcp server listener cast ~p~n", [tcp_accept]),
  start_server_listener(State, Pid),
    {noreply, State};

handle_cast(_Msg, State) ->
  io:format("tcp server listener cast ~p~n", [_Msg]),
  {noreply, State}.

handle_info({'EXIT', Pid, _}, State) ->
  io:format("tcp server listener info exit ~p~n", [Pid]),
  start_server_listener(State, Pid),
  {noreply, State};

handle_info(_Info, State) ->
  io:format("tcp server listener info ~p~n", [_Info]),
  {noreply, State}.

terminate(_Reason, _State) ->
  io:format("tcp server listener terminate ~p~n", [_Reason]),
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

start_server_listener(State, Pid) ->
  unlink(Pid),
  start_server_listener(State#state.lsock).

start_server_listener(Lsock) ->
  case tcp_server_sup:start_child(Lsock) of
    {ok, Pid} ->
      link(Pid);
    _Other ->
      do_log
  end.

