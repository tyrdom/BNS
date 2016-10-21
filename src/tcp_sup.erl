%%%-------------------------------------------------------------------
%% @doc BNS top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(tcp_sup).

-behaviour(supervisor).

%% API
-export([start_link/1, start_child/1]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link(Port) ->
	io:format("tcp sup start link~n"),
	supervisor:start_link({local, ?MODULE}, ?MODULE, [Port]).

start_child(LSock) ->
	io:format("tcp sup start child~n"),
	supervisor:start_child(tcp_client_sup, [LSock]).


%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([tcp_client_sup]) ->
	io:format("tcp sup init client~n"),
	RebootWay =
		{simple_one_for_one, 0, 1},
	Child =
		{tcp_server_handler,
			{tcp_server_handler, start_link, []},
			temporary,
			brutal_kill,
			worker,
			[tcp_server_handler]
		},
	{ok,
		{RebootWay,
			[Child
			]
		}
	};

init([Port]) ->
	io:format("tcp sup init~n"),
	RebootWay={one_for_one, 5, 60},
	Child1=				% client supervisor
	{tcp_client_sup,
		{supervisor, start_link, [{local, tcp_client_sup}, ?MODULE, [tcp_client_sup]]},
		permanent,
		2000,
		supervisor,
		[tcp_server_listener]
	},
	Child2 =
		% tcp listener
	{tcp_server_listener,
		{tcp_server_listener, start_link, [Port]},
		permanent,
		2000,
		worker,
		[tcp_server_listener]
	},
	{ok,
		{RebootWay,
			[Child1
			,Child2
			]
		}
	}.

%%====================================================================
%% Internal functions
%%====================================================================
