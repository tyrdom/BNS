%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 27. 十月 2016 10:05
%%%-------------------------------------------------------------------
-module(sp_tcp_ac_sup).
-author("Administrator").

-behaviour(supervisor).

%% API
-export([start_link/1,start_child/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link(Port::integer()) ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(Port) ->
  supervisor:start_link({local, ?SERVER}, ?MODULE, [Port]).


%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================
start_child() ->
  sp_tcp_cl_sup:start_link(),
  supervisor:start_child(?SERVER,[]).
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
  {ok, {SupFlags :: {RestartStrategy :: supervisor:strategy(),
    MaxR :: non_neg_integer(), MaxT :: non_neg_integer()},
    [ChildSpec :: supervisor:child_spec()]
  }} |
  ignore |
  {error, Reason :: term()}).
init([Port]) ->
  BasicSockOpts =[binary,
                  {active,true},
                  {packet,4},
                  {reuseaddr,true}],
  {ok,LSocket} = gen_tcp:listen(Port,BasicSockOpts),
  io:format("listener ok ~n"),

  RestartStrategy = one_for_one,
  MaxRestarts = 5,
  MaxSecondsBetweenRestarts = 10,

  SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

  Restart = permanent,
  Shutdown = 2000,
  Type = worker,

  AChild = {sp_tcp_acceptor, {sp_tcp_acceptor, start_link, [LSocket]},
    Restart, Shutdown, Type, [sp_tcp_acceptor]},


  {ok, {SupFlags, [AChild]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
