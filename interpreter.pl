% BSD 3-Clause License
%
% Copyright (c) 2024, Roy Ward
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
% 1. Redistributions of source code must retain the above copyright notice, this
%    list of conditions and the following disclaimer.
%
% 2. Redistributions in binary form must reproduce the above copyright notice,
%    this list of conditions and the following disclaimer in the documentation
%    and/or other materials provided with the distribution.
%
% 3. Neither the name of the copyright holder nor the names of its
%    contributors may be used to endorse or promote products derived from
%    this software without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
% DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
% FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
% DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
% CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
% OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

:- consult('../plammar/pack.pl').
:- use_module(library(plammar)).
:- use_module(library(plammar/environments)).
:- use_module(library(cli_table)).

/*
interpret(file("append.pl"),string("append([1],[],X)."),Results).
interpret(file("append.pl"),string("append([1,2],[3],X)."),Results).
interpret(file("append.pl"),string("append(X,Y,[1,2,3])."),Results).
interpret(file("append.pl"),string("append(X,[3],[1,2,3])."),Results).
interpret(file("factorial.pl"),string("fact(6,R)."),Results).
interpret(file("fibonacci.pl"),string("fib(8,R)."),Results).
interpret(file("nqueens.pl"),string("range(1,4,X)."),Results).
interpret(file("nqueens.pl"),string("selectx(X,[1,2,3,4],R)."),Results).
interpret(file("nqueens.pl"),string("queens(1,Q)."),Results).
interpret(file("nqueens.pl"),string("queens(4,Q)."),Results).
interpret(file("nqueens.pl"),string("queens(8,Q)."),Results).
*/

interpret(RawProgram,RawGoal,Results) :-
    convert_program(RawProgram,Pdict,Program),
    convert_input(RawGoal,Name,Goal,InputDict),
    get_index_dict(Name,InitClause,Pdict,_),
    length(InputDict,I1),
    run_program(Program,InitClause,Goal,I1,[],Sub),
    get_results(InputDict,0,Sub,Results).

get_results([],_,_,[]).
get_results([Dh|Dt],N,Sub,[assign(Dh,V)|R1]) :-
    usubstitute(Sub,v(N),V),
    N1 is N+1,
    get_results(Dt,N1,Sub,R1).

run_program(Program,InitClause,Goal,Nmax,Sub,Subn) :-
    nth0(InitClause,Program,Clause),
    run_program_aux(Program,Clause,Goal,Nmax,_,Sub,Subn).

run_program_aux(Program,[clause(Cdict,Args,Body)|_],Goal,Nmax1,Nmax2,Sub1,Sub3) :-
    maplist(var_add(Nmax1),Args,Args2),
    maplist(var_add(Nmax1),Body,Body2),
    map_fold1(unify,Goal,Args2,Sub1,Sub2),
    maplist(usubstitute(Sub2),Body2,Body3),
    length(Cdict,Csize),
    NewNmax is Csize+Nmax1,
    fold2(run_program_aux2(Program),Body3,NewNmax,Nmax2,Sub2,Sub3).
run_program_aux(Program,[_|Tclause],Goal,Nmax1,Nmax2,Sub1,Sub2) :-
    run_program_aux(Program,Tclause,Goal,Nmax1,Nmax2,Sub1,Sub2).

run_program_aux2(Program,fcall(Index,Args),Nmax1,Nmax2,Sub1,Sub2) :-
    nth0(Index,Program,Clause),
    maplist(usubstitute(Sub1),Args,Args2),
    run_program_aux(Program,Clause,Args2,Nmax1,Nmax2,Sub1,Sub2).
run_program_aux2(_,function(test_neq,A1,A2),Nmax,Nmax,Sub,Sub) :-
    eval_expression(Sub,A1,i(E1)),
    eval_expression(Sub,A2,i(E2)),
    E1=\=E2.
run_program_aux2(_,function(assign,v(V),A),Nmax,Nmax,Sub1,[subst(V,E)|Sub2]) :-
    eval_expression(Sub1,A,E),
    usubsub0(V,E,Sub1,Sub2).

eval_expression(_,i(X),i(X)).
eval_expression([subst(V,X)|_],v(V),X).
eval_expression([subst(V,_)|T],v(W),X) :- V=\=W,eval_expression(T,v(W),X).
eval_expression(Sh,function(add,A1,A2),i(In)) :-
    eval_expression(Sh,A1,i(I1)),
    eval_expression(Sh,A2,i(I2)),
    In is I1+I2.
eval_expression(Sh,function(sub,A1,A2),i(In)) :-
    eval_expression(Sh,A1,i(I1)),
    eval_expression(Sh,A2,i(I2)),
    In is I1-I2.
eval_expression(Sh,function(times,A1,A2),i(In)) :-
    eval_expression(Sh,A1,i(I1)),
    eval_expression(Sh,A2,i(I2)),
    In is I1*I2.

% This has way more cut statements than I would like
unify(eol,eol,S,S).
unify(i(V),i(V),S,S).
unify(v(V),v(V),S,S).
unify(v(V),X1,S1,[subst(V,X2)|S2]) :-
    X1\==v(V), !,
    unot_occurs(V,X1),
    usubstitute(S1,X1,X2),
    usubsub0(V,X2,S1,S2).
unify(X1,v(V),S1,[subst(V,X2)|S2]) :-
    X1\==v(_),
    unot_occurs(V,X1),
    usubstitute(S1,X1,X2),
    usubsub0(V,X2,S1,S2).
unify(list(H1,T1),list(H2,T2),S1,S3) :-
    unify(H1,H2,S1,S2),
    usubstitute(Sh,T1,W1),
    usubstitute(Sh,T2,W2), !,
    unify(W1,W2,S2,S3).

unot_occurs(V,v(W)) :- V\==W.
unot_occurs(_,i(_)).
unot_occurs(_,eol).
unot_occurs(V,list(H,T)) :- unot_occurs(V,H),unot_occurs(V,T).

usubstitute(Sh,v(V),X) :- usubstitute1(Sh,V,X).
usubstitute(_,i(V),i(V)).
usubstitute(_,eol,eol).
usubstitute(Sh,list(H1,T1),list(H2,T2)) :- usubstitute(Sh,H1,H2),usubstitute(Sh,T1,T2).
usubstitute(Sh,fcall(N,Args),fcall(N,Args2)) :- maplist(usubstitute(Sh),Args,Args2).
usubstitute(Sh,function(Op,X1,Y1),function(Op,X2,Y2)) :- usubstitute(Sh,X1,X2),usubstitute(Sh,Y1,Y2).

usubstitute1([],V,v(V)).
usubstitute1([subst(V,X)|_],V,X).
usubstitute1([subst(W,_)|T],V1,V2) :- W=\=V1,usubstitute1(T,V1,V2).

usubsub0(_,_,[],[]).
usubsub0(V,X,[subst(V,X)|T1],T2) :- usubsub0(V,X,T1,T2).
usubsub0(V,X,[subst(V1,X1)|T1],[subst(V1,X2)|T2]) :- V\==V1,usubsub(V,X,X1,X2),usubsub0(V,X,T1,T2).

usubsub(V,X,v(V),X).
usubsub(V,_,v(W),v(W)) :- W\==V.
usubsub(_,_,i(V),i(V)).
usubsub(_,_,eol,eol).
usubsub(V,X,list(H1,T1),list(H2,T2)) :- usubsub(V,X,H1,H2),usubsub(V,X,T1,T2).
usubsub(V,X,fcall(N,Args),fcall(N,Args2)) :- map(usubsub(V,X),Args,Args2).
usubsub(V,X,function(Op,X1,Y1),function(Op,X2,Y2)) :- usubsub(V,X,X1,X2),usubsub(V,X,Y1,Y2).

var_add(N,v(V),v(V2)) :- V2 is V+N.
var_add(_,i(V),i(V)).
var_add(_,eol,eol).
var_add(N,list(H1,T1),list(H2,T2)) :- var_add(N,H1,H2),var_add(N,T1,T2).
var_add(N,fcall(M,Args),fcall(M,Args2)) :- maplist(var_add(N),Args,Args2).
var_add(N,function(Op,X1,Y1),function(Op,X2,Y2)) :- var_add(N,X1,X2),var_add(N,Y1,Y2).
