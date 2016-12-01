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
-include("base_config.hrl").
-include("other_settings.hrl").
%% API
-export([start_link/3,broadcast/1,stop/1,join_room/3,ticker_check/1,reboot_ticker/1,do_movement/3]).

%% gen_server callbacks
-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {seats, ticker, tick_cycle_count, receive_cycle_count,
								type,ob,rooms_table,
								sock_pid_account_table,allow_players}).


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

join_room(RoomPid,SocketPid,Rank) ->
	gen_server:call(RoomPid,{join,SocketPid,Rank}).
stop(RoomPid) ->
	gen_server:stop(RoomPid).


do_movement(RoomPid, SPid,	AcMsg) ->
	gen_server:cast(RoomPid,{do_movement, SPid,	AcMsg}).
%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link(SPAT::term(),Al::term(),RoT::term()) ->
	{ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(SPAT,Allow_Players,Room_table) ->
	gen_server:start_link(?MODULE, [SPAT,Allow_Players,Room_table], []).


init_seat(0) -> [];

init_seat(N) ->
	[#seat_info{seat = N,sock_pid = empty,rank = 0}] ++ init_seat(N-1).

find_seat([]) -> not_find;

find_seat([#seat_info{seat = Num,sock_pid = empty,rank = 0}|_Q]) -> Num;

find_seat([_SeatInfo|Q]) ->
	find_seat(Q).

sit_seat(Seats,Seat_Info = #seat_info{seat = A_seat}) ->
	lists:keyreplace(A_seat,2,Seats,Seat_Info).

left_seat(Socket_Pid,Seat) ->
	left_seat(Socket_Pid,[],Seat).

left_seat(_Sock_Pid,CheckedSeats,[]) ->
		{CheckedSeats,0};

left_seat(Sock_Pid,CheckedSeats,RestSeats) ->
		[Checking|Rest_Rest_Seats] =RestSeats,
			case Checking of
				#seat_info{sock_pid = Sock_Pid,rank = Rank} ->
					NewSeats = CheckedSeats ++ Rest_Rest_Seats ++ [Checking#seat_info{sock_pid = 0,rank = 0}],
					{NewSeats,Rank};
				_Other ->
					left_seat(Sock_Pid,(CheckedSeats ++ [Checking]),Rest_Rest_Seats)
			end.




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
init([SPAT,Allow_Players,Room_Table]) ->
	Pid = self(),
	Ticker = room_ticker:start_link(Pid),
	Seat =init_seat(?ROOM_MAX),
	{ok, #state{seats = Seat,ticker = Ticker,tick_cycle_count = 0,allow_players = Allow_Players,
							rooms_table = Room_Table,
							receive_cycle_count = 0,type = party,ob = off,
							sock_pid_account_table = SPAT}}.


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

handle_cast({join, SockPid, Rank},  State = #state{seats = Seats, type = Type, ob = Ob,
																							sock_pid_account_table = SPAT ,
																							allow_players = undefined,rooms_table = RTa}) ->
	{Msg,NewSeat} =
	case ets:lookup(SPAT,SockPid) of
		[] -> {error,Seats};
		[{SockPid,SPA = #sock_pid_account_info{special_status = undefined}}] ->
		case Type of
			party -> A_seat = find_seat(Seats),
				case is_integer(A_seat) of

					true -> Room_Pid = self(),
									[{Room_Pid,Room_Info = #room_info{player_num = PNum,average_rank = AR}}] = ets:lookup(RTa,Room_Pid),
									ets:insert(RTa,{Room_Pid,Room_Info#room_info{player_num = PNum + 1,
									average_rank = ((AR * PNum + Rank) /(PNum +1))}}),

									put(SockPid, #sock_pid_battle_info{movement = 0, lost_tick = 0, r_times = 0, seat = A_seat}),
									ets:insert(SPAT,{SockPid,SPA#sock_pid_account_info{special_status = in_battle}}),
									Seat_Info = #seat_info{seat = A_seat,sock_pid = SockPid,rank = Rank},
									{ok, sit_seat(Seats,Seat_Info)};
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

handle_cast({quit,SockPid}, State=#state{seats = Seats,rooms_table = RT}) ->
	%%TODO out_seat
	{NewSeat,Rank} = left_seat(SockPid,Seats),
	erase(SockPid),

	Room_Pid = self(),
	[{Room_Pid,Room_Info = #room_info{player_num = PNum,average_rank = AR}}] = ets:lookup(RT,Room_Pid),

	NewAvgRank =
	case PNum > 1 of
		true ->(AR * PNum - Rank)/(PNum - 1);
		false -> 0
	end,

	ets:insert(RT,{Room_Pid,Room_Info#room_info{player_num = PNum -1 ,average_rank = NewAvgRank}}),

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
	case R_times > 3 of
		true ->ranc_client:send(a_player_check_error,SockPid,too_much);
		false -> ok
	end,
	case LostTick > 5 of
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
