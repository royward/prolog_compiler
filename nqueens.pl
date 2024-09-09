range(M,M,[M]).
range(M,N,[M|Ns]) :- M =\= N, M1 is M+1,range(M1,N,Ns).

selectx(X,[X|Xs],Xs).
selectx(X,[Y|Ys],[Y|Zs]) :- selectx(X,Ys,Zs).

nqueens(N,Qs) :- range(1,N,Ns),nqueens_aux(Ns,[],Qs).

nqueens_aux([],Qs,Qs).
nqueens_aux(UnplacedQs,SafeQs,Qs) :-
    selectx(Q,UnplacedQs,UnplacedQs1),
    not_attack(Q,1,SafeQs),
    nqueens_aux(UnplacedQs1,[Q|SafeQs],Qs).

not_attack(_A1,_A2,[]).
not_attack(Q0,D0,[Q|Qs]) :-
    Q0 =\= Q,
    Q0 =\= D0+Q,
    Q =\= D0+Q0,
    D1 is D0+1,
    not_attack(Q0,D1,Qs).

% nqueens(4,Q).

% time(nqueens(16,Q)).
