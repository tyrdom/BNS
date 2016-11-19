%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 21. 十月 2016 12:01
%%%-------------------------------------------------------------------
-module(zone).
-author("Administrator").
-include("other_settings.hrl").
-behaviour(gen_server).

%% API
-export([start_link/0,inZone/3]).

%% gen_server callbacks
-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-define(SERVER, ?MODULE).
-include("account_base_config.hrl").
-record(state, {socket_account_table, room_table}).
-record(room_info,{type,player_num}).
%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
	{ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
	gen_server:start_link( ?MODULE, [], []).

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

	RoomList = ets:new(roomList,[set]),
	{ok, #state{room_table = RoomList},0}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%% @spec
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

handle_cast({create_room,Type}, State = #state{room_table = RTable}) ->
	RoomPid = room:start_link(),
	ets:insert(RTable,{RoomPid,#room_info{type = Type}}),
	{noreply, State};

handle_cast({join_room,RoomPid,_Socket,SPid}, State = #state{room_table = RTable,socket_account_table = SAT}) ->
	RoomPid,#room_info{player_num = PNum} = ets:lookup(RTable,RoomPid),
	 case PNum < ?ROOMMAX of
		 true -> room:join_room(RoomPid,SPid),
		 					ets:SAT;
		 false -> fullroom
	 end,

	{noreply, State};



handle_cast({delete_room,RoomPid}, State = #state{room_table = RTable}) ->

	ets:delete(RTable,RoomPid),
	 room:stop(RoomPid),
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
handle_info({sock_pid_account_table,SAT}, State) ->
	NewState = State#state{socket_account_table = SAT},
	{noreply, NewState};

handle_info(timeout, State) ->
	account_bank:get_state(self(),sock_pid_account_table),
	{noreply, State, 10000};
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

inZone(Account,Socket,Spid) ->gen_server:call(?SERVER,{inZone,Socket,Spid,Account}).

matchroom(_Rooms) ->todo. %TODO get a room which have a seat