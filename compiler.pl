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

/*
compile(file("append.pl"),string("append([],[],X).")).
compile(file("append.pl"),string("append([],[1],X).")).
compile(file("append.pl"),string("append([],[1,2],X).")).
compile(file("append.pl"),string("append([1],[],X).")).
compile(file("append.pl"),string("append([1],[2],X).")).
compile(file("append.pl"),string("append([1,2],[3,4],X).")).
compile(file("append.pl"),string("append([1,2],X,[1,2,3,4]).")).
compile(file("append.pl"),string("append(X,[1],[2]).")).
compile(file("append.pl"),string("append(X,[3,4],[1,2,3,4]).")).
compile(file("append.pl"),string("append(X,Y,[1]).")).
compile(file("append.pl"),string("append(X,Y,[1,2,3,4]).")).
compile(file("nqueens.pl"),string("nqueens(1,Q).")).
compile(file("nqueens.pl"),string("range(1,4,X).")).
compile(file("nqueens.pl"),string("nqueens_aux([1],[],Q).")).
compile(file("nqueens.pl"),string("selectx(X,[1],Y).")).
compile(file("nqueens.pl"),string("selectx(X,[1],Y).")).
compile(file("selectx.pl"),string("selectx(X,[1,2,3,4],Y).")).
compile(file("nqueens.pl"),string("nqueens(4,Q).")).
compile(file("nqueens.pl"),string("nqueens(8,Q).")).
compile(file("nqueens.pl"),string("nqueens(12,Q).")).
compile(file("foo.pl"),string("foo(1,2,X).")).
*/

trace_mode :- fail.

compile(RawProgram,RawGoal) :-
    convert_program(RawProgram,Pdict,Program),
    maplist(length,Program,ClauseCounts),
    convert_input(RawGoal,f(Name,Arity),Goal,InputDict),
    get_index_dict(f(Name,Arity),InitClause,Pdict,_),
    length(InputDict,I1),
    open('PrologGenerated.cpp',write,St),
    write(St,'//////////////////////////////////////////////////////////////////////////////////////\n'),
    write(St,'// DO NOT EDIT THIS FILE. It is programmatically generated and WILL be overwritten. //\n'),
    write(St,'//////////////////////////////////////////////////////////////////////////////////////\n\n'),
    write(St,'#include "Prolog.h"\n\n'),
    maplist(write_function_template(St),Pdict),nl(St),
    write(St,'void Prolog::__do_start() {\n'),
    foldl(setup_args(St),Goal,0,_),
    write(St,'\tframe_top=0;\n'),
    write(St,'\tFrameStore& frame=frames[frame_top];\n'),
    write(St,'\tframe.clause_index=0;\n'),
    write(St,'\tframe.clause_count=0;\n'),
    write(St,'\tframe.parent_frame=0;\n'),
    (trace_mode -> write(St,'\tframe.call_depth=1;\n') ; true),
    write(St,'\tframes[0].store_sp=base_sp=(uint8_t*)__builtin_frame_address(0);\n'),
    write(St,'\tuint32_t parent_frame=0;\n'),
    nth0(InitClause,Pdict,f(Name,Arity)),
    (InputDict=[] -> true ; foldl(do_init(St),InputDict,0,_)),
    write(St,'\tuint32_t voffset_next='),write(St,I1),write(St,';\n'),
    write(St,'\tbool found='),write(St,Name),write(St,'_'),write(St,Arity),write(St,'(*this'),
    write_arg(St,', goal_args',0,Arity),
    write(St,', voffset_next, voffset_next, parent_frame);\n'),
    write(St,'\tif(found) {\n'),
    (InputDict=[] -> write(St,'\t\tstd::cout << "true." << std::endl;\n') ; foldl(do_output(St),InputDict,0,_)),
    write(St,'\t} else {\n'),
    write(St,'\t\tstd::cout << "false." << std::endl;\n'),
    write(St,'\t}\n'),
    write(St,'\tif(frame_top>0) {\n'),
    (trace_mode -> write(St,'\t\t\tstd::cout << "=== loaded continuation " << frame_top << std::endl;\n') ; true),
    write(St,'\t\tprocess_stack_state_load_save(frame_top);\n'),
    write(St,'\t}\n'),
    write(St,'}\n'),
    maplist(compile_predicate(St,Pdict,ClauseCounts),Pdict,Program),
    close(St).

do_output(St,InputName,N,N1) :-
    N1 is N+1,
    write(St,'\t\tstd::cout << "'),write(St,InputName),write(St,' = " << '),write(St,'pldisplay(('),write(St,N),write(St,'<<TAG_WIDTH)+TAG_VREF) << std::endl;\n').

do_init(St,_,N,N1) :-
    N1 is N+1,
    write(St,'\tvariables['),write(St,N),write(St,']=TAG_VAR;\n').

setup_args(St,Arg,N,N1) :-
    N1 is N+1,
    write(St,'\tuint32_t goal_args'),write(St,N),write(St,'='),
    write_build(St,'',Arg),
    write(St,';\n').

write_build(St,Prefix,eol) :- write(St,Prefix),write(St,'plcreate_eol()').
write_build(St,Prefix,i(I)) :- write(St,Prefix),write(St,'plcreate_int('),write(St,I),write(St,')').
write_build(St,Prefix,v(N)) :- write(St,Prefix),write(St,'plcreate_var('),write(St,N),write(St,')').
write_build(St,Prefix,list(H,T)) :-
    write(St,Prefix),write(St,'plcreate_list('),
    write_build(St,Prefix,H),
    write(St,','),
    write_build(St,Prefix,T),
    write(St,')').

write_arg(_,_,N,N).
write_arg(St,String,N,M) :-
    N=\=M,
    write(St,String),
    write(St,N),
    N1 is N+1,
    write_arg(St,String,N1,M).

write_arg2(_,_,_,N,N).
write_arg2(St,String1,String2,N,M) :-
    N=\=M,
    write(St,String1),
    write(St,N),
    write(St,String2),
    N1 is N+1,
    write_arg2(St,String1,String2,N1,M).

write_function_template(St,f(Name,Arity)) :-
    write(St,'uint8_t '),write(St,Name),write(St,'_'),write(St,Arity),write(St,'(Prolog& p'),
    write_arg(St,', uint32_t arg',0,Arity),
    write(St,', uint32_t voffset, uint32_t& voffset_new, uint32_t parent_frame);\n').

create_multifire_matrix([],[]).
create_multifire_matrix([clause(_,Args,_)|RestC],[Row|RestR]) :-
    foldl(create_multifire_row,RestC,Args,Row),
    create_multifire_matrix(RestC,RestR).

create_multifire_row(clause(_,Args1,_),Args2,Row) :- maplist(create_multifire_row_one,Args1,Args2,Row).

create_multifire_row_one(eol,eol,v(-1)) :- !.
create_multifire_row_one(_,v(N),v(N)) :- !.
create_multifire_row_one(i(N),i(N),v(-1)) :- !.
create_multifire_row_one(list(H1,T1),list(H2,T2),R) :- !,
    create_multifire_row_one(H1,H2,Ra),
    create_multifire_row_one(T1,T2,Rb),
    (Ra=v(_),Rb=v(_) -> R=v(-1) ; R=list(H2,T2)).
create_multifire_row_one(v(N),_,v(N)).
create_multifire_row_one(_,X,X).

compile_predicate(St,Pdict,ClauseCounts,f(Name,Arity),Predicate) :-
    create_multifire_matrix(Predicate,Matrix),
    length(Predicate,LP),
    nl(St),write(St,'uint8_t '),write(St,Name),write(St,'_'),write(St,Arity),write(St,'(Prolog& p'),
    write_arg(St,', uint32_t arg',0,Arity),
    write(St,', uint32_t voffset, uint32_t& voffset_new, uint32_t parent_frame) {\n'),
    (LP>1 -> write(St,'\tFrameStore* fs=nullptr;\n') ; true),
    write(St,'\tuint32_t unwind_stack_decouple_mark=p.top_unwind_stack_decouple;\n'),
    %(Arity>0 -> write(St,'\tuint8_t tag_arg0'),compile_clause_args_setup_vars(St,', tag_arg',1,Arity),write(St,';\n') ; true),
    write(St,'\tuint32_t function_frame_top='),
    (LP>1 -> write(St,'p.frame_top;\n') ; write(St,'p.function_frame_top_last_n_clause;\n')),
    (trace_mode,LP>1 ->
        write(St,'\t std::cout << (int)((fs==nullptr)?-1:fs->call_depth) << \':\' << ">'),write(St,Name),write(St,'"'),
        write_arg2(St,' << \',\' << p.pldisplay(arg',')',0,Arity),
        write(St,' << " c=" << (int)((fs==nullptr)?-1:fs->clause_index) << std::endl;\n')
    ; true),
    foldl(compile_clause(Name,Arity,St,Pdict,ClauseCounts,LP),Predicate,Matrix,0,_),
    %(LP>1 -> write(St,'\tp.pop_frame_stack();\n') ; true),
    write(St,'\tvoffset_new=voffset;\n'),
    (trace_mode -> write(St,'\t std::cout << '),(LP>1 -> write(St,'(int)((fs==nullptr)?-1:fs->call_depth)') ; write(St,'0')),write(St,' << \':\' << "<'),write(St,Name),write(St,':FAIL" << std::endl;\n') ; true),
    write(St,'\treturn false;\n'),
    write(St,'}\n').

compile_args_conditions(_,v(_),M,N) :- !,N is M+1.
compile_args_conditions(St,_,M,N) :-
    write(St,' && ((arg'),write(St,M),write(St,'&TAG_MASK)==TAG_VREF)'),
    N is M+1.

get_var_arg_map(D,D,[],_,U,U).
get_var_arg_map(D1,D3,[v(N)|T],Count,U1,U3) :- !,
    (nth0(N,D1,nomatch) ->
        nth0(N,D1,_,Transfer),
        nth0(N,D2,a(Count),Transfer),
        U2=[N|U1]
    ; D2=D1,U2=U1),
    Count2 is Count+1,
    get_var_arg_map(D2,D3,T,Count2,U2,U3).
get_var_arg_map(D1,D2,[_|T],Count,U1,U2) :-
    Count2 is Count+1,
    get_var_arg_map(D1,D2,T,Count2,U1,U2).

fill_var_map([],[],C,C).
fill_var_map([H1|T1],[H2|T2],C1,C3) :-
    (H1==nomatch ->
        H2=v(C1),C2 is C1+1
    ; H2=H1,C2=C1),
    fill_var_map(T1,T2,C2,C3).

write_tag(St,V) :- write(St,',tag_'),write(St,V).

compile_clause(Name,Arity,Sto,Pdict,ClauseCounts,LP,clause(Dict,Args,Body),MRow,NClause,NClause1) :-
    NClause1 is NClause+1,
    (LP>1 -> write(Sto,'\t{\n') ; true),
    length(Dict,LD0),
    length(EmptyDictTranslate,LD0),
    maplist(=(nomatch),EmptyDictTranslate),
    get_var_arg_map(EmptyDictTranslate,DictTranslate0,Args,0,[],Used0),
    fill_var_map(DictTranslate0,DictT,0,LD),
    empty_assoc(Sdictpart),
    Sdict1=state(Sdictpart,[],[],false),
    new_memory_file(MemoryFile),
    open_memory_file(MemoryFile,write,St),
    write(St,'\t\tuint32_t voffset_next=voffset+'),write(St,LD),write(St,';\n'),
    (LD>0 -> write(St,'\t\tuint32_t var0'),compile_clause_args_setup_vars(St,', var',1,LD),write(St,';\n') ; true),
    atomics_to_string(['label_c',NClause],Label),
    fold3(compile_clause_args1(St,DictT,Label),Args,0,_,Used0,Used1,Sdict1,Sdict2),
    (LP>1, NClause1\=LP ->
        (NClause=0 -> write(St,'\t\tif(true') ; write(St,'\t\tif(fs==nullptr')),
        foldl(compile_args_conditions(St),MRow,0,_),
        write(St,') {\n'),
        write(St,'\t\t\tfs=&p.frames[++p.frame_top];\n'),
        write(St,'\t\t\tfs->clause_index='),write(St,NClause),write(St,';\n'),
        write(St,'\t\t\tfunction_frame_top=p.frame_top;\n'),
        write(St,'\t\t\tfs->clause_count='),write(St,LP),write(St,';\n'),
        write(St,'\t\t\tfs->parent_frame=parent_frame;\n'),
        write(St,'\t\t\tparent_frame=p.frame_top;\n'),
        write(St,'\t\t\tfs=p.process_stack_state_load_save(0);\n'),
        write(St,'\t\t\tfs->clause_index++;\n'),
        write(St,'\t\t\tif(fs->clause_index!='),write(St,NClause1),write(St,') {\n'),
        write(St,'\t\t\t\tp.unwind_stack_revert_to_mark(unwind_stack_decouple_mark,function_frame_top,parent_frame);\n'),
        %write(St,'\t\t\t\tparent_frame=p.frame_top;\n'),
        write(St,'\t\t\t\tgoto next_'),write(St,Label),write(St,';\n'),
        write(St,'\t\t\t} else {\n'),
        (trace_mode -> write(St,'\t\t\t\tstd::cout << "=== saved continuation " << p.frame_top << std::endl;\n') ; true),
        do_process_delayed(St,Sdict2,Sdict3),
        write(St,'\t\t\t}\n'),
        write(St,'\t\t}\n')
    ; Sdict3=Sdict2),
    foldl(compile_clause_body_args_prep_vars(St,DictT),Args,Used1,Used2),
    fold3(compile_clause_body(St,DictT,Label,Pdict,LP,ClauseCounts),Body,Used2,_,0,_,Sdict3,Sdictn),
    do_process_delayed(St,Sdictn,state(_,Tags,_,_)),
    write(St,'\t\tvoffset_new=voffset_next;\n'),
    %(LP>1 -> write(St,'\t\tp.pop_frame_stack();\n') ; true),
    (trace_mode,LP>1 ->
        write(St,'\t std::cout << '),(LP>1 -> write(St,'(int)((fs==nullptr)?-1:fs->call_depth)') ; write(St,'0')),write(St,' << \':\' << "<'),
        write(St,Name),write(St,'"'),
        write_arg2(St,' << \',\' << p.pldisplay(arg',')',0,Arity),
        write(St,' << " c=" << (int)((fs==nullptr)?-1:fs->clause_index-1) << std::endl;\n')
    ; true),
    write(St,'\t\treturn true;\n'),
    close(St),
    memory_file_to_string(MemoryFile, PredBody),
    free_memory_file(MemoryFile),
    (Tags=[H|T] ->
        write(Sto,'\t\tuint8_t tag_'),write(Sto,H),
        maplist(write_tag(Sto),T),
        write(Sto,';\n')
    ; true),
    write(Sto,PredBody),
    (LP>1 -> write(Sto,'\t}\n') ; true),
    write(Sto,'fail_'),write(Sto,Label),write(Sto,':;\n'),
    write(Sto,'\tp.unwind_stack_revert_to_mark(unwind_stack_decouple_mark,function_frame_top,parent_frame);\n'),
    write(Sto,'fail_'),write(Sto,Label),write(Sto,'_no_unwind:;\n'),
    (LP>1,NClause1\=LP -> write(Sto,'\tif(fs!=nullptr)fs->clause_index++;\n') ; true),
    write(Sto,'next_'),write(Sto,Label),write(Sto,':;\n').

process_delayed_pre(St,[]) :- write(St,'\t\t').
process_delayed_pre(St,[t(N,equal,Tag)|T]) :-
    process_delayed_pre(St,T),
    write(St,'if(tag_'),write(St,N),write(St,'=='),write(St,Tag),write(St,')').
process_delayed_pre(St,[t(N,notequal,Tag)|T]) :-
    process_delayed_pre(St,T),
    write(St,'if(tag_'),write(St,N),write(St,'!='),write(St,Tag),write(St,')').

process_delayed(St,var_set_add_to_unwind_stack_var(Pre,Chase,L,V),Sdict1,state(Sd,Tags1,Delayed,true)) :-
    process_delayed_pre(St,Pre),
    (Chase -> check_pointer_chase_notag(St,V,Sdict1,Sdict2) ; Sdict2=Sdict1),
    state(Sd,Tags1,Delayed,_)=Sdict2,
    write(St,'p.var_set_add_to_unwind_stack('),write(St,L),write(St,'>>TAG_WIDTH,'),write(St,V),write(St,');\n').
process_delayed(St,var_set_add_to_unwind_stack_offset(Pre,Chase,L,V),Sdict1,state(Sd,Tags1,Delayed,true)) :-
    process_delayed_pre(St,Pre),
    (Chase -> check_pointer_chase_notag(St,V,Sdict1,Sdict2) ; Sdict2=Sdict1),
    state(Sd,Tags1,Delayed,_)=Sdict2,
    write(St,'p.var_set_add_to_unwind_stack('),write(St,L),write(St,'+voffset,'),write(St,V),write(St,');\n').
process_delayed(St,create_list(Pre,N,H,T),Sdict1,Sdict1) :-
    process_delayed_pre(St,Pre),
    write(St,N),write(St,'lc=p.plcreate_list('),write(St,H),write(St,','),write(St,T),write(St,');\n').

compile_clause_args_setup_vars(_,_,N,N).
compile_clause_args_setup_vars(St,S,M,N) :- M<N,write(St,S),write(St,M),M1 is M+1,compile_clause_args_setup_vars(St,S,M1,N).

write_var_from_dictt(St,N,DictT) :-
    nth0(N,DictT,X),
    ( X=v(K) -> write(St,'var'),write(St,K)
    ; X=a(K) -> write(St,'arg'),write(St,K)).

arg_to_atom_for_dict(DictT,N,V) :-
    nth0(N,DictT,X),
    (X=a(K) -> atomic_concat(arg,K,V)
    ; X=v(K), atomic_concat(var,K,V)).

/*
unchased
chased_untagged
chased_tagged
ground
*/

get_from_dict(Name,Sdict1,Result,Sdict2) :-
    (get_assoc(Name,Sdict1,Result) -> Sdict2=Sdict1
    ; Result=k(chased_untagged,type_unknown),put_assoc(Name,Sdict1,Result,Sdict2)).

put_in_dict(Name,Sdict1,Value,Sdict2) :- put_assoc(Name,Sdict1,Value,Sdict2).

check_tag_var_type(St,Name,state(Sdict1,Tags1,Delayed,UW1),state(Sdict4,Tags2,Delayed,UW2),TpSet,Label) :-
    check_got_tag(St,Name,state(Sdict1,Tags1,Delayed,UW1),state(Sdict2,Tags2,Delayed,UW2)),
    get_from_dict(Name,Sdict2,k(X,Tp),Sdict3),
    (Tp=TpSet -> Sdict4=Sdict3
    ;   put_in_dict(Name,Sdict3,k(X,TpSet),Sdict4),
        write(St,'\t\tif(tag_'),write(St,Name),write(St,'!='),write(St,TpSet),write(St,') {goto fail_'),write(St,Label),
        (UW1 -> true ; write(St,'_no_unwind')),
        write(St,';}\n')).

check_got_tag(St,Name,state(Sdict1,Tags1,Delayed,UW1),state(Sdict3,Tags3,Delayed,UW1)) :-
    get_from_dict(Name,Sdict1,PCState0,Sdict2),
    (PCState0=k(unchased,Tp) ->
        write(St,'\t\tp.pointer_chase(tag_'),write(St,Name),write(St,','),write(St,Name),write(St,');\n'),
        put_in_dict(Name,Sdict2,k(chased_tagged,Tp),Sdict3),
        (member(Name,Tags1) -> Tags3=Tags1 ; Tags3=[Name|Tags1])
    ; PCState0=k(chased_untagged,Tp) ->
        write(St,'\t\ttag_'),write(St,Name),write(St,'=('),write(St,Name),write(St,'&TAG_MASK);\n'),
        put_in_dict(Name,Sdict2,k(chased_tagged,Tp),Sdict3),
        (member(Name,Tags1) -> Tags3=Tags1 ; Tags3=[Name|Tags1])
    ; Sdict3=Sdict1,Tags3=Tags1).

check_pointer_chase_notag(St,Name,state(Sdict1,Tags,Delayed,UW1),state(Sdict3,Tags,Delayed,UW1)) :-
    get_from_dict(Name,Sdict1,PCState0,Sdict2),
    (PCState0=k(unchased,Tp) ->
        write(St,'\t\tp.pointer_chase_notag('),write(St,Name),write(St,');\n'),
        put_in_dict(Name,Sdict2,k(chased,Tp),Sdict3)
    ; Sdict3=Sdict1).

check_pointer_chase_notag_for_fcall(St,Name,state(Sdict1,Tags,Delayed,UW1),state(Sdict3,Tags,Delayed,UW1)) :-
    get_from_dict(Name,Sdict1,PCState0,Sdict2),
    (PCState0=k(unchased,_) ->
        write(St,'\t\tp.pointer_chase_notag('),write(St,Name),write(St,');\n')
    ; true),
    (PCState0=k(ground,_) -> Sdict3=Sdict2
    ; PCState0=k(_,Tp),put_in_dict(Name,Sdict2,k(unchased,Tp),Sdict3)).

check_pointer_chase_notag_for_fcall_list(_,[],_,Sdict,Sdict).
check_pointer_chase_notag_for_fcall_list(St,[v(N)|ArgRest],DictT,Sdict1,Sdictn) :-
    arg_to_atom_for_dict(DictT,N,Name),
    check_pointer_chase_notag_for_fcall(St,Name,Sdict1,Sdict2),
    check_pointer_chase_notag_for_fcall_list(St,ArgRest,DictT,Sdict2,Sdictn).
check_pointer_chase_notag_for_fcall_list(St,[list(V1,V2)|ArgRest],DictT,Sdict1,Sdictn) :-
    check_pointer_chase_notag_for_fcall_list(St,[V1,V2|ArgRest],DictT,Sdict1,Sdictn).
check_pointer_chase_notag_for_fcall_list(St,[eol|ArgRest],DictT,Sdict1,Sdict2) :-
    check_pointer_chase_notag_for_fcall_list(St,ArgRest,DictT,Sdict1,Sdict2).
check_pointer_chase_notag_for_fcall_list(St,[i(_)|ArgRest],DictT,Sdict1,Sdict2) :-
    check_pointer_chase_notag_for_fcall_list(St,ArgRest,DictT,Sdict1,Sdict2).

add_delayed_instruction(state(D,T,Delayed,UW1),state(D,T,[V|Delayed],UW1),V).

compile_clause_args1(St,DictT,Label,X,N,N1,Used1,Used2,Sdict1,Sdict2) :-
    N1 is N+1,
    atomics_to_string(['arg',N],Argname),
    compile_clause_args1_aux(St,DictT,Label,X,Argname,Used1,Used2,Sdict1,Sdict2,[]).

compile_clause_args1_aux(St,DictT,Label,X,N,Used1,Used2,Sdict1,Sdict2,Pre) :-
    compile_clause_args1_aux2(St,DictT,Label,X,N,Used1,Used2,Sdict1,Sdict2,Pre),
    write(St,'s_'),write(St,Label),write(St,'_'),write(St,N),write(St,':;\n').

do_process_delayed(St,Sdict1,Sdict3) :-
    Sdict1=state(_,_,DelayedR,_),
    reverse(DelayedR,Delayed),
    map1fold1(process_delayed(St),Delayed,Sdict1,Sdict2),
    Sdict2=state(D,T,DelayedR,UW1),
    Sdict3=state(D,T,[],UW1).

compile_clause_args1_aux2(St,_,Label,eol,N,Used1,Used1,Sdict1,Sdict3,Pre) :-
    check_got_tag(St,N,Sdict1,Sdict2),
    write(St,'\t\tif(tag_'),write(St,N),write(St,'==TAG_EOL) {goto s_'),write(St,Label),write(St,'_'),write(St,N),write(St,';}\n'),
    write(St,'\t\tif(tag_'),write(St,N),write(St,'!=TAG_VREF) {goto fail_'),write(St,Label),
        (Sdict2=state(_,_,_,true) -> true ; write(St,'_no_unwind')),
        write(St,';}\n'),
    add_delayed_instruction(Sdict2,Sdict3,var_set_add_to_unwind_stack_var([t(N,notequal,'TAG_EOL')|Pre],false,N,'TAG_EOL')).
    %write(St,'\t\tp.var_set_add_to_unwind_stack('),write(St,N),write(St,'>>TAG_WIDTH,TAG_EOL);\n').
compile_clause_args1_aux2(St,_,Label,i(I),N,Used1,Used1,Sdict1,Sdict3,Pre) :-
    check_got_tag(St,N,Sdict1,Sdict2),
    write(St,'\t\tif('),write(St,N),write(St,'==('),write(St,I),write(St,'<<TAG_WIDTH)+TAG_INTEGER) {goto s_'),write(St,Label),write(St,'_'),write(St,N),write(St,';}\n'),
    write(St,'\t\tif(tag_'),write(St,N),write(St,'!=TAG_VREF) {goto fail_'),write(St,Label),
        (Sdict2=state(_,_,_,true) -> true ; write(St,'_no_unwind')),
        write(St,';}\n'),
    concat_atom([I,'<<TAG_WIDTH)+TAG_INTEGER'],R),
    add_delayed_instruction(Sdict2,Sdict3,var_set_add_to_unwind_stack_var(Pre,false,N,R)).
    %write(St,'\t\tp.var_set_add_to_unwind_stack('),write(St,N),write(St,'>>TAG_WIDTH,'),write(St,I),write(St,');\n').
compile_clause_args1_aux2(St,DictT,Label,v(V),N,Used1,Used2,Sdict1,Sdictn,Pre) :-
    (member(V,Used1) ->
        Used2=Used1,
        (nth0(V,DictT,a(NN)),atomics_to_string(['arg',NN],N) -> Sdictn=Sdict1
        ;   arg_to_atom_for_dict(DictT,V,VV),
            check_pointer_chase_notag_for_fcall(St,VV,Sdict1,Sdict2),
            check_pointer_chase_notag_for_fcall(St,N,Sdict2,state(D,T,DelayedR,_)),
            Sdictn=state(D,T,DelayedR,true),
            write(St,'\t\tif(!p.unify('),write(St,VV),write(St,','),write(St,N),write(St,')) {goto fail_'),write(St,Label),write(St,';}\n'))
    ;
        Used2=[V|Used1],
        nth0(V,DictT,v(K)),
        write(St,'\t\tvar'),write(St,K),write(St,'='),write(St,N),write(St,';\n'),
        %check_pointer_chase_notag(St,N,Sdict1,Sdict2),
        add_delayed_instruction(Sdict1,Sdictn,var_set_add_to_unwind_stack_offset(Pre,true,V,N))
        %write(St,'\t\tp.var_set_add_to_unwind_stack('),write(St,V),write(St,'+voffset,'),write(St,N),write(St,');\n')
    ).
compile_clause_args1_aux2(St,DictT,Label,list(H,T),N,Used1,Used3,Sdict1,Sdictn,_) :-
    check_got_tag(St,N,Sdict1,Sdict1a),
    H=v(Vh),
    atomics_to_string([N,'h'],ArgH),
    atomics_to_string([N,'t'],ArgT),
    write(St,'\t\tuint32_t '),write(St,N),write(St,'lc, '),write(St,ArgH),write(St,', '),write(St,ArgT),write(St,';\n'),
    write(St,'\t\tif(tag_'),write(St,N),write(St,'==TAG_LIST) {\n'),
    write(St,'\t\tList& '),write(St,N),write(St,'l=p.list_values['),write(St,N),write(St,'>>TAG_WIDTH];\n'),
    write(St,'\t\t'),write(St,ArgH),write(St,'='),write(St,N),write(St,'l.head;\n'),
    write(St,'\t\tp.pointer_chase_notag('),write(St,ArgH),write(St,');\n'),
    compile_clause_args1_aux(St,DictT,Label,H,ArgH,Used1,Used2,Sdict1a,Sdict2,[t(N,notequal,'TAG_VREF')]),
    write(St,'\t\t'),write(St,ArgT),write(St,'='),write(St,N),write(St,'l.tail;\n'),
    write(St,'\t\tp.pointer_chase_notag('),write(St,ArgT),write(St,');\n'),
    compile_clause_args1_aux(St,DictT,Label,T,ArgT,Used2,Used3,Sdict2,Sdict3,[t(N,notequal,'TAG_VREF')]),
    write(St,'\t\t} else if(tag_'),write(St,N),write(St,'==TAG_VREF) {\n'),
    concat_atom([N,'lc'],R),
    (member(Vh,Used1) -> Used1a=Used1 ;
        Used1a=[Vh|Used1],
        nth0(Vh,DictT,X),
        (X=v(K) ->
            write(St,'\t\tvar'),write(St,K),write(St,'=('),write(St,K),write(St,'<<TAG_WIDTH)+TAG_VREF'),write(St,'+(voffset<<TAG_WIDTH);\n'),
            write(St,'\t\tp.variables['),write(St,K),write(St,'+voffset]=TAG_VAR;\n'))
        ; true),
    (T=v(Vt) ->
        (member(Vt,Used1a) -> true ;
            nth0(Vt,DictT,v(K2)),
            write(St,'\t\tvar'),write(St,K2),write(St,'=('),write(St,K2),write(St,'<<TAG_WIDTH)+TAG_VREF'),write(St,'+(voffset<<TAG_WIDTH);\n'),
            write(St,'\t\tp.variables['),write(St,K2),write(St,'+voffset]=TAG_VAR;\n')),
        arg_to_atom_for_dict(DictT,Vh,Head),
        arg_to_atom_for_dict(DictT,Vt,Tail),
        %write(St,'\t\t'),write(St,N),write(St,'lc=p.plcreate_list('),
        %write_var_from_dictt(St,Vh,DictT),write(St,','),write_var_from_dictt(St,Vt,DictT),write(St,');\n')
        add_delayed_instruction(Sdict3,Sdict4,create_list([t(N,equal,'TAG_VREF')],N,Head,Tail))
    ; T=eol ->
        %write(St,N),write(St,'lc=p.plcreate_list('),write_var_from_dictt(St,Vh,DictT),write(St,',TAG_EOL);\n')
        arg_to_atom_for_dict(DictT,Vh,Head),
        add_delayed_instruction(Sdict3,Sdict4,create_list([t(N,equal,'TAG_VREF')],N,Head,'TAG_EOL'))
    ; false),
    %check_pointer_chase_notag(St,N,Sdict3,Sdict4),
    add_delayed_instruction(Sdict4,Sdictn,var_set_add_to_unwind_stack_var([t(N,equal,'TAG_VREF')],true,N,R)),
    %write(St,'\t\tp.var_set_add_to_unwind_stack('),write(St,N),write(St,'>>TAG_WIDTH,'),write(St,N),write(St,'lc);\n'),
    write(St,'\t\t} else {goto fail_'),write(St,Label),
    (Sdictn=state(_,_,_,true) -> true ; write(St,'_no_unwind')),
    write(St,';}\n').

compile_clause_body_args_with_comma(St,DictT,X) :- write(St,', '),compile_clause_body_args(St,DictT,X).

compile_clause_body_args(St,DictT,v(V)) :- write_var_from_dictt(St,V,DictT).
compile_clause_body_args(St,_,i(N)) :- write(St,'('),write(St,N),write(St,'<<TAG_WIDTH)+TAG_INTEGER').
compile_clause_body_args(St,_,eol) :- write(St,'TAG_EOL').
compile_clause_body_args(St,DictT,list(H,T)) :-
    write(St,'p.plcreate_list('),
    compile_clause_body_args(St,DictT,H),
    write(St,','),
    compile_clause_body_args(St,DictT,T),
    write(St,')').

compile_clause_body_args_prep_vars(St,DictT,v(V),Used1,Used2) :-
    (member(V,Used1) ->
        Used2=Used1
    ;   Used2=[V|Used1],
        nth0(V,DictT,v(K)),
        write(St,'\t\tvar'),write(St,K),write(St,'=('),write(St,K),write(St,'<<TAG_WIDTH)+TAG_VREF'),write(St,'+(voffset<<TAG_WIDTH);\n'),
        write(St,'\t\tp.variables['),write(St,K),write(St,'+voffset]=TAG_VAR;\n')).
compile_clause_body_args_prep_vars(_,_,i(_),Used,Used).
compile_clause_body_args_prep_vars(_,_,eol,Used,Used).
compile_clause_body_args_prep_vars(St,DictT,list(H,T),Used1,Used3) :-
    compile_clause_body_args_prep_vars(St,DictT,H,Used1,Used2),
    compile_clause_body_args_prep_vars(St,DictT,T,Used2,Used3).

compile_clause_get_expression(_,_,_,i(I),Name,UniqueId,UniqueId,Sdict1,Sdict1) :- atomics_to_string(['((',I,'<<TAG_WIDTH)+TAG_INTEGER)'],Name).
compile_clause_get_expression(St,DictT,Label,v(V),Name,UniqueId1,UniqueId2,Sdict1,Sdict2) :-
    UniqueId2 is UniqueId1,
    arg_to_atom_for_dict(DictT,V,Name),
    check_tag_var_type(St,Name,Sdict1,Sdict2,'TAG_INTEGER',Label).
compile_clause_get_expression(St,DictT,Label,function(add,A1,A2),Name,UniqueId1,UniqueId3,Sdict1,Sdict3) :-
    compile_clause_get_expression(St,DictT,Label,A1,Name1,UniqueId1,UniqueId2,Sdict1,Sdict2),
    compile_clause_get_expression(St,DictT,Label,A2,Name2,UniqueId2,UniqueId3,Sdict2,Sdict3),
    atomics_to_string(['(',Name1,'+',Name2,'-TAG_INTEGER)'],Name).

compile_clause_body(St,DictT,Label,Pdict,LP,ClauseCounts,fcall(Index,Args),Used1,Used2,UniqueId1,UniqueId2,Sdict0,Sdict2) :-
    do_process_delayed(St,Sdict0,Sdict1),
    nth0(Index,Pdict,f(Name,Arity)),
    nth0(Index,ClauseCounts,ClauseCountThis),
    (ClauseCountThis>1 ->
        (UniqueId2 is UniqueId1+1,
        write(St,'\t\t{\n'),
        foldl(compile_clause_body_args_prep_vars(St,DictT),Args,Used1,Used2),
        write(St,'\t\t\tuint32_t local_frame_top=p.frame_top;\n'),
        check_pointer_chase_notag_for_fcall_list(St,Args,DictT,Sdict1,Sdict2),
        write(St,'\t\t\tbool found='),write(St,Name),write(St,'_'),write(St,Arity),write(St,'(p'),
        maplist(compile_clause_body_args_with_comma(St,DictT),Args),
        write(St,', voffset_next, voffset_next, parent_frame);\n'),
        write(St,'\t\t\tp.pop_frame_stack_track_parent(parent_frame);\n'),
        write(St,'\t\t\tif(p.frame_top>=local_frame_top && !found) {\n'),
        (trace_mode -> write(St,'\t\t\tstd::cout << "=== loaded continuation " << p.frame_top << std::endl;\n') ; true),
        write(St,'\t\t\t\tp.process_stack_state_load_save(local_frame_top);\n'),
        write(St,'\t\t\t}\n'),
        write(St,'\t\t\tif(!found) {goto fail_'),write(St,Label),
        (Sdict2=state(_,_,_,true) -> true ; write(St,'_no_unwind')),
        write(St,';}\n'),
        write(St,'\t\t}\n'))
    ;   (UniqueId2=UniqueId1,
        (LP>1 -> write(St,'\t\tp.function_frame_top_last_n_clause=function_frame_top;\n') ; true),
        foldl(compile_clause_body_args_prep_vars(St,DictT),Args,Used1,Used2),
        check_pointer_chase_notag_for_fcall_list(St,Args,DictT,Sdict1,Sdict2),
        write(St,'\t\tbool found='),write(St,Name),write(St,'_'),write(St,Arity),write(St,'(p'),
        maplist(compile_clause_body_args_with_comma(St,DictT),Args),
        write(St,', voffset_next, voffset_next, parent_frame);\n'),
        (LP>1 -> write(St,'\t\tp.pop_frame_stack_track_parent(parent_frame);\n') ; true),
        write(St,'\t\tif(!found) {goto fail_'),write(St,Label),
        (Sdict2=state(_,_,_,true) -> true ; write(St,'_no_unwind')),
        write(St,';}\n'))
    ).
compile_clause_body(St,DictT,Label,_,_,_,function(test_neq,A1,A2),Used,Used,UniqueId1,UniqueId3,Sdict1,Sdict3) :-
    compile_clause_get_expression(St,DictT,Label,A1,Name1,UniqueId1,UniqueId2,Sdict1,Sdict2),
    compile_clause_get_expression(St,DictT,Label,A2,Name2,UniqueId2,UniqueId3,Sdict2,Sdict3),
    write(St,'\t\tif('),write(St,Name1),write(St,'=='),write(St,Name2),write(St,') {goto fail_'),write(St,Label),
    (Sdict3=state(_,_,_,true) -> true ; write(St,'_no_unwind')),
    write(St,';}\n').
compile_clause_body(St,DictT,Label,_,_,_,function(assign,v(V),A2),Used1,Used2,UniqueId1,UniqueId2,Sdict1,Sdict4) :-
    compile_clause_get_expression(St,DictT,Label,A2,Name2,UniqueId1,UniqueId2,Sdict1,Sdict2),
    (member(V,Used1) ->
        Used2=Used1,
        Sdict4=Sdict2,
        write(St,'\t\tif(!'),write_var_from_dictt(St,V,DictT),write(St,'!='),write(St,Name2),write(St,')) {goto fail_'),write(St,Label),
        (Sdict4=state(_,_,_,true) -> true ; write(St,'_no_unwind')),
        write(St,';}\n')
    ;
        Used2=[V|Used1],
        nth0(V,DictT,v(K)),
        atomic_concat(var,K,Name),
        write(St,'\t\t'),write(St,Name),write(St,'='),write(St,Name2),write(St,';\n'),
        check_pointer_chase_notag(St,Name,Sdict2,Sdict4),
        %add_delayed_instruction(Sdict2,Sdict4,var_set_add_to_unwind_stack_offset(true,K,Name))
        write(St,'\t\tp.var_set_add_to_unwind_stack('),write(St,K),write(St,'+voffset,'),write(St,Name),write(St,');\n')
    ).
