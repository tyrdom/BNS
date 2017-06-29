%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 25. 十月 2016 18:00
%%%-------------------------------------------------------------------
-module(matcher).
-author("Administrator").

-behaviour(gen_server).

%% API
-export([start_link/3,match_a_player/3]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).
-include("base_config.hrl").
-record(state, {matchList,rooms,sock_pid_account_table,account_bank}).
-record(matcher,{rank,account_id}).
%%%===================================================================
%%% API
%%%===================================================================
match_a_player(_Socket,_SPid,_Mode) -> ok.
%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
%%-spec(start_link(A::term(),B::term()) ->
%%  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(RoomList,SPAT,ABank) ->
  gen_server:start_link( {local,?SERVER},?MODULE, [RoomList,SPAT,ABank], []).

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
init([RoomList,SPAT,ABank]) ->
  MatchList = ets:new(matchlist,[ordered_set]),
  {ok, #state{matchList = MatchList,rooms = RoomList,sock_pid_account_table = SPAT,account_bank = ABank}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%% @spec Player() -> {{Score,Team,AccountId}
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
handle_cast({match_a_player,_Socket,SPid,match}, State = #state{matchList = MList,account_bank = ABank,sock_pid_account_table = SPAT}) ->

  [{SPid,#sock_pid_account_info{account_id = Account_id}}] = ets:lookup(SPAT,SPid),
  [{Account_id,#account_info{account_check = #account_check{rank = Rank}}}] = ets:lookup(ABank,Account_id),

  A_matcher_key = #matcher{rank = Rank,account_id = Account_id},
  ets:insert(MList,{A_matcher_key,matching}),

  {noreply, State};

handle_cast({match_a_player,Socket,SPid,party}, State = #state{rooms = RoomTable,account_bank = ABank,sock_pid_account_table = SPAT}) ->

  [{SPid,#sock_pid_account_info{account_id = Account_id}}] = ets:lookup(SPAT,SPid),
  [{Account_id,#account_info{account_check = #account_check{rank = Rank}}}] = ets:lookup(ABank,Account_id),

  Fun =
    fun ({RoomPid,#room_info{average_rank = AVR}},{LastAbs,LastRoomPid}) ->
      NowAbs = abs (Rank - AVR),
      case NowAbs <LastAbs of
        true -> {NowAbs,RoomPid};
        false -> {LastAbs,LastRoomPid}
      end
  end,

  {_Abs,OkRoomPid} =  ets:foldl(Fun,{1000000,undefined},RoomTable),

  zone:join_room(OkRoomPid,Socket,SPid,Rank),


  {noreply, State};

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
