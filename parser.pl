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
convert_program(file("nqueens.pl"),PDict,Rform),print(PDict),nl,nl,print(Rform),nl,nl.
convert_program(file("append.pl"),PDict,Rform),print(PDict),nl,nl,print(Rform),nl,nl.
convert_program(file("selectx.pl"),PDict,Rform),print(PDict),nl,nl,print(Rform),nl,nl.
convert_input(string("append([1,2,3],[3],X)."),Name,Args,Dict).
*/

convert_program(X,PDict,Rform) :- prolog_ast(X,prolog(AST)),convert_ast_to_rform(AST,prog(PDict,Rform)).

get_index_dict(N,V,PDictIn,PDictOut) :- get_index_dict_aux(N,0,V,PDictIn,PDictOut).

get_index_dict_aux(N,I,I,[],[N]).
get_index_dict_aux(N,I,I,[N|T],[N|T]).
get_index_dict_aux(N,I,V,[X|T1],[X|T2]) :-
    N \== X,
    I1 is I+1,
    get_index_dict_aux(N,I1,V,T1,T2).

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
    length(Args,La),get_index_dict(f(Name,La),Index,PDict1,PDict2),
    process_args_body(Args,[],[NormArgs,NormBody],VDict,PDict2,PDict3),
    append_to_nth(Index,clause(VDict,NormArgs,NormBody),C1,C2).
convert_ast_to_rform_one(rule(compound(atom(Name),Args),Body),prog(PDict1,C1),prog(PDict3,C2)) :-
    length(Args,La),get_index_dict(f(Name,La),Index,PDict1,PDict2),
    process_args_body(Args,Body,[NormArgs,NormBody],VDict,PDict2,PDict3),
    append_to_nth(Index,clause(VDict,NormArgs,NormBody),C1,C2).

process_args_body(Args,Body,[ProcessedArgs,ProcessedBody],VDict2,PDict1,PDict2) :-
    map_fold1(process_args_one,Args,ProcessedArgs,[],VDict1),
    map_fold2(process_body_one,Body,ProcessedBody,VDict1,VDict2,PDict1,PDict2).

process_args_one(variable(M),v(V),VDict1,VDict2) :- get_index_dict(M,V,VDict1,VDict2).
process_args_one(anonymous,anonymous,VDict,VDict).
process_args_one(eol,eol,VDict,VDict).
process_args_one(integer(N),i(N),VDict,VDict).
process_args_one(list([],X1),X2,VDict1,VDict2) :- process_args_one(X1,X2,VDict1,VDict2).
process_args_one(list([H1|T1],X),list(H2,T2),VDict1,VDict3) :-
    process_args_one(H1,H2,VDict1,VDict2),
    process_args_one(list(T1,X),T2,VDict2,VDict3).

process_body_one(variable(M),v(V),VDict1,VDict2,PDict,PDict) :- get_index_dict(M,V,VDict1,VDict2).
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
    length(Args,La),get_index_dict(f(Name,La),Index,PDict1,PDict2),
    map_fold2(process_body_one,Args,ProcessedArgs,VDict1,VDict2,PDict2,PDict3).

process_convert_op(=\=,test_neq).
process_convert_op(is,assign).
process_convert_op(+,add).
process_convert_op(-,sub).
process_convert_op(*,times).

convert_input(X,f(Name,La),Args,Dict) :-
    prolog_ast(X,prolog([fact(compound(atom(Name),RawArgs))])),
    length(RawArgs,La),
    map_fold1(process_args_one,RawArgs,Args,[],Dict).

