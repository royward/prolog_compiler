# BSD 3-Clause License
#
# Copyright (c) 2024, Roy Ward
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

:- consult('../plammar/pack.pl').
:- use_module(library(plammar)).
:- use_module(library(plammar/environments)).
:- use_module(library(cli_table)).

/*
convert_program(file("nqueens.pl"),PDict,Rform),print(PDict),nl,nl,print(Rform),nl,nl.
convert_program(file("append.pl"),PDict,Rform),print(PDict),nl,nl,print(Rform),nl,nl.
convert_program(file("selectx.pl"),PDict,Rform),print(PDict),nl,nl,print(Rform),nl,nl.
convert_input(string("append([1,2,3],[3],X)."),Name,Args,Dict).
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
    get_index_dict(Name,InitClause,Pdict,_,_),
    length(InputDict,I1),
    run_program(Program,InitClause,Goal,I1,[],Sub),
    get_results(InputDict,0,Sub,Results).

get_results([],_,_,[]).
get_results([Dh|Dt],N,Sub,[assign(Dh,V)|R1]) :-
    usubstitute(Sub,v(N),V),
    N1 is N+1,
    get_results(Dt,N1,Sub,R1).
    
convert_program(X,PDict,Rform) :- prolog_ast(X,prolog(AST)),convert_ast_to_rform(AST,prog(PDict,Rform)).

get_index_dict(N,V,PDictIn,PDictOut,Rep) :- get_index_dict_aux(N,0,V,PDictIn,PDictOut,Rep).

get_index_dict_aux(N,I,I,[],[N],false).
get_index_dict_aux(N,I,I,[N|T],[N|T],true).
get_index_dict_aux(N,I,V,[X|T1],[X|T2],Rep) :-
    N \== X,
    I1 is I+1,
    get_index_dict_aux(N,I1,V,T1,T2,Rep).

append_to_nth(0,V,[],[[V]]).
append_to_nth(0,V,[H1|T],[H2|T]) :- append(H1,[V],H2).
append_to_nth(N,V,[],[[]|T]) :- N>0,N1 is N-1,append_to_nth(N1,V,[],T).
append_to_nth(N,V,[H|T1],[H|T2]) :-  N>0,N1 is N-1,append_to_nth(N1,V,T1,T2).

% map_fold1(Pred,ListIn,Listout,AccIn,AccOut).
map_fold1(_,[],[],A,A).
map_fold1(Pred,[X|Xt],[Y|Yt],A1,A3) :- call(Pred,X,Y,A1,A2),map_fold1(Pred,Xt,Yt,A2,A3).

% map_fold2(Pred,ListIn,Listout,AccIn,AccOut,BccIn,BccOut).
map_fold2(_,[],[],A,A,B,B).
map_fold2(Pred,[X|Xs],[Y|Ys],A1,A3,B1,B3) :- call(Pred,X,Y,A1,A2,B1,B2),map_fold2(Pred,Xs,Ys,A2,A3,B2,B3).

% fold2(Pred,ListIn,AccIn,AccOut,BccIn,BccOut).
fold2(_,[],A,A,B,B).
fold2(Pred,[X|Xs],A1,A3,B1,B3) :- call(Pred,X,A1,A2,B1,B2),fold2(Pred,Xs,A2,A3,B2,B3).

convert_ast_to_rform(AST,Program) :- foldl(convert_ast_to_rform_one,AST,prog([],[]),Program).

% For simplicity, I treat a fact as a rule with no body. I lose a little bit of performance that way in the interpreter, but simpler code
convert_ast_to_rform_one(fact(compound(atom(Name),Args)),prog(PDict1,C1),prog(PDict3,C2)) :-
    length(Args,La),get_index_dict(f(Name,La),Index,PDict1,PDict2,_),
    process_args_body(Args,[],[NormArgs,NormBody],VDict,PDict2,PDict3,VRep),
    append_to_nth(Index,clause(VDict,VRep,NormArgs,NormBody),C1,C2).
convert_ast_to_rform_one(rule(compound(atom(Name),Args),Body),prog(PDict1,C1),prog(PDict3,C2)) :-
    length(Args,La),get_index_dict(f(Name,La),Index,PDict1,PDict2,_),
    process_args_body(Args,Body,[NormArgs,NormBody],VDict,PDict2,PDict3,VRep),
    append_to_nth(Index,clause(VDict,VRep,NormArgs,NormBody),C1,C2).
    
process_args_body(Args,Body,[ProcessedArgs,ProcessedBody],VDict2,PDict1,PDict2,VRep) :-
    map_fold2(process_args_one,Args,ProcessedArgs,[],VDict1,[],VRep),
    map_fold2(process_body_one,Body,ProcessedBody,VDict1,VDict2,PDict1,PDict2).

process_args_one(variable(M),v(V),VDict1,VDict2,VRep1,VRep2) :-
    get_index_dict(M,V,VDict1,VDict2,Rep),
    (Rep -> VRep2=[V|VRep1] ; VRep2=VRep1).
process_args_one(anonymous,anonymous,VDict,VDict,VRep,VRep).
process_args_one(eol,eol,VDict,VDict,VRep,VRep).
process_args_one(integer(N),i(N),VDict,VDict,VRep,VRep).
process_args_one(list([],X1),X2,VDict1,VDict2,VRep1,VRep2) :- process_args_one(X1,X2,VDict1,VDict2,VRep1,VRep2).
process_args_one(list([H1|T1],X),list(H2,T2),VDict1,VDict3,VRep1,VRep3) :-
    process_args_one(H1,H2,VDict1,VDict2,VRep1,VRep2),
    process_args_one(list(T1,X),T2,VDict2,VDict3,VRep2,VRep3).

process_body_one(variable(M),v(V),VDict1,VDict2,PDict,PDict) :- get_index_dict(M,V,VDict1,VDict2,_).
process_body_one(anonymous,anonymous,VDict,VDict,PDict,PDict).
process_body_one(eol,eol,VDict,VDict,PDict,PDict).
process_body_one(integer(N),i(N),VDict,VDict,PDict,PDict).
process_body_one(list([],X1),X2,VDict1,VDict2,PDict1,PDict2) :- process_body_one(X1,X2,VDict1,VDict2,PDict1,PDict2).
process_body_one(list([H1|T1],X),list(H2,T2),VDict1,VDict3,PDict1,PDict3) :-
    process_body_one(H1,H2,VDict1,VDict2,PDict1,PDict2),
    process_body_one(list(T1,X),T2,VDict2,VDict3,PDict2,PDict3).
process_body_one(infix(Op,_,Fa1,Fb1),function(Op2,Fa2,Fb2),VDictIn,VDictOut,PDictIn,PDictOut) :-
    process_convert_op(Op,Op2),
    process_body_one(Fa1,Fa2,VDictIn,VDictInt,PDictIn,PDictInt),
    process_body_one(Fb1,Fb2,VDictInt,VDictOut,PDictInt,PDictOut).
process_body_one(compound(atom(Name),Args),fcall(Index,ProcessedArgs),VDict1,VDict2,PDict1,PDict3) :-
    length(Args,La),get_index_dict(f(Name,La),Index,PDict1,PDict2,_),
    map_fold2(process_body_one,Args,ProcessedArgs,VDict1,VDict2,PDict2,PDict3).

process_convert_op(=\=,test_neq).
process_convert_op(is,assign).
process_convert_op(+,add).
process_convert_op(-,sub).
process_convert_op(*,times).

convert_input(X,f(Name,La),Args,Dict) :-
    prolog_ast(X,prolog([fact(compound(atom(Name),RawArgs))])),
    length(RawArgs,La),
    map_fold2(process_args_one,RawArgs,Args,[],Dict,[],_).

run_program(Program,InitClause,Goal,Nmax,Sub,Subn) :-
    nth0(InitClause,Program,Clause),
    run_program_aux(Program,Clause,Goal,Nmax,_,Sub,Subn).

run_program_aux(Program,[clause(Cdict,_,Args,Body)|_],Goal,Nmax1,Nmax2,Sub1,Sub3) :-
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
