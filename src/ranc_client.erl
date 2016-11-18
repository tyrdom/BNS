%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 31. 十月 2016 18:37
%%%-------------------------------------------------------------------
-module(ranc_client).
-author("Administrator").

-behaviour(gen_server).
-behaviour(ranch_protocol).

%% API
-export([start_link/4,init/4,send/4]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).
-define(TIMEOUT, 10000).
-record(state, {socket,transport,status}).
%status unknown 未知 access 已经通过验证登录 matching 匹配中 battle 战斗中
%       login 登录中 create 创建中
%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link(Ref::term(),Socket::term(),Transport::term(),Opts::term()) ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(Ref,Socket,Transport,Opts) ->
  proc_lib:start_link( ?MODULE, init, [Ref,Socket,Transport,Opts]).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

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
init([]) ->
  {ok, undefined}.

init(Ref, Socket, Transport, _Opts = []) ->
  ok = proc_lib:init_ack({ok, self()}),
  ok = ranch:accept_ack(Ref),
  ok = Transport:setopts(Socket, [{active, 10}, {packet, 4}]),
  gen_server:enter_loop(?MODULE, [],
    #state{socket = Socket, transport = Transport},
    ?TIMEOUT).

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

handle_info({tcp, Socket, Data}, State=#state{ socket=Socket, transport= _Transport}) ->
  io:format("Data:~p~n", [Data]),
  % Transport:setopts(Socket, [{active, 5}]),
  OldStatus = State#state.status,
  Status =  proto_trans:call(OldStatus,Data,Socket,self()),
  NewState = State#state{status = Status},
  {noreply, NewState, ?TIMEOUT};


handle_info({send,Socket,{error,Msg}}, State = #state{ socket = Socket, transport = _Transport}) ->


  {warning,Pack} = proto_trans:reply(error,Msg),

  gen_tcp:send(Socket, Pack),



  {stop, normal, State,?TIMEOUT};



handle_info({beat_send,Socket,{beat,Msg}}, State = #state{ socket = Socket, transport = Transport}) ->
  Transport:setopts(Socket, [{active, 5}]),
  io:format("~p socket pid want send ~p ~p ~n",[self(), beat,Msg]),


        {NewStatus,Pack} = proto_trans:reply(beat,Msg),

        gen_tcp:send(Socket, Pack),
        NewState = State#state{status = NewStatus},

  {noreply, NewState, ?TIMEOUT};


handle_info({send,Socket,{OldStatus,Msg}}, State = #state{ socket = Socket, transport = Transport}) ->
  Transport:setopts(Socket, [{active, 5}]),
  io:format("~p socket pid want send ~p ~p ~n",[self(), OldStatus,Msg]),
  NewState =
    case OldStatus =:= State#state.status of
    true ->
    {NewStatus,Pack} = proto_trans:reply(OldStatus,Msg),

                    gen_tcp:send(Socket, Pack),
                    State#state{status = NewStatus};
    false -> io:format("wrong status"),
                    send(error,self(),Socket,status_error),
                    State#state{status = warning}
  end,
  {noreply, NewState, ?TIMEOUT};


handle_info({tcp_closed, Socket}, State = #state{socket = Socket}) ->

  proto_trans:call(exc_quit,Socket,self()),

  {stop, normal, State};
handle_info({tcp_error, _, Reason}, State = #state{socket = Socket}) ->
  proto_trans:call(exc_quit,Socket,self()),

  {stop, Reason, State};

handle_info(timeout, State = #state{socket = Socket}) ->
  gen_tcp:close(Socket),
  {stop, normal, State};

handle_info(_Info, State = #state{socket = Socket}) ->
  proto_trans:call(exc_quit,Socket,self()),
  {stop, normal, State}.

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
send(beat,SPid,Socket,Msg)
->SPid!{beat_send,Socket,{beat,Msg}};

send(StatusOrType,SPid,Socket,Msg)
  ->SPid!{send,Socket,{StatusOrType,Msg}}.