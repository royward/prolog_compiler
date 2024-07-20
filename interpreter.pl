:- consult('../plammar/pack.pl').
:- use_module(library(plammar)).
:- use_module(library(plammar/environments)).
:- use_module(library(cli_table)).

% convert_program(file("/home/roy/prolog/nqueens.pl"),PredDict,Rform),print(PredDict),nl,nl,print(Rform),nl,nl.
% convert_program(file("/home/roy/prolog/append.pl"),PredDict,Rform),print(PredDict),nl,nl,print(Rform),nl,nl.
% convert_input(string("[1,2,[3,X],X,Y,5]."),Rform,[],PredDict),print(PredDict),nl,nl,print(Rform),nl,nl.
% convert_input(string("X."),Rform,PredDict),[],print(PredDict),nl,nl,print(Rform),nl,nl.
% convert_input(string("[1,2,3]."),Rform,[],PredDict),print(PredDict),nl,nl,print(Rform),nl,nl.
% convert_input(string("[]."),Rform,[],PredDict),print(PredDict),nl,nl,print(Rform),nl,nl.
% interpret(file("/home/roy/prolog/append.pl"),string("append([1,2,3],[3],X)."),2,Results).
% convert_input(string("append([1,2,3],[3],X)."),Name,Args,Dict).

interpret(RawProgram,Gaol,NumOutputs,[]) :-
    convert_program(RawProgram,Pdist1,Program),
    convert_input(Gaol,Name,Inputs,InputDict),
    get_index_dict(Name,InitClause,Pdist1,Pdist2),
    print(Program),nl,
    print(Pdist2),nl,
    print(InitClause),nl,
    print(NumOutputs),nl,
    print(Inputs),nl,
    print(InputDict),nl.    
    
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

% prolog([
% fact(compound(atom(range),[variable('M'),variable('M'),list([variable('M')],eol)])),
% rule(compound(atom(range),[variable('M'),variable('N'),list([variable('M')],variable('Ns'))]),
%     [infix(=\=,xfx,variable('M'),variable('N')),infix(is,xfx,variable('M1'),infix(+,yfx,variable('M'),integer(1))),compound(atom(range),[variable('M1'),variable('N'),variable('Ns')])]),
% 
% fact(compound(atom(selectx),[variable('X'),list([variable('X')],variable('Xs')),variable('Xs')])),
% rule(compound(atom(selectx),[variable('X'),list([variable('Y')],variable('Ys')),list([variable('Y')],variable('Zs'))]),
%     [compound(atom(selectx),[variable('X'),variable('Ys'),variable('Zs')])]),
%     
% rule(compound(atom(queens),[variable('N'),variable('Qs')]),
%     [compound(atom(range),[integer(1),variable('N'),variable('Ns')]),compound(atom(queens_aux),[variable('Ns'),list([],eol),variable('Qs')])]),
%     
% rule(compound(atom(queens_aux),[variable('UnplacedQs'),variable('SafeQs'),variable('Qs')]),
%     [compound(atom(selectx),[variable('Q'),variable('UnplacedQs'),variable('UnplacedQs1')]),
%         compound(atom(not_attack),[variable('Q'),integer(1),variable('SafeQs')]),
%         compound(atom(queens_aux),[variable('UnplacedQs1'),list([variable('Q')],variable('SafeQs')),variable('Qs')])]),
% fact(compound(atom(queens_aux),[list([],eol),variable('Qs'),variable('Qs')])),
% 
% fact(compound(atom(not_attack),[anonymous,anonymous,list([],eol)])),
% rule(compound(atom(not_attack),[variable('Q0'),variable('D0'),list([variable('Q')],variable('Qs'))]),
%     [infix(=\=,xfx,variable('Q0'),variable('Q')),
%         infix(=\=,xfx,infix(-,yfx,variable('Q0'),variable('Q')),variable('D0')),
%         infix(=\=,xfx,infix(-,yfx,variable('Q'),variable('Q0')),variable('D0')),
%         infix(is,xfx,variable('D1'),infix(+,yfx,variable('D0'),integer(1))),
%         compound(atom(not_attack),[variable('Q0'),variable('D1'),variable('Qs')])])])

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

% [f(range,3),f(selectx,3),f(queens,2),f(queens_aux,3),f(not_attack,3)]
% [   [clause(['M'],
%         [v(0),v(0),list(v(0),eol)],
%             []),
%     clause(['M','N','Ns','M1'],
%         [v(0),v(1),list(v(0),v(2))],
%             [function(test_neq,v(0),v(1)),
%             function(assign,v(3),function(add,v(0),i(1))),
%             fcall(0,[v(3),v(1),v(2)])])],
% [   clause(['X','Xs'],
%         [v(0),list(v(0),v(1)),v(1)],
%             []),
%     clause(['X','Y','Ys','Zs'],
%         [v(0),list(v(1),v(2)),list(v(1),v(3))],
%             [fcall(1,[v(0),v(2),v(3)])])],
% [   clause(['N','Qs','Ns'],
%         [v(0),v(1)],
%             [fcall(0,[i(1),v(0),v(2)]),
%             fcall(3,[v(2),eol,v(1)])])],
% [   clause(['UnplacedQs','SafeQs','Qs','Q','UnplacedQs1'],
%         [v(0),v(1),v(2)],
%             [fcall(1,[v(3),v(0),v(4)]),
%             fcall(4,[v(3),i(1),v(1)]),
%             fcall(3,[v(4),list(v(3),v(1)),v(2)])]),
%     clause(['Qs'],
%         [eol,v(0),v(0)],
%             [])],
% [   clause([],
%         [anonymous,anonymous,eol],
%             []),
%     clause(['Q0','D0','Q','Qs','D1'],
%     [v(0),v(1),list(v(2),v(3))],
%         [function(test_neq,v(0),v(2)),
%         function(test_neq,function(sub,v(0),v(2)),v(1)),
%         function(test_neq,function(sub,v(2),v(0)),v(1)),
%         function(assign,v(4),function(add,v(1),i(1))),
%         fcall(4,[v(0),v(4),v(3)])])]]
