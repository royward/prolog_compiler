:- consult('../plammar/pack.pl').
:- use_module(library(plammar)).
:- use_module(library(plammar/environments)).
:- use_module(library(cli_table)).

% convert_program(file("nqueens.pl"),PredDict,Rform),print(PredDict),nl,nl,print(Rform),nl,nl.
% convert_program(file("append.pl"),PredDict,Rform),print(PredDict),nl,nl,print(Rform),nl,nl.
% convert_input(string("append([1,2,3],[3],X)."),Name,Args,Dict).
% interpret(file("append.pl"),string("append([1,2],[3],X)."),Results).
% interpret(file("append.pl"),string("append([1,2],[3],X)."),Results).
% interpret(file("append.pl"),string("append(X,Y,[1,2,3])."),Results).
% interpret(file("append.pl"),string("append(X,[3],[1,2,3])."),Results).

interpret(RawProgram,RawGoal,Results) :-
    convert_program(RawProgram,Pdict,Program),
    convert_input(RawGoal,Name,Goal,InputDict),
    get_index_dict(Name,InitClause,Pdict,_),
    length(InputDict,I1),
    run_program(Program,InitClause,Goal,I1,[],Sub),
    get_results(InputDict,0,Sub,Results).

get_results([],_,_,[]).
get_results([Dh|Dt],N,Sub,[assign(Dh,V),R1]) :-
    usubstitute(Sub,v(N),V),
    N1 is N+1,
    get_results(Dt,N1,Sub,R1).
    
convert_program(X,PredDict,Rform) :- prolog_ast(X,prolog(AST)),convert_ast_to_rform(AST,prog(PredDict,Rform)).

get_index_dict(N,V,PredDictIn,PredDictOut) :- get_index_dict_aux(N,0,V,PredDictIn,PredDictOut).

get_index_dict_aux(N,I,I,[],[N]).
get_index_dict_aux(N,I,I,[N|T],[N|T]).
get_index_dict_aux(N,I,V,[X|Tin],[X|Tout]) :-
    N \== X,
    I1 is I+1,
    get_index_dict_aux(N,I1,V,Tin,Tout).

append_to_nth(0,V,[],[[V]]).
append_to_nth(0,V,[H0|T],[H1|T]) :- append(H0,[V],H1).
append_to_nth(N,V,[],[[]|T]) :- N>0,N1 is N-1,append_to_nth(N1,V,[],T).
append_to_nth(N,V,[H|T0],[H|T1]) :-  N>0,N1 is N-1,append_to_nth(N1,V,T0,T1).

% map_fold1(Pred,ListIn,Listout,AccIn,AccOut).
map_fold1(_,[],[],A,A).
map_fold1(Pred,[X|Xs],[Y|Ys],Ax,Ay) :- call(Pred,X,Y,Ax,Aint),map_fold1(Pred,Xs,Ys,Aint,Ay).

% map_fold2(Pred,ListIn,Listout,AccIn,AccOut,BccIn,BccOut).
map_fold2(_,[],[],A,A,B,B).
map_fold2(Pred,[X|Xs],[Y|Ys],Ax,Ay,Bx,By) :- call(Pred,X,Y,Ax,Aint,Bx,Bint),map_fold2(Pred,Xs,Ys,Aint,Ay,Bint,By).

convert_ast_to_rform(AST,Program) :- foldl(convert_ast_to_rform_one,AST,prog([],[]),Program).

convert_ast_to_rform_one(fact(compound(atom(Name),Args)),prog(PredDictIn,Cin),prog(PredDictOut,Cout)) :-
    length(Args,La),get_index_dict(f(Name,La),Index,PredDictIn,PredDict1),
    process_args_body(Args,[],[NormArgs,NormBody],VarDictOut,PredDict1,PredDictOut),
    append_to_nth(Index,clause(VarDictOut,NormArgs,NormBody),Cin,Cout).
convert_ast_to_rform_one(rule(compound(atom(Name),Args),Body),prog(PredDictIn,Cin),prog(PredDictOut,Cout)) :-
    length(Args,La),get_index_dict(f(Name,La),Index,PredDictIn,PredDict1),
    process_args_body(Args,Body,[NormArgs,NormBody],VarDictOut,PredDict1,PredDictOut),
    append_to_nth(Index,clause(VarDictOut,NormArgs,NormBody),Cin,Cout).
    
process_args_body(Args,Body,[ProcessedArgs,ProcessedBody],VarDictOut,PredDictIn,PredDictOut) :-
    map_fold1(process_args_one,Args,ProcessedArgs,[],VarDictInt),
    map_fold2(process_body_one,Body,ProcessedBody,VarDictInt,VarDictOut,PredDictIn,PredDictOut).

process_args_one(variable(M),v(V),VarDictIn,VarDictOut) :- get_index_dict(M,V,VarDictIn,VarDictOut).
process_args_one(anonymous,anonymous,VarDictIn,VarDictIn).
process_args_one(eol,eol,VarDictIn,VarDictIn).
process_args_one(integer(N),i(N),VarDictIn,VarDictIn).
process_args_one(list([],X1),X2,VarDictIn1,VarDictIn2) :- process_args_one(X1,X2,VarDictIn1,VarDictIn2).
process_args_one(list([Car|Cdr],X),list(Car1,Cdr1),VarDictIn,VarDictOut) :-
    process_args_one(Car,Car1,VarDictIn,VarDictInt),
    process_args_one(list(Cdr,X),Cdr1,VarDictInt,VarDictOut).

process_body_one(variable(M),v(V),VarDictIn,VarDictOut,PredDict,PredDict) :- get_index_dict(M,V,VarDictIn,VarDictOut).
process_body_one(anonymous,anonymous,VarDictIn,VarDictIn,PredDict,PredDict).
process_body_one(eol,eol,VarDictIn,VarDictIn,PredDict,PredDict).
process_body_one(integer(N),i(N),VarDictIn,VarDictIn,PredDict,PredDict).
process_body_one(list([],X1),X2,VarDictIn,VarDictIn,PredDict1,PredDict2) :- process_body_one(X1,X2,VarDictIn,VarDictIn,PredDict1,PredDict2).
process_body_one(list([Car|Cdr],X),list(Car1,Cdr1),VarDictIn,VarDictOut,PredDictIn,PredDictOut) :-
    process_body_one(Car,Car1,VarDictIn,VarDictInt,PredDictIn,PredDictInt),
    process_body_one(list(Cdr,X),Cdr1,VarDictInt,VarDictOut,PredDictInt,PredDictOut).
process_body_one(infix(Op,_,Fa,Fb),function(Op2,Fa1,Fb1),VarDictIn,VarDictOut,PredDictIn,PredDictOut) :-
    process_convert_op(Op,Op2),
    process_body_one(Fa,Fa1,VarDictIn,VarDictInt,PredDictIn,PredDictInt),
    process_body_one(Fb,Fb1,VarDictInt,VarDictOut,PredDictInt,PredDictOut).
process_body_one(compound(atom(Name),Args),fcall(Index,ProcessedArgs),VarDictIn,VarDictOut,PredDictIn,PredDictOut) :-
    length(Args,La),get_index_dict(f(Name,La),Index,PredDictIn,PredDict1),
    map_fold2(process_body_one,Args,ProcessedArgs,VarDictIn,VarDictOut,PredDict1,PredDictOut).

process_convert_op(=\=,test_neq).
process_convert_op(is,assign).
process_convert_op(+,add).

convert_input(X,f(Name,La),Args,Dict) :-
    prolog_ast(X,prolog([fact(compound(atom(Name),RawArgs))])),
    length(RawArgs,La),
    map_fold1(process_args_one,RawArgs,Args,[],Dict).

run_program(Program,InitClause,Goal,Nmax,Sub,Subn) :-
    nth0(InitClause,Program,Clause),
    run_program_aux(Program,Clause,Goal,Nmax,Sub,Subn).

run_program_aux(Program,[clause(Cdict,Args,Body)|_],Goal,Nmax,Sub,Sub3) :-
    maplist(var_add(Nmax),Args,Args2),
    maplist(var_add(Nmax),Body,Body2),
    map_fold1(unify,Goal,Args2,Sub,Sub2),
    maplist(usubstitute(Sub2),Body2,Body3),
    length(Cdict,Csize),
    NewNmax is Csize+Nmax,
    foldl(run_program_aux2(Program,NewNmax),Body3,Sub2,Sub3).
run_program_aux(Program,[_|Tclause],Goal,Nmax,Sub,Subn) :-
    run_program_aux(Program,Tclause,Goal,Nmax,Sub,Subn).

run_program_aux2(Program,NewNmax,fcall(Index,Args),Sub0,Subn) :-
    nth0(Index,Program,Clause),
    maplist(usubstitute(Sub0),Args,Args2),
    run_program_aux(Program,Clause,Args2,NewNmax,Sub0,Subn).
    
unify(X,X,S,S) :- !.
unify(v(V),X,S0,[subst(V,X1)|S1]) :-
    X\==v(V),!,
    unot_occurs(V,X),
    usubstitute(S0,X,X1),
    usubsub0(V,X1,S0,S1).
unify(X,v(V),S0,[subst(V,X1)|S1]) :-
    X\==v(_),!,
    unot_occurs(V,X),
    usubstitute(S0,X,X1),
    usubsub0(V,X1,S0,S1).
unify(list(H1,T1),list(H2,T2),S0,S2) :- !,
    unify(H1,H2,S0,S1),
    usubstitute(Sh,T1,W1),
    usubstitute(Sh,T2,W2),!,
    unify(W1,W2,S1,S2).

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

usubsub0(_,_,[],[]).
usubsub0(V,X,[subst(V,X)|T0],T1) :- usubsub0(V,X,T0,T1).
usubsub0(V,X,[subst(V0,X0)|T0],[subst(V0,X1)|T1]) :- V\==V0,usubsub(V,X,X0,X1),usubsub0(V,X,T0,T1).

usubsub(V,X,v(V),X).
usubsub(V,_,v(W),v(W)) :- W\==V.
usubsub(_,_,i(V),i(V)).
usubsub(_,_,eol,eol).
usubsub(V,X,list(H1,T1),list(H2,T2)) :- usubsub(V,X,H1,H2),usubsub(V,X,T1,T2).
usubsub(V,X,fcall(N,Args),fcall(N,Args2)) :- map(usubsub(V,X),Args,Args2).
usubsub(V,X,function(Op,X1,Y1),function(Op,X2,Y2)) :- usubsub(V,X,X1,X2),usubsub(V,X,Y1,Y2).

usubstitute1([],V,v(V)).
usubstitute1([subst(V,X)|_],V,X).
usubstitute1([subst(W,_)|T],V,V2) :- W=\=V,usubstitute1(T,V,V2).

var_add(N,v(V),v(V2)) :- V2 is V+N.
var_add(_,i(V),i(V)).
var_add(_,eol,eol).
var_add(N,list(H1,T1),list(H2,T2)) :- var_add(N,H1,H2),var_add(N,T1,T2).
var_add(N,fcall(M,Args),fcall(M,Args2)) :- maplist(var_add(N),Args,Args2).
var_add(N,function(Op,X1,Y1),function(Op,X2,Y2)) :- usubstitute(N,X1,X2),usubstitute(N,Y1,Y2).
