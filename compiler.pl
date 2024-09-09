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
compile(file("selectx.pl"),string("selecty(X,[1,2,3,4],Y).")).
compile(file("nqueens.pl"),string("nqueens(4,Q).")).
compile(file("nqueens.pl"),string("nqueens(8,Q).")).
compile(file("nqueens.pl"),string("nqueens(12,Q).")).
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
    (Arity>0 -> write(St,'\tuint8_t tag_arg0'),compile_clause_args_setup_vars(St,', tag_arg',1,Arity),write(St,';\n') ; true),
    compile_clause_args_pointer_chase(St,Arity,0),
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

compile_clause(Name,Arity,St,Pdict,ClauseCounts,LP,clause(Dict,Args,Body),MRow,NClause,NClause1) :-
    NClause1 is NClause+1,
    (LP>1 -> write(St,'\t{\n') ; true),
    length(Dict,LD),
    write(St,'\t\tuint32_t voffset_next=voffset+'),write(St,LD),write(St,';\n'),
    (LD>0 -> write(St,'\t\tuint32_t var0'),compile_clause_args_setup_vars(St,', var',1,LD),write(St,';\n') ; true),
    atomics_to_string(['label_c',NClause],Label),
    fold2(compile_clause_args1(St,Label),Args,0,_,[],Used1),
    (LP>1 ->
        (NClause1\=LP ->
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
            (trace_mode ->
                write(St,'\t\t\t} else {\n'),
                write(St,'\t\t\t\tstd::cout << "=== saved continuation " << p.frame_top << std::endl;\n')
            ; true),
            write(St,'\t\t\t}\n'),
            write(St,'\t\t}\n')
        ;   true)
    ; true),
    foldl(compile_clause_body_args_prep_vars(St),Args,Used1,Used2),
    fold2(compile_clause_body(St,Label,Pdict,LP,ClauseCounts),Body,Used2,_,0,_),
    write(St,'\t\tvoffset_new=voffset_next;\n'),
    %(LP>1 -> write(St,'\t\tp.pop_frame_stack();\n') ; true),
    (trace_mode,LP>1 ->
        write(St,'\t std::cout << '),(LP>1 -> write(St,'(int)((fs==nullptr)?-1:fs->call_depth)') ; write(St,'0')),write(St,' << \':\' << "<'),
        write(St,Name),write(St,'"'),
        write_arg2(St,' << \',\' << p.pldisplay(arg',')',0,Arity),
        write(St,' << " c=" << (int)((fs==nullptr)?-1:fs->clause_index-1) << std::endl;\n')
    ; true),
    write(St,'\t\treturn true;\n'),
    write(St,'fail_'),write(St,Label),write(St,':;\n'),
    (LP>1,NClause1\=LP -> write(St,'\t\tif(fs!=nullptr)fs->clause_index++;\n') ; true),
    write(St,'\t\tp.unwind_stack_revert_to_mark(unwind_stack_decouple_mark,function_frame_top,parent_frame);\n'),
    (LP>1 -> write(St,'\t}\n') ; true),
    write(St,'next_'),write(St,Label),write(St,':;\n').

compile_clause_args_setup_vars(_,_,N,N).
compile_clause_args_setup_vars(St,S,M,N) :- M<N,write(St,S),write(St,M),M1 is M+1,compile_clause_args_setup_vars(St,S,M1,N).

compile_clause_args_pointer_chase(_,Arity,Arity).
compile_clause_args_pointer_chase(St,Arity,N) :-
    N<Arity,
    N1 is N+1,
    write(St,'\tp.pointer_chase(tag_arg'),write(St,N),write(St,',arg'),write(St,N),write(St,');\n'),
    compile_clause_args_pointer_chase(St,Arity,N1).    

compile_clause_args1(St,Label,X,N,N1,Used1,Used2) :-
    N1 is N+1,
    atomics_to_string(['arg',N],Argname),
    compile_clause_args1_aux(St,Label,X,Argname,Used1,Used2).

compile_clause_args1_aux(St,Label,X,N,Used1,Used2) :-
    compile_clause_args1_aux2(St,Label,X,N,Used1,Used2),
    write(St,'s_'),write(St,Label),write(St,'_'),write(St,N),write(St,':;\n').

compile_clause_args1_aux2(St,Label,eol,N,Used1,Used1) :-
    write(St,'\t\tif(tag_'),write(St,N),write(St,'==TAG_EOL) {goto s_'),write(St,Label),write(St,'_'),write(St,N),write(St,';}\n'),
    write(St,'\t\tif(tag_'),write(St,N),write(St,'!=TAG_VREF) {goto fail_'),write(St,Label),write(St,';}\n'),
    write(St,'\t\tp.var_set_add_to_unwind_stack('),write(St,N),write(St,'>>TAG_WIDTH,TAG_EOL);\n').
compile_clause_args1_aux2(St,Label,i(I),N,Used1,Used1) :-
    write(St,'\t\tif('),write(St,N),write(St,'==('),write(St,I),write(St,'<<TAG_WIDTH)+TAG_INTEGER) {goto s_'),write(St,Label),write(St,'_'),write(St,N),write(St,';}\n'),
    write(St,'\t\tif(tag_'),write(St,N),write(St,'!=TAG_VREF) {goto fail_'),write(St,Label),write(St,';}\n'),
    write(St,'\t\tp.var_set_add_to_unwind_stack('),write(St,N),write(St,'>>TAG_WIDTH,'),write(St,I),write(St,');\n').
compile_clause_args1_aux2(St,Label,v(V),N,Used1,Used2) :-
    (member(V,Used1) ->
        Used2=Used1,
        write(St,'\t\tif(!p.unify(var'),write(St,V),write(St,','),write(St,N),write(St,')) {goto fail_'),write(St,Label),write(St,';}\n')
    ;
        Used2=[V|Used1],
        write(St,'\t\tvar'),write(St,V),write(St,'='),write(St,N),write(St,';\n'),
        write(St,'\t\tp.var_set_add_to_unwind_stack('),write(St,V),write(St,'+voffset,'),write(St,N),write(St,');\n')
    ).
compile_clause_args1_aux2(St,Label,list(H,T),N,Used1,Used3) :-
    H=v(Vh),
    atomics_to_string([N,'h'],ArgH),
    atomics_to_string([N,'t'],ArgT),
    write(St,'\t\tuint32_t '),write(St,ArgH),write(St,', '),write(St,ArgT),write(St,';\n'),
    write(St,'\t\tif(tag_'),write(St,N),write(St,'==TAG_LIST) {\n'),
    write(St,'\t\tList& '),write(St,N),write(St,'l=p.list_values['),write(St,N),write(St,'>>TAG_WIDTH];\n'),
    write(St,'\t\t'),write(St,ArgH),write(St,'='),write(St,N),write(St,'l.head;\n'),
    write(St,'\t\tuint8_t tag_'),write(St,ArgH),write(St,';\n'),
    write(St,'\t\tp.pointer_chase(tag_'),write(St,ArgH),write(St,','),write(St,ArgH),write(St,');\n'),
    compile_clause_args1_aux(St,Label,H,ArgH,Used1,Used2),
    write(St,'\t\t'),write(St,ArgT),write(St,'='),write(St,N),write(St,'l.tail;\n'),
    write(St,'\t\tuint8_t tag_'),write(St,ArgT),write(St,';\n'),
    write(St,'\t\tp.pointer_chase(tag_'),write(St,ArgT),write(St,','),write(St,ArgT),write(St,');\n'),
    compile_clause_args1_aux(St,Label,T,ArgT,Used2,Used3),
    write(St,'\t\t} else if(tag_'),write(St,N),write(St,'==TAG_VREF) {\n'),
    (member(Vh,Used1) -> Used1a=Used1 ; 
        Used1a=[Vh|Used1],
        write(St,'\t\tvar'),write(St,Vh),write(St,'=('),write(St,Vh),write(St,'<<TAG_WIDTH)+TAG_VREF'),write(St,'+(voffset<<TAG_WIDTH);\n'),
        write(St,'\t\tp.variables['),write(St,Vh),write(St,'+voffset]=TAG_VAR;\n')),
    (T=v(Vt) ->
        (member(Vt,Used1a) -> true ; 
            write(St,'\t\tvar'),write(St,Vt),write(St,'=('),write(St,Vt),write(St,'<<TAG_WIDTH)+TAG_VREF'),write(St,'+(voffset<<TAG_WIDTH);\n'),
            write(St,'\t\tp.variables['),write(St,Vt),write(St,'+voffset]=TAG_VAR;\n')),
        write(St,'\t\tuint32_t '),write(St,N),write(St,'lc=p.plcreate_list('),write(St,'var'),write(St,Vh),write(St,','),write(St,'var'),write(St,Vt),write(St,');\n')
    ; T=eol ->
        write(St,'\t\tuint32_t '),write(St,N),write(St,'lc=p.plcreate_list('),write(St,'var'),write(St,Vh),write(St,',TAG_EOL);\n')
    ; false),
    write(St,'\t\tp.var_set_add_to_unwind_stack('),write(St,N),write(St,'>>TAG_WIDTH,'),write(St,N),write(St,'lc);\n'),
    write(St,'\t\t} else {goto fail_'),write(St,Label),write(St,';}\n').

compile_clause_body_args_with_comma(St,X) :- write(St,', '),compile_clause_body_args(St,X).

compile_clause_body_args(St,v(V)) :- write(St,'var'),write(St,V).
compile_clause_body_args(St,i(N)) :- write(St,'('),write(St,N),write(St,'<<TAG_WIDTH)+TAG_INTEGER').
compile_clause_body_args(St,eol) :- write(St,'TAG_EOL').
compile_clause_body_args(St,list(H,T)) :-
    write(St,'p.plcreate_list('),
    compile_clause_body_args(St,H),
    write(St,','),
    compile_clause_body_args(St,T),
    write(St,')').

compile_clause_body_args_prep_vars(St,v(V),Used1,Used2) :-
    (member(V,Used1) ->
        Used2=Used1
    ;   Used2=[V|Used1],
        write(St,'\t\tvar'),write(St,V),write(St,'=('),write(St,V),write(St,'<<TAG_WIDTH)+TAG_VREF'),write(St,'+(voffset<<TAG_WIDTH);\n'),
        write(St,'\t\tp.variables['),write(St,V),write(St,'+voffset]=TAG_VAR;\n')).
        
compile_clause_body_args_prep_vars(_,i(_),Used,Used).
compile_clause_body_args_prep_vars(_,eol,Used,Used).
compile_clause_body_args_prep_vars(St,list(H,T),Used1,Used3) :-
    compile_clause_body_args_prep_vars(St,H,Used1,Used2),
    compile_clause_body_args_prep_vars(St,T,Used2,Used3).

compile_clause_get_expression(_,_,i(I),Name,UniqueId,UniqueId) :- atomics_to_string(['((',I,'<<TAG_WIDTH)+TAG_INTEGER)'],Name).
compile_clause_get_expression(St,Label,v(V),Name,UniqueId1,UniqueId2) :-
    UniqueId2 is UniqueId1+1,
    write(St,'\t\tuint8_t tag_'),write(St,UniqueId1),write(St,'_var'),write(St,V),write(St,';\n'),
    write(St,'\t\tp.pointer_chase(tag_'),write(St,UniqueId1),write(St,'_var'),write(St,V),write(St,',var'),write(St,V),write(St,');\n'),
    write(St,'\t\tif((var'),write(St,V),write(St,'&TAG_MASK)!=TAG_INTEGER) {goto fail_'),write(St,Label),write(St,';}\n'),
    atomics_to_string(['var',V],Name).
compile_clause_get_expression(St,Label,function(add,A1,A2),Name,UniqueId1,UniqueId3) :-
    compile_clause_get_expression(St,Label,A1,Name1,UniqueId1,UniqueId2),
    compile_clause_get_expression(St,Label,A2,Name2,UniqueId2,UniqueId3),
    atomics_to_string(['(',Name1,'+',Name2,'-TAG_INTEGER)'],Name).

compile_clause_body(St,Label,Pdict,LP,ClauseCounts,fcall(Index,Args),Used1,Used2,UniqueId1,UniqueId2) :-
    nth0(Index,Pdict,f(Name,Arity)),
    nth0(Index,ClauseCounts,ClauseCountThis),
    (ClauseCountThis>1 ->
        (UniqueId2 is UniqueId1+1,
        write(St,'\t\t{\n'),
        foldl(compile_clause_body_args_prep_vars(St),Args,Used1,Used2),
        write(St,'\t\t\tuint32_t local_frame_top=p.frame_top;\n'),
        write(St,'\t\t\tbool found='),write(St,Name),write(St,'_'),write(St,Arity),write(St,'(p'),
        maplist(compile_clause_body_args_with_comma(St),Args),
        write(St,', voffset_next, voffset_next, parent_frame);\n'),
        write(St,'\t\t\tp.pop_frame_stack_track_parent(parent_frame);\n'),
        write(St,'\t\t\tif(p.frame_top>=local_frame_top && !found) {\n'),
        (trace_mode -> write(St,'\t\t\tstd::cout << "=== loaded continuation " << p.frame_top << std::endl;\n') ; true),
        write(St,'\t\t\t\tp.process_stack_state_load_save(local_frame_top);\n'),
        write(St,'\t\t\t}\n'),
        write(St,'\t\t\tif(!found) {goto fail_'),write(St,Label),write(St,';}\n'),
        write(St,'\t\t}\n'))
    ;   (UniqueId2=UniqueId1,
        (LP>1 -> write(St,'\t\tp.function_frame_top_last_n_clause=function_frame_top;\n') ; true),
        foldl(compile_clause_body_args_prep_vars(St),Args,Used1,Used2),
        write(St,'\t\tbool found='),write(St,Name),write(St,'_'),write(St,Arity),write(St,'(p'),
        maplist(compile_clause_body_args_with_comma(St),Args),
        write(St,', voffset_next, voffset_next, parent_frame);\n'),
        write(St,'\t\tp.pop_frame_stack_track_parent(parent_frame);\n'),
        write(St,'\t\tif(!found) {goto fail_'),write(St,Label),write(St,';}\n'))
    ).
compile_clause_body(St,Label,_,_,_,function(test_neq,A1,A2),Used,Used,UniqueId1,UniqueId3) :-
    compile_clause_get_expression(St,Label,A1,Name1,UniqueId1,UniqueId2),
    compile_clause_get_expression(St,Label,A2,Name2,UniqueId2,UniqueId3),
    write(St,'\t\tif('),write(St,Name1),write(St,'=='),write(St,Name2),write(St,') {goto fail_'),write(St,Label),write(St,';}\n').
compile_clause_body(St,Label,_,_,_,function(assign,v(V),A2),Used1,Used2,UniqueId1,UniqueId2) :-
    compile_clause_get_expression(St,Label,A2,Name2,UniqueId1,UniqueId2),
    (member(V,Used1) ->
        Used2=Used1,
        write(St,'\t\tif(!var'),write(St,V),write(St,'!='),write(St,Name2),write(St,')) {goto fail_'),write(St,Label),write(St,';}\n')
    ;
        Used2=[V|Used1],
        write(St,'\t\tvar'),write(St,V),write(St,'='),write(St,Name2),write(St,';\n'),
        write(St,'\t\tp.var_set_add_to_unwind_stack('),write(St,V),write(St,'+voffset,'),write(St,V),write(St,');\n')
    ).
