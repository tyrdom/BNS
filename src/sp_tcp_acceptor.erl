%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 31. 十月 2016 16:55
%%%-------------------------------------------------------------------
-module(sp_tcp_acceptor).
-author("Administrator").

-behaviour(gen_server).

%% API
-export([start_link/1,acptloop/1,start/0]).

%% gen_server callbacks
-export([init/1,

  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================
start()-> sp_tcp_ac_sup:start_child().
%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link(Socket::term) ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(LSocket) ->
  proc_lib:start_link(?MODULE,acptloop,[LSocket]).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================
acptloop(LSocket) ->
  io:format("wait client ~n"),

  case gen_tcp:accept(LSocket) of
    {ok,CSocket} -> Pid = sp_tcp_client:start(CSocket),io:format(" client link ~n"),
      case gen_tcp:controlling_process(CSocket, Pid) of
        ok ->  io:format(" client link ok ~n");
        {error, _Err} ->
          gen_tcp:close(CSocket),
          io:format(" client link error ~n")
      end;
    {error,Reason} -> io:format("tcp_acceptor is error ~p ~n",[Reason])

  end,
  ok.
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
  {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([LSocket]) ->
  ok =proc_lib:init_ack({ok,self()}),
  erlang:process_flag(trap_exit, true),
  ok = acptloop(LSocket),
  io:format("acceptor start ~n"),
  gen_server:enter_loop(?MODULE,[],LSocket).

 % {ok, LSocket}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #state{}) ->
  {reply, Reply :: term(), NewState :: #state{}} |
  {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_call(_Request, _From, State) ->

  {reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_cast(_Request, State) ->
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_info(timeout, LSocket) ->

  io:format("wait client ~n"),

    case gen_tcp:accept(LSocket) of
      {ok,CSocket} -> Pid = sp_tcp_client:start(CSocket),io:format(" client link ~n"),
        case gen_tcp:controlling_process(CSocket, Pid) of
          ok ->  io:format(" client link ok ~n");
          {error, _Err} ->
            gen_tcp:close(CSocket),
            io:format(" client link error ~n")
        end;
      {error,Reason} -> io:format("tcp_acceptor is error ~p ~n",[Reason])

    end,
  {noreply, LSocket};
handle_info(_Info, State) ->
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #state{}) -> term()).
terminate(_Reason, _State) ->
  ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
    Extra :: term()) ->
  {ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
