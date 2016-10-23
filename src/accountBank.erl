%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%% Use SqlDB
%%% @end
%%% Created : 21. 十月 2016 13:53
%%%-------------------------------------------------------------------
-module(accountBank).
-author("Administrator").

-behaviour(gen_server).

-include("net_settings.hrl").
%% API
-export([start_link/0,md5_string/1,login/4]).

%% gen_server callbacks
-export([init/1,
	handle_call/3,
	handle_cast/2,
	handle_info/2,
	terminate/2,
	code_change/3]).

-define(SERVER, ?MODULE).
-record(state, {etsTempBank,mysqlPid}).


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
	TempBank = ets:new(tempBank,[set]),
	{ok,MySqlPid} = mysql:start_link([{host, ?MYSQL_IP}, {user, ?MYSQL_ID},
		{password, ?MYSQL_PS}, {database, ?MYSQL_DB}]),
	{ok, #state{etsTempBank = TempBank,mysqlPid = MySqlPid}}.

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

handle_call({login,Account,Password,Socket,Spid}, _From, State) ->
	TempBank = State#state.etsTempBank,
	Pid = State#state.mysqlPid,
	PasswordInDB =md5_string(Password),

	{ok, _ColumnNames, Rows} =
		mysql:query(Pid, <<"SELECT accountId FROM account_auth WHERE accountId = ? AND password= ?">>, [Account,PasswordInDB]),


	Reply = case Rows of
		        _ -> ets:insert(TempBank,{Socket,Spid,Account}),
			            CMDCode = <<4>>,
			            Resp = 1,
									Spid!{Socket,CMDCode,Resp},
			        %TODO In startzone

			        access;
		        []->dy
	        end,
	{Reply, ok, State};


handle_call({checkmoney,Socket}, _From, State) ->
	TempBank = State#state.etsTempBank,
	ets:lookup(TempBank,Socket),
	{reply, ok, State};


handle_call({checkItem,Socket}, _From, State) ->
	TempBank = State#state.etsTempBank,
	ets:lookup(TempBank,Socket),
	{reply, ok, State};


handle_call({updata,Socket,MoneyData}, _From, State) ->
	TempBank = State#state.etsTempBank,
	ets:lookup(TempBank,Socket),
	%TODO check_account_money


	{reply, ok, State};


handle_call({create,AccountId,Password,Socket,Spid}, _From, State) ->

	Pid = State#state.mysqlPid,
	%TODO create account!
	PasswordInDB =md5_string(Password),
	{ok, _ColumnNames, Rows} =
		mysql:query(Pid, <<"SELECT accountId FROM account_auth WHERE accountId = ?">>, [AccountId]),

	case Rows of
		  _ -> no_no_no ,
			  Spid!{Socket };
		 [] ->	mysql:query(Pid, "INSERT INTO account_auth (account_id, password) VALUES (?, ?)", [AccountId, PasswordInDB]),
			  ok
	end,

	{reply, ok, State};

handle_call(_Request, _From, State) ->
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


md5_string(String) ->
	list_to_hex(binary_to_list(erlang:md5(String))).

list_to_hex(List) -> lists:map(fun(X) ->int_to_hex(X) end ,List).

int_to_hex(X) when X < 256 -> [hex(X div 16),hex(X rem 16)].

hex(X) -> $C+X.


%handle_call({login,Account,Password,Socket,Spid}, _From, State)
login(Account,Password,Socket,Spid)->
	gen_server:call(?SERVER,({login,Account,Password,Socket,Spid}),ok.
create(AccountId,Password,Socket,Spid) -> gen_server:call(?SERVER,({create,AccountId,Password,Socket,Spid}),ok.
