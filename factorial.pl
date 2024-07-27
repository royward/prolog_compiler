fact(0,1).
fact(N,R) :-
    N =\= 0,
    N1 is N-1,
    fact(N1,R1),
    R is N*R1.

/*
[trace]  ?- fact(1,R).
   Call: (12) fact(1, _10830) ? creep
   Call: (13) 1=\=0 ? creep
   Exit: (13) 1=\=0 ? creep
   Call: (13) _13754 is 1+ -1 ? creep
   Exit: (13) 0 is 1+ -1 ? creep
   Call: (13) fact(0, _15376) ? creep
   Exit: (13) fact(0, 1) ? creep
   Call: (13) _10830 is 1*1 ? creep
   Exit: (13) 1 is 1*1 ? creep
   Exit: (12) fact(1, 1) ? creep
R = 1 .
*/
