-ifndef(ACCOUNTREQ_PB_H).
-define(ACCOUNTREQ_PB_H, true).
-record(accountreq, {
    accountid = erlang:error({required, accountid}),
    password = erlang:error({required, password})
}).
-endif.

-ifndef(ACCOUNTRESP_PB_H).
-define(ACCOUNTRESP_PB_H, true).
-record(accountresp, {
    reply = []
}).
-endif.

-ifndef(ACCOUNTINFOREQ_PB_H).
-define(ACCOUNTINFOREQ_PB_H, true).
-record(accountinforeq, {
    
}).
-endif.

-ifndef(ACCOUNTINFORESP_PB_H).
-define(ACCOUNTINFORESP_PB_H, true).
-record(accountinforesp, {
    account_id = erlang:error({required, account_id}),
    nickname = erlang:error({required, nickname}),
    money = erlang:error({required, money})
}).
-endif.

