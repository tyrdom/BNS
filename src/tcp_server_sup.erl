-module(tcp_server_sup).
-behaviour(supervisor).
-export([start_link/1, start_child/1]).
-export([init/1]).

start_link(Port) ->
  io:format("tcp sup start link~n"),
  supervisor:start_link({local, ?MODULE}, ?MODULE, [Port]).

start_child(LSock) ->
  io:format("tcp sup start child~n"),
  supervisor:start_child(tcp_client_sup, [LSock]).

init([tcp_client_sup]) ->
  io:format("tcp sup init client~n"),
  {ok,
   { {simple_one_for_one, 0, 1},
    [
     { tcp_server_handler, 
      {tcp_server_handler, start_link, []},
      temporary, 
      brutal_kill, 
      worker, 
      [tcp_server_handler]
     }
    ]
   }
  };

init([Port]) ->
  io:format("tcp sup init~n"),
  {ok,
    { {one_for_one, 5, 60},
     [
      % client supervisor
      { tcp_client_sup, 
       {supervisor, start_link, [{local, tcp_client_sup}, ?MODULE, [tcp_client_sup]]},
        permanent, 
        2000, 
        supervisor, 
        [tcp_server_listener]
       },
     % tcp listener
     { tcp_server_listener, 
      {tcp_server_listener, start_link, [Port]},
      permanent, 
      2000, 
      worker, 
      [tcp_server_listener]
     }
    ]
   }
  }.