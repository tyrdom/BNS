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
-export([start_link/0,md5_string/1,login/4,create/4,check/2,quit/3,get_state/2]).

%% gen_server callbacks
-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-define(SERVER, ?MODULE).

-include("base_config.hrl").
%%%===================================================================
%%% API
%%%===================================================================
get_state(RQPid,RQItem) ->
	gen_server:cast(?SERVER,{get_state,RQItem,RQPid}).

quit(Socket, SPid, Type) ->
	gen_server:cast(?SERVER,{quit,Socket, SPid, Type}).

check(Socket,SPid) ->
	gen_server:cast(?SERVER,{check,Socket,SPid}).

login(Account,Password,Socket,SPid) ->
	gen_server:cast(?SERVER,{login,Account,Password,Socket,SPid}).

create(AccountId,Password,Socket,SPid) ->
	gen_server:cast(?SERVER,{create,AccountId,Password,Socket,SPid}).
%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
	{ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
	gen_server:start_link({local,?SERVER},?MODULE, [], []).

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
	{ok, State :: #bank_state{}} | {ok, State :: #bank_state{}, timeout() | hibernate} |
	{stop, Reason :: term()} | ignore).
init([]) ->
	AccountBank = ets:new(accountBank,[set]),
	Socket_Account_Table = ets:new(sock_account,[set]),%%TODO 多进程读写
	{ok,MySqlPid} = mysql:start_link([{host, ?MYSQL_IP}, {user, ?MYSQL_ID},
		{password, ?MYSQL_PS}, {database, ?MYSQL_DB}]),
	link(MySqlPid),
	zone:start_link(Socket_Account_Table,AccountBank),
	{ok, #bank_state{accountBank = AccountBank, sock_pid_account_table = Socket_Account_Table,mysqlPid = MySqlPid}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
		State :: #bank_state{}) ->
	{reply, Reply :: term(), NewState :: #bank_state{}} |
	{reply, Reply :: term(), NewState :: #bank_state{}, timeout() | hibernate} |
	{noreply, NewState :: #bank_state{}} |
	{noreply, NewState :: #bank_state{}, timeout() | hibernate} |
	{stop, Reason :: term(), Reply :: term(), NewState :: #bank_state{}} |
	{stop, Reason :: term(), NewState :: #bank_state{}}).


handle_call(_Request, _From, State) ->
	{reply, ok, State}.
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #bank_state{}) ->
	{noreply, NewState :: #bank_state{}} |
	{noreply, NewState :: #bank_state{}, timeout() | hibernate} |
	{stop, Reason :: term(), NewState :: #bank_state{}}).

handle_cast({login,Account,Password,Socket, SPid}, State = #bank_state{accountBank = AcBank, sock_pid_account_table = SPid_Ac_Table}) ->

	Pid = State#bank_state.mysqlPid,
	PasswordInDBBin =
		md5_bin_string(Password),
	AccountLogin =#account_login{socket = Socket, sPid = SPid, password_in_db =  PasswordInDBBin},
	Online = ets:lookup(AcBank,Account),
	case Online of
		[]->

			{ok, _ColumnNames, Rows} =
				mysql:query(Pid, <<"SELECT account_id ,password FROM account_auth WHERE account_id = ? ">>, [Account]),
			io:format("in mysql find ~p ~n",[Rows]),

			case Rows of
				[[_Bin_Ac, PasswordInDBBin]] ->


					{ok,Account_Check} = get_account_check_in_DB(Account,Pid),

          ets:insert(AcBank, {Account,#account_info{account_login =  AccountLogin,account_check = Account_Check}}),
					ets:insert(SPid_Ac_Table, {SPid,#sock_pid_account_info{account_id = Account, socket = Socket,special_status = access}}),

					ranc_client:send(login,SPid,Socket,ok);

				[[_Bin_Ac,_Other]] ->
					ranc_client:send(login,SPid,Socket,wrong_ps);


				[]->

					io:format("bank send resp ~n"),
					ranc_client:send(login,SPid,Socket,not_exist)
			end;
		[{Account, #account_login{socket = OldSocket,sPid =  OldSPid,password_in_db =  PasswordInDBBin}}] ->
			ets:delete(SPid_Ac_Table,OldSPid),

			ranc_client:send(error,OldSPid, OldSocket, other),

			{ok,Account_Check} = get_account_check_in_DB(Account,Pid),

			ets:insert(AcBank, {Account,#account_info{account_login =  AccountLogin,account_check = Account_Check}}),
			ets:insert(SPid_Ac_Table, {SPid,#sock_pid_account_info{account_id = Account, socket = Socket,special_status = access}}),

			ranc_client:send(login,SPid,Socket,other);
		[{Account,_Other}] ->
			ranc_client:send(login,SPid,Socket,wrong_ps);
		_Other ->
			ranc_client:send(error,SPid,Socket,unknown)
	end,
	{noreply, State};

handle_cast({check,Socket,SPid},  State = #bank_state{sock_pid_account_table = SPAT,accountBank = ACB}) ->
	[{SPid,#sock_pid_account_info{account_id = Account}}]= ets:lookup(SPAT,SPid),
	[{Account,#account_info{account_check = #account_check{nickname = Nickname,gold = Gold}}}] = ets:lookup(ACB,Account),
	ranc_client:send(check,SPid,Socket,{Nickname,Gold}),
	{noreply, State};

%创建账号
handle_cast({create,AccountId,Password,Socket, SPid}, State) ->

	Pid = State#bank_state.mysqlPid,

	PasswordInDB =md5_string(Password),
	{ok, _ColumnNames, Rows} =
		mysql:query(Pid, <<"SELECT account_id FROM account_auth WHERE account_id = ?">>, [AccountId]),

	case Rows of
		[_] ->

			ranc_client:send(create,SPid,Socket,same);

		[] ->
     ok = init_account_in_DB(AccountId, PasswordInDB,Pid),

			ranc_client:send(create,SPid,Socket,ok)
	end,
	{noreply, State};

handle_cast({quit,Socket, SPid, Type}, State = #bank_state{sock_pid_account_table = SAT,accountBank = ACBank}) ->
  case ets:lookup(SAT, Socket) of
    [{Socket, AccountId}] -> ets:delete(ACBank, AccountId);
    [] -> io:format("ets waring : bank table not match ~n"),
      AcList = ets:match(ACBank, {'$1', #account_info{
        account_login = #account_login{socket = Socket,
          sPid = '_', password_in_db = '_'},
        account_check = '_'}}),
      F = fun([Account]) -> ets:delete(ACBank, Account) end,
      lists:map(F, AcList)
  end,
  ets:delete(SAT, Socket),

  case Type of
    exception -> ok;
    _ ->
      ranc_client:send(quit, SPid, Socket, ok)
  end,
	{noreply, State};


handle_cast({get_state,sock_pid_account_table,RQPid}, State) ->
	Reply =  State#bank_state.sock_pid_account_table,
	RQPid ! {sock_pid_account_table, Reply},
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
-spec(handle_info(Info :: timeout() | term(), State :: #bank_state{}) ->
	{noreply, NewState :: #bank_state{}} |
	{noreply, NewState :: #bank_state{}, timeout() | hibernate} |
	{stop, Reason :: term(), NewState :: #bank_state{}}).
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
		State :: #bank_state{}) -> term()).
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
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #bank_state{},
		Extra :: term()) ->
	{ok, NewState :: #bank_state{}} | {error, Reason :: term()}).
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

hex(X) -> $C + X.



get_account_check_in_DB(Account,Pid) ->
	{ok, _ColumnNames, Rows} =
		mysql:query(Pid, <<"SELECT nickname,gold FROM account_info WHERE account_id = ? ">>, [Account]),
	case Rows of

		[[Nickname,Gold,Rank]] ->
		#account_check{nickname = Nickname,gold = Gold};
		_Other ->
			ok = mysql:query(Pid, "INSERT INTO account_info (account_id, gold) VALUES (?, ?)", [Account, 0]),

			#account_check{nickname = <<"nick">> ,gold = 0}
	end.

init_account_in_DB(AccountId, PasswordInDB,Pid) ->
  ok = mysql:query(Pid, "INSERT INTO account_auth (account_id, password) VALUES (?, ?)", [AccountId, PasswordInDB]),
  ok = mysql:query(Pid, "INSERT INTO account_info (account_id, gold) VALUES (?, ?)", [AccountId, 0]),
  ok.