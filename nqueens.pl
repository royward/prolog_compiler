range(M,M,[M]).
range(M,N,[M|Ns]) :- M =\= N, M1 is M+1,range(M1,N,Ns).

selectx(X,[X|Xs],Xs).
selectx(X,[Y|Ys],[Y|Zs]) :- selectx(X,Ys,Zs).

queens(N,Qs) :- range(1,N,Ns),queens_aux(Ns,[],Qs).

queens_aux([],Qs,Qs).
queens_aux(UnplacedQs,SafeQs,Qs) :-
    selectx(Q,UnplacedQs,UnplacedQs1),
    not_attack(Q,1,SafeQs),
    queens_aux(UnplacedQs1,[Q|SafeQs],Qs).

not_attack(_A1,_A2,[]).
not_attack(Q0,D0,[Q|Qs]) :-
    Q0 =\= Q,
    Q0 =\= D0+Q,
    Q =\= D0+Q0,
    D1 is D0+1,
    not_attack(Q0,D1,Qs).

% queens(4,Q).

% time(queens(16,Q)). 
