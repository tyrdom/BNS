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
-export([start_link/2,inZone/3, join/4]).

%% gen_server callbacks
-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-define(SERVER, ?MODULE).
-include("base_config.hrl").
-record(state, {sock_pid_account_table, room_table}).

%%%===================================================================
%%% API
%%%===================================================================
join(Type,RoomPid,Socket,SPid) ->
	gen_server:cast(?SERVER,{join,Type,RoomPid,Socket,SPid}).

join_room(RoomPid,Socket,SPid,Rank) ->
	gen_server:cast(?SERVER,{join_room,RoomPid,Socket,SPid,Rank}).
%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------

start_link(SPAT,ABank) ->
	gen_server:start_link({local,?SERVER}, ?MODULE, [SPAT,ABank], []).



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
init([SPAT,ABank]) ->

	RoomList = ets:new(roomList,[set]),
	matcher:start_link(RoomList,SPAT,ABank),
	{ok, #state{room_table = RoomList,sock_pid_account_table = SPAT}}.

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

handle_cast({create_room,Type,AllowPlayers,Info}, State = #state{room_table = RTable,sock_pid_account_table = SPAT}) ->
	RoomPid = room:start_link(SPAT,AllowPlayers,RTable),
	ets:insert(RTable,{RoomPid,#room_info{type = Type,allow_players = AllowPlayers,average_rank = 0,player_num = 0 ,info = Info}}),
	{noreply, State};

handle_cast({join,0,RoomPid,Socket,SPid}, State) ->

	join_room(RoomPid,Socket,SPid,0),
	{noreply, State};

handle_cast({join,1,_RoomPid,Socket,SPid}, State) ->
	matcher:match_a_player(Socket,SPid,party),
	{noreply, State};

handle_cast({join,2,_RoomPid,Socket,SPid}, State) ->
	matcher:match_a_player(Socket,SPid,match),
	{noreply, State};

handle_cast({join_room,RoomPid,_Socket,SPid,Rank}, State = #state{room_table = RTable,sock_pid_account_table = SPAT}) ->

	[{RoomPid,#room_info{player_num = PNum,allow_players = Allow_Players}}] = ets:lookup(RTable,RoomPid),
	 case PNum < ?ROOM_MAX of
		 true ->
			 case Allow_Players  of
				undefined -> room:join_room(RoomPid,SPid,Rank);
				 Players -> [{SPid,#sock_pid_account_info{account_id = AccountId}}] = ets:lookup(SPid,SPAT),
					 					case lists:member(AccountId,Players) of
											true -> room:join_room(RoomPid,SPid,Rank);
											flase -> not_allowed
										end

			 end;
		 false -> full_room
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

inZone(Account,Socket, SPid) ->gen_server:call(?SERVER,{inZone,Socket, SPid,Account}).

