-ifndef(ACCOUNTCREATEREQ_PB_H).
-define(ACCOUNTCREATEREQ_PB_H, true).
-record(accountcreatereq, {
    accountid = erlang:error({required, accountid}),
    password = erlang:error({required, password})
}).
-endif.

-ifndef(ACCOUNTCREATERESP_PB_H).
-define(ACCOUNTCREATERESP_PB_H, true).
-record(accountcreateresp, {
    reply = []
}).
-endif.

-ifndef(ACCOUNTLOGINREQ_PB_H).
-define(ACCOUNTLOGINREQ_PB_H, true).
-record(accountloginreq, {
    accountid = erlang:error({required, accountid}),
    password = erlang:error({required, password})
}).
-endif.

-ifndef(ACCOUNTLOGINRESP_PB_H).
-define(ACCOUNTLOGINRESP_PB_H, true).
-record(accountloginresp, {
    reply = []
}).
-endif.

-ifndef(ACCOUNTCHECKMONEYREQ_PB_H).
-define(ACCOUNTCHECKMONEYREQ_PB_H, true).
-record(accountcheckmoneyreq, {
    
}).
-endif.

-ifndef(ACCOUNTCHECKMONEYRESP_PB_H).
-define(ACCOUNTCHECKMONEYRESP_PB_H, true).
-record(accountcheckmoneyresp, {
    account_id = erlang:error({required, account_id}),
    nickname = erlang:error({required, nickname}),
    money = erlang:error({required, money})
}).
-endif.

