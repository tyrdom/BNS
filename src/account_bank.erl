%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%% Use SqlDB
%%% @end
%%% Created : 21. 十月 2016 13:53
%%%-------------------------------------------------------------------
-module(account_bank).
-author("Administrator").

-behaviour(gen_server).

-include("net_settings.hrl").
%% API
-export([start_link/0,md5_string/1,login/4,create/4]).

%% gen_server callbacks
-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-define(SERVER, ?MODULE).
-record(state, {accountBank,infoBank,mysqlPid,zonePid}).

-record(accountlogin, { socket ,sPid , password_in_db
}).
-record(accountcheck,{
	account_id,
	nickname,
	gold
	}).
%%%===================================================================
%%% API
%%%===================================================================
login(Account,Password,Socket,SPid) ->
	gen_server:call(?SERVER,{login,Account,Password,Socket,SPid}).

create(AccountId,Password,Socket,SPid) ->
	gen_server:call(?SERVER,{create,AccountId,Password,Socket,SPid}).
%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
	{ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
	gen_server:start_link(?MODULE, [], []).

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
	AccountBank = ets:new(accountBank,[set]),
	InfoBank = ets:new(infoBank,[set]),
	{ok,MySqlPid} = mysql:start_link([{host, ?MYSQL_IP}, {user, ?MYSQL_ID},
		{password, ?MYSQL_PS}, {database, ?MYSQL_DB}]),
	link(MySqlPid),
	{ok,ZonePid} = zone:start_link(),
	{ok, #state{accountBank = AccountBank,infoBank = InfoBank,mysqlPid = MySqlPid,zonePid = ZonePid}}.

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

handle_cast({login,Account,Password,Socket, SPid}, State = #state{accountBank = AcBank, infoBank = InBank}) ->

	Pid = State#state.mysqlPid,
	PasswordInDBBin =
		md5_bin_string(Password),
	AccountLogin =#accountlogin{socket = Socket,sPid =  SPid,password_in_db =  PasswordInDBBin},
	Online = ets:lookup(AcBank,Account),
	case Online of
		[]->

			{ok, _ColumnNames, Rows} =
				mysql:query(Pid, <<"SELECT account_id ,password FROM account_auth WHERE account_id = ? ">>, [Account]),
			io:format("in mysql find ~p ~n",[Rows]),

			case Rows of
				[[_Bin_Ac, PasswordInDBBin]] ->

					ets:insert(AcBank, {Account, AccountLogin}),
					{ok,Account_Info} = get_account_info_in_DB(Account,Pid),
					ets:insert(InBank,{Socket,Account_Info}),
			%	TODO	zone:inZone(Account,Socket, SPid),
%%			            CMDCode = <<4>>,
%%									Resp = {accountloginresp,1},
%%              io:format("bank send resp ~n"),
					ranc_client:send(SPid,Socket,login,ok);
				%TODO In startzone
				[[_Bin_Ac,_Other]] ->
					ranc_client:send(SPid,Socket,login,wrong_ps);


				[]->
%%              CMDCode = <<4>>,
%%              Resp = {accountloginresp,2},
					io:format("bank send resp ~n"),
					ranc_client:send(SPid,Socket,login,not_exist)
			end;
		[{Account, #accountlogin{socket = OldSocket,sPid =  OldSPid,password_in_db =  PasswordInDBBin}}] ->
			ets:delete(InBank,OldSocket),

			ranc_client:send(OldSPid, OldSocket, error, other),

			ets:insert(AcBank,{Account,AccountLogin}),

			{ok,Account_Info} = get_account_info_in_DB(Account,Pid),

			ets:insert(InBank,{Socket,Account_Info}),

			ranc_client:send(SPid,Socket,login,other);
		[{Account,_Other}] ->
			ranc_client:send(SPid,Socket,login,wrong_ps);
		_Other ->
			ranc_client:send(SPid,Socket,error,unknown)
	end,
	{noreply, State};

handle_cast({check,Socket,SPid},  State = #state{infoBank = InBank}) ->
	[{Socket,#accountcheck{nickname = Nickname,gold = Gold}}] = ets:lookup(InBank,Socket),
	ranc_client:send(SPid,Socket,check,{Nickname,Gold}),
	{noreply, State};


handle_cast({create,AccountId,Password,Socket, SPid}, State) ->

	Pid = State#state.mysqlPid,

	PasswordInDB =md5_string(Password),
	{ok, _ColumnNames, Rows} =
		mysql:query(Pid, <<"SELECT account_id FROM account_auth WHERE account_id = ?">>, [AccountId]),

	case Rows of
		[_] ->

			ranc_client:send(SPid,Socket,create,same);

		[] ->
			ok = mysql:query(Pid, "INSERT INTO account_auth (account_id, password) VALUES (?, ?)", [AccountId, PasswordInDB]),
			ok = mysql:query(Pid, "INSERT INTO account_info (account_id, gold) VALUES (?, ?)", [AccountId, 0]),

			ranc_client:send(SPid,Socket,create,ok)
	end,
	{noreply, State};

handle_cast({quit,Socket, SPid}, State = #state{infoBank = IFBank ,accountBank = ACBank}) ->
		case ets:lookup(IFBank,Socket) of
			[{Socket,#accountcheck{account_id = AccountId}}] -> ets:delete(ACBank,AccountId);
			[] ->
				AcList =	ets:match(ACBank , {'$1',#accountlogin{socket = Socket,sPid = '_',password_in_db = '_'}}),
				F = fun([Account]) -> ets:delete(ACBank,Account) end,
				lists:map(F,AcList)
		end,
		ets:delete(IFBank,Socket),
		ranc_client:send(SPid,Socket,quit,ok),
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
md5_bin_string(String) ->
	list_to_binary(md5_string(String)).

md5_string(String) ->
list_to_hex(binary_to_list(erlang:md5(String))).

list_to_hex(List) -> lists:map(fun(X) ->int_to_hex(X) end ,List).

int_to_hex(X) when X < 256 -> [hex(X div 16),hex(X rem 16)].

hex(X) -> $C+X.



get_account_info_in_DB (Account,Pid) ->
	{ok, _ColumnNames, Rows} =
		mysql:query(Pid, <<"SELECT nickname,gold FROM account_info WHERE account_id = ? ">>, [Account]),
	case Rows of

		[[Nickname,Gold]] ->
		#accountcheck{account_id = Account, nickname = Nickname,gold = Gold};
		_Other ->
			ok = mysql:query(Pid, "INSERT INTO account_info (account_id, gold) VALUES (?, ?)", [Account, 0]),

			#accountcheck{account_id = Account, nickname = <<"nick">> ,gold = 0}
	end.

