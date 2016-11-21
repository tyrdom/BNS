%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 21. 十月 2016 12:02
%%%-------------------------------------------------------------------
-module(room).
-author("Administrator").

-behaviour(gen_server).
-include("account_base_config.hrl").

%% API
-export([start_link/1,broadcast/1,stop/1,join_room/2,ticker_check/1,reboot_ticker/1]).

%% gen_server callbacks
-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).
-include("other_settings.hrl").
-define(SERVER, ?MODULE).

-record(state, {seats, ticker, tick_cycle_count, receive_cycle_count, type ,ob,sock_pid_account_table}).
%{_Movement,_LostTick,_R_times}
-record(sock_pid_battle_info,{movement,lost_tick,r_times,seat}).
%%%===================================================================
%%% API
%%%===================================================================
a_player_check(RoomPid,SockPid) ->
	gen_server:cast(RoomPid,{a_player_check,SockPid}).

reboot_ticker(RoomPid) ->
	room_ticker:start_link(RoomPid).

broadcast(RoomPid) ->
	gen_server:call(RoomPid,{broadcast}).

ticker_check(RoomPid) ->
	gen_server:cast(RoomPid,{ticker_check}).

join_room(RoomPid,SocketPid) ->
	gen_server:call(RoomPid,{join,SocketPid}).
stop(RoomPid) ->
	gen_server:stop(RoomPid).
%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link(SPAT::term()) ->
	{ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(SPAT) ->
	gen_server:start_link(?MODULE, [SPAT], []).


init_seat(0) -> [];

init_seat(N) ->
	[{N,empty}] ++ init_seat(N-1).

find_seat([]) -> not_find;

find_seat([{Num,empty}|_Q]) -> Num;

find_seat([{_Num,_SomeOne}|Q]) ->
	find_seat(Q).

sit_seat(Seats,A_seat,SockPid) ->
	lists:keyreplace(A_seat,1,Seats,{A_seat,SockPid}).

left_seat(Socket_Pid,Seats) ->

	Fun =
		fun(Seat_Status) ->
			case Seat_Status of
				Socket_Pid ->  empty ;
				_Other -> Seat_Status
				end
		end,
	lists:keymap(Fun,2,Seats).
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
init([SPAT]) ->
	Pid = self(),
	Ticker = room_ticker:start_link(Pid),
	Seat =init_seat(?ROOMMAX),
	{ok, #state{seats = Seat,ticker = Ticker,tick_cycle_count = 0, receive_cycle_count = 0,type = party,ob = off,sock_pid_account_table = SPAT}}.


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

handle_call({broadcast}, _From, State) ->
	Tick = State#state.tick_cycle_count,

	Raw_Msg = get(),
	Shorter = fun({SPid,#sock_pid_battle_info{movement = M}})-> {SPid,M} end,

	Broadcast_Msg = lists:map(Shorter,Raw_Msg),

	B =
		fun (ASockMsg,Acc)
			->
				{SockPid,_SomeThing} = ASockMsg,
				ranc_client:send(battle,SockPid,Broadcast_Msg),
				a_player_check(self(),SockPid),
				Acc
		end,

	lists:foldl(B, ok, Broadcast_Msg),

	NextTick =
		case Tick < 2000000000 of
			true -> Tick + 1;
			false -> 1
		end,

	NewState = State#state{tick_cycle_count = NextTick},

	{reply, ok, NewState};




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

handle_cast({join, SockPid},  State = #state{seats = Seats, type = Type, ob = Ob,sock_pid_account_table = SPAT}) ->
	{Msg,NewSeat} =
	case ets:lookup(SPAT,SockPid) of
		[] -> {error,Seats};
		[{SockPid,SPA = #sock_pid_account_info{special_status = undefined}}] ->
		case Type of
			party -> A_seat = find_seat(Seats),
				case is_integer(A_seat) of
					true -> put(SockPid, #sock_pid_battle_info{movement = 0, lost_tick = 0, r_times = 0, seat = A_seat}),
									ets:insert(SPAT,{SockPid,SPA#sock_pid_account_info{special_status = in_battle}}),
									{ok, sit_seat(Seats,A_seat,SockPid)};
					false ->
						case Ob of
							on 		 -> ets:insert(SPAT,{SockPid,SPA#sock_pid_account_info{special_status = in_battle}}),
												{ok, Seats};
							_Other -> {full, Seats}
						end
				end;

			_Other -> {full, Seats}
		end
	end,
	NewState = State#state{seats = NewSeat},

	ranc_client:send({join,self()},SockPid,Msg),

	{noreply, NewState};

handle_cast({quit,SockPid}, State=#state{seats = Seats}) ->
	%%TODO out_seat
	NewSeat = left_seat(SockPid,Seats),
	erase(SockPid),
	NewState = State#state{seats =NewSeat},
	{noreply,  NewState};



handle_cast({do_movement, SockPid,Movement}, State) ->
	#sock_pid_battle_info{r_times = R_times} = get(SockPid),
	put(SockPid,#sock_pid_battle_info{movement = Movement,lost_tick = 0,r_times = R_times+1}),
	OldReceiveCount = State#state.receive_cycle_count,
	NewReceiveCount =
		case OldReceiveCount <10000 of
			true -> OldReceiveCount +1;
			false ->ok, ticker_check(self()),
							1
		end,

	NewState =State#state{receive_cycle_count = NewReceiveCount},

	{noreply, NewState};


handle_cast({a_player_check,SockPid}, State) ->
	#sock_pid_battle_info{movement = Movement,lost_tick = LostTick,r_times = R_times} = get(SockPid),
	case R_times>3 of
		true ->ranc_client:send(a_player_check_error,SockPid,too_much);
		false -> ok
	end,
	case LostTick >5 of
		true ->
			put(SockPid,#sock_pid_battle_info{movement = 0, lost_tick = LostTick + 1, r_times = 0}),
			case LostTick > 200 of
				true -> ranc_client:send(a_player_check_error,SockPid,afk);
				false -> ok
			end;
		false -> put(SockPid,#sock_pid_battle_info{movement = Movement,lost_tick = LostTick + 1,r_times = 0})
	end,

	{noreply, State};


handle_cast({ticker_check}, State) ->
	Ticker = State#state.ticker,
	case erlang:process_info(Ticker) of
		undefined -> P = self(),
								reboot_ticker(P);
		_Other -> ok
	end,
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
