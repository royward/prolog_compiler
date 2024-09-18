:- module nqueens_mercury.
:- interface.

:- import_module io.

:- pred main(io::di, io::uo) is det.

:- implementation.

:- import_module list, int.
:- import_module solutions.

% Helper predicate: range(Start, End, List)
% This generates a list of numbers from Start to End.
:- pred range(int::in, int::in, list(int)::out) is det.
range(Start, End, List) :-
    ( if Start > End then
        List = []
    else
        range(Start + 1, End, Rest),
        List = [Start | Rest]
    ).

% Select: select an element from the list.
:- pred selectx(int::out, list(int)::in, list(int)::out) is nondet.
selectx(X, [X | Xs], Xs).
selectx(X, [Y | Ys], [Y | Zs]) :-
    selectx(X, Ys, Zs).

% N-Queens: find the solution for the N-Queens problem.
:- pred nqueens(int::in, list(int)::out) is nondet.
nqueens(N, Qs) :-
    range(1, N, Ns),
    nqueens_aux(Ns, [], Qs).

% Helper predicate for N-Queens.
:- pred nqueens_aux(list(int)::in, list(int)::in, list(int)::out) is nondet.
nqueens_aux([], Qs, Qs).
nqueens_aux(UnplacedQs, SafeQs, Qs) :-
    selectx(Q, UnplacedQs, UnplacedQs1),
    not_attack(Q, 1, SafeQs),
    nqueens_aux(UnplacedQs1, [Q | SafeQs], Qs).

% Check if queens are attacking each other.
:- pred not_attack(int::in, int::in, list(int)::in) is semidet.
not_attack(_, _, []).
not_attack(Q0, D0, [Q | Qs]) :-
    Q0 \= Q,
    Q0 \= D0 + Q,
    Q \= D0 + Q0,
    D1 = D0 + 1,
    not_attack(Q0, D1, Qs).

% Main predicate to run the N-Queens solver and print the result.
main(!IO) :-
    N = 14,  % Change this to solve for other sizes.
    solutions(nqueens(N), Result),
    io.write_list(Result, "\n", write_inner_list, !IO),
    io.nl(!IO).


% Helper predicate to display an inner list of integers
:- pred write_inner_list(list(int)::in, io::di, io::uo) is det.
write_inner_list(List, !IO) :-
    % Write the list of integers, separated by commas, and enclosed in square brackets
    io.write_char('[', !IO),
    io.write_list(List, ",", io.write_int, !IO),
    io.write_char(']', !IO).
