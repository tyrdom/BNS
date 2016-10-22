-ifndef(PERSON_PB_H).
-define(PERSON_PB_H, true).
-record(person, {
    age = erlang:error({required, age}),
    name = erlang:error({required, name})
}).
-endif.

-ifndef(FAMILY_PB_H).
-define(FAMILY_PB_H, true).
-record(family, {
    person = []
}).
-endif.

