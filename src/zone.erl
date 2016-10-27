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

-record(state, {playerList,roomList}).
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
	gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

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
	PlayerList =ets:new(playerList,[set]),
	RoomList = ets:new(roomList,[set]),
	{ok, #state{playerList = PlayerList,roomList = RoomList}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%% @spec  room() -> {RoomPid,PlayerNum,Status}
%%				player() -> {Socket,Spid,Account}
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

handle_call({inZone,Socket,Spid,Account}, _From, State) ->
	PlayerList = State#state.playerList,
	ets:insert(PlayerList,{Socket,Spid,Account}),
	{reply, ok, State};

handle_call({autojoinRoom,Socket,Spid,Account}, _From, State) ->
	PlayerList = State#state.playerList,
	Rooms =State#state.roomList,
	ets:lookup(PlayerList,Socket),
	[[{RoomPid,PlayerNum,unfull}]] = ets:match(Rooms,{'_','_',unfull},1),
	room:join(RoomPid,Spid,Socket,Account),
	case PlayerNum  < ?ROOMMAX-1 of
		false ->ets:insert(Rooms,{RoomPid,?ROOMMAX,full});
		true -> ets:insert(Rooms,{RoomPid,(PlayerNum+1),unfull})
	end,

	{reply, ok, State};

handle_call({createRoom}, _From, State) ->
	RoomPid = room:start_link(),
	Rooms =State#state.roomList,
	case ets:lookup (Rooms,RoomPid) of
			[]->ets:insert(Rooms,{RoomPid,0,unfull});
			[_]->error
	end,
	{reply, ok, State};

handle_call({outZone,Socket,Spid,_Account}, _From, State) ->
	PlayerList = State#state.playerList,
	case ets:lookup(PlayerList,Socket) of

		[_] ->ets:delete(PlayerList,Socket),
			ok;
		[] ->error,Spid ! {tcp_closed, Socket}
	end,

	{reply, ok, State};

handle_call({joinRoom,Socket,Spid,Account,RoomPid}, _From, State) ->
	Rooms = State#state.roomList,
	case ets:lookup(Rooms,RoomPid) of
		[] -> error, Spid ! {tcp_closed, Socket};
		[{RoomPid,PlayerNum,Status}] ->
			case Status of
					full -> error,Spid ! {tcp_closed, Socket};
					unfull ->
						room:join(RoomPid,Spid,Socket,Account),
						case PlayerNum  < ?ROOMMAX-1 of
							false ->ets:insert(Rooms,{RoomPid,?ROOMMAX,full});
							true -> ets:insert(Rooms,{RoomPid,(PlayerNum+1),unfull})
						end
			end
	end,
	{reply, ok, State};

handle_call({joinMatch,Socket,Spid,Account}, _From, State) ->
	matcher:join(Socket,Spid,Account),

	{reply, ok, State};

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
handle_cast({getRoomsInfo,Socket,Pid}, State) ->
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

inZone(Account,Socket,Spid) ->gen_server:call(?SERVER,{inZone,Socket,Spid,Account}).

matchroom(_Rooms) ->todo. %TODO get a room which have a seat