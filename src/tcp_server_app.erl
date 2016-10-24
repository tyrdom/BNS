-module(tcp_server_app).
%-behaviour(application).
-export([start/1, stop/1]).


start(PORT) -> %tcp_server_app:start().
  io:format("tcp app start~n"),
  case tcp_server_sup:start_link(PORT) of
    {ok, Pid} ->
      {ok, Pid};
    Other ->
      {error, Other}
  end.

stop(_S) ->
  ok.
