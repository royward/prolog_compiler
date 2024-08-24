/*
compile(file("append.pl"),string("append([1,2],[3,4],X).")).
compile(file("append.pl"),string("append([1,2],X,[1,2,3,4]).")).
compile(file("append.pl"),string("append(X,[1],[2]).")).
compile(file("append.pl"),string("append(X,[3,4],[1,2,3,4]).")).
compile(file("append.pl"),string("append(X,Y,[1,2,3,4]).")).
compile(file("nqueens.pl"),string("queens(1,Q).")).
compile(file("nqueens.pl"),string("range(1,4,X).")).
compile(file("nqueens.pl"),string("queens_aux([1],[],Q).")).
compile(file("nqueens.pl"),string("selectx(X,[1],Y).")).
compile(file("nqueens.pl"),string("selectx(X,[1],Y).")).
compile(file("selectx.pl"),string("selectx(X,[1,2,3,4],Y).")).
compile(file("selectx.pl"),string("selecty(X,[1,2,3,4],Y).")).
compile(file("nqueens.pl"),string("queens(4,Q).")).
nb_setval(trace_mode,1).
*/

trace_mode(1).

compile(RawProgram,RawGoal) :-
    convert_program(RawProgram,Pdict,Program),
    convert_input(RawGoal,f(Name,Arity),Goal,InputDict),
    get_index_dict(f(Name,Arity),_,Pdict,_,_),
    length(InputDict,I1),
    open('PrologGenerated.cpp',write,St),
    write(St,'//////////////////////////////////////////////////////////////////////////////////////\n'),
    write(St,'// DO NOT EDIT THIS FILE. It is programmatically generated and WILL be overwritten. //\n'),
    write(St,'//////////////////////////////////////////////////////////////////////////////////////\n\n'),
    write(St,'#include "Prolog.h"\n\n'),
    maplist(write_function_template(St),Pdict),nl(St),
    maplist(write_frame_reference_template(St),Pdict,Program),nl(St),
    write(St,'void Prolog::__do_start() {\n'),
    foldl(setup_args(St),Goal,0,_),
    write(St,'\tFrameStore& frame=frames[frame_count++];\n'),
    %write(St,'\tframe.frame_index=0;\n'),
    write(St,'\tframe.clause_index=0;\n'),
    (trace_mode(1) -> write(St,'\tframe.call_depth=1;\n') ; true),
    write(St,'\tframe.clause_count='),write(St,Name),write(St,'_'),write(St,Arity),write(St,'_fri.count;\n'),
    %write(St,'\tframe.stack_top=base_sp=(uint8_t*)__builtin_frame_address(0);\n'),
    write(St,'\tbase_sp=(uint8_t*)__builtin_frame_address(0);\n'),
    write(St,'\tuint32_t dummy;\n'),
    write(St,'\twhile(frame_count>0) {\n'),
    write(St,'\t\tif('),write(St,Name),write(St,'_'),write(St,Arity),write(St,'(*this'),
    write_arg(St,', goal_args',0,Arity),
    write(St,', '),write(St,I1),write(St,', dummy, &frame)) {\n'),
    (InputDict=[] -> write(St,'\t\tstd::cout << "true." << std::endl;\n') ; foldl(do_output(St),InputDict,0,_)),
    write(St,'\t\t} else {\n'),
    write(St,'\t\t\tstd::cout << "false." << std::endl;\n'),
    write(St,'\t\t}\n'),
    write(St,'\t}\n'),
    write(St,'}\n'),
    maplist(compile_predicate(St,Pdict),Pdict,Program),
    close(St).

do_output(St,InputName,N,N1) :-
    N1 is N+1,
    write(St,'\t\t\tstd::cout << "'),write(St,InputName),write(St,' = " << '),write(St,'pldisplay(('),write(St,N),write(St,'<<TAG_WIDTH)+TAG_VREF) << std::endl;\n').
    
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
    write(St,'bool '),write(St,Name),write(St,'_'),write(St,Arity),write(St,'(Prolog& p'),
    write_arg(St,', uint32_t arg',0,Arity),
    write(St,', uint32_t voffset, uint32_t& voffset_new, FrameStore* fs'),
    write(St,');\n').

write_frame_reference_template(St,f(Name,Arity),Predicate) :-
    length(Predicate,LP),
    write(St,'static FrameReferenceInfo '),write(St,Name),write(St,'_'),write(St,Arity),write(St,'_fri('),write(St,LP),write(St,');\n').
     
compile_predicate(St,Pdict,f(Name,Arity),Predicate) :-
    length(Predicate,LP),
    nl(St),write(St,'bool '),write(St,Name),write(St,'_'),write(St,Arity),write(St,'(Prolog& p'),
    write_arg(St,', uint32_t arg',0,Arity),
    write(St,', uint32_t voffset, uint32_t& voffset_new, FrameStore* fs) {\n'),
    (Arity>0 -> write(St,'\tuint8_t tag_arg0'),compile_clause_args_setup_vars(St,', tag_arg',1,Arity),write(St,';\n') ; true),
    write(St,'\tbool setup_bool=(fs->clause_index==0);\n'),
    write(St,'\tif(setup_bool) {\n'),
    compile_clause_args_pointer_chase(St,Arity,0),
    write(St,'\t\tp.unwind_stack_mark();\n'),
    write(St,'\t}\n'),
    (trace_mode(1) -> write(St,'if(setup_bool) std::cout << "=== saved continuation " << p.frame_count << std::endl; else std::cout << "=== loaded continuation " << p.frame_count << std::endl;\n') ; true),
    write(St,'\tfs=p.process_stack_state_load_save(setup_bool?fs:nullptr);\n'),
    (trace_mode(1) ->
        write(St,'\t std::cout << fs->call_depth << \':\' << "'),write(St,Name),write(St,'/" << '),write(St,Arity),
        write_arg2(St,' << \',\' << p.pldisplay(arg',')',0,Arity),
        write(St,' << " c=" << fs->clause_index << std::endl;\n')
    ; true),
    (LP>1 -> write(St,'\tswitch(fs->clause_index) {\n') ; true),
    foldl(compile_clause(St,Pdict,LP),Predicate,0,_),
    (LP>1 -> write(St,'\t}\n') ; true),
    write(St,'\tp.pop_frame_stack(fs);\n'),
    write(St,'\tvoffset_new=voffset;\n'),
    write(St,'\tp.top_unwind_stack_decouple_mark--;\n'),
    write(St,'\treturn false;\n'),
    write(St,'}\n').

compile_clause(St,Pdict,LP,clause(Dict,_,Args,Body),NClause,NClause1) :-
    NClause1 is NClause+1,
    (LP>1 -> write(St,'\t\tcase '),write(St,NClause),write(St,': {\n') ; true),
    write(St,'\t\t\tfs->clause_index++;\n'),
    length(Dict,LD),
    write(St,'\t\t\tuint32_t voffset_next=voffset+'),write(St,LD),write(St,';\n'),
    (LD>0 -> write(St,'\t\t\tuint32_t var0'),compile_clause_args_setup_vars(St,', var',1,LD),write(St,';\n') ; true),
    atomics_to_string(['label_c',NClause],Label),
    fold2(compile_clause_args1(St,Label),Args,0,_,[],Used1),
    foldl(compile_clause_body_args_prep_vars(St),Args,Used1,Used2),
    fold2(compile_clause_body(St,Label,Pdict),Body,Used2,_,0,_),
    write(St,'\t\t\tvoffset_new=voffset_next;\n'),
    write(St,'\t\tp.pop_frame_stack(fs);\n'),
    write(St,'\t\t\treturn true;\n'),
    write(St,'fail_'),write(St,Label),write(St,':;\n'),
    write(St,'\t\t\tp.unwind_stack_revert_to_mark();\n'),
    (LP>1 -> write(St,'\t\t}\n') ; true).

compile_clause_args_setup_vars(_,_,N,N).
compile_clause_args_setup_vars(St,S,M,N) :- M<N,write(St,S),write(St,M),M1 is M+1,compile_clause_args_setup_vars(St,S,M1,N).

compile_clause_args_pointer_chase(_,Arity,Arity).
compile_clause_args_pointer_chase(St,Arity,N) :-
    N<Arity,
    N1 is N+1,
    write(St,'\t\tp.pointer_chase(tag_arg'),write(St,N),write(St,',arg'),write(St,N),write(St,');\n'),
    compile_clause_args_pointer_chase(St,Arity,N1).    

compile_clause_args1(St,Label,X,N,N1,Used1,Used2) :-
    N1 is N+1,
    atomics_to_string(['arg',N],Argname),
    compile_clause_args1_aux(St,Label,X,Argname,Used1,Used2).

compile_clause_args1_aux(St,Label,X,N,Used1,Used2) :-
    compile_clause_args1_aux2(St,Label,X,N,Used1,Used2),
    write(St,'s_'),write(St,Label),write(St,'_'),write(St,N),write(St,':;\n').

compile_clause_args1_aux2(St,Label,eol,N,Used1,Used1) :-
    write(St,'\t\t\tif(tag_'),write(St,N),write(St,'==TAG_EOL) {goto s_'),write(St,Label),write(St,'_'),write(St,N),write(St,';}\n'),
    write(St,'\t\t\tif(tag_'),write(St,N),write(St,'!=TAG_VREF) {goto fail_'),write(St,Label),write(St,';}\n'),
    write(St,'\t\t\tp.variables['),write(St,N),write(St,'>>TAG_WIDTH]=TAG_EOL;\n'),
    write(St,'\t\t\tp.unwind_stack_decouple[p.top_unwind_stack_decouple++]='),write(St,N),write(St,'>>TAG_WIDTH;\n').
compile_clause_args1_aux2(St,Label,i(I),N,Used1,Used1) :-
    write(St,'\t\t\tif('),write(St,N),write(St,'==('),write(St,I),write(St,'<<TAG_WIDTH)+TAG_INTEGER) {goto s_'),write(St,Label),write(St,'_'),write(St,N),write(St,';}\n'),
    write(St,'\t\t\tif(tag_'),write(St,N),write(St,'!=TAG_VREF) {goto fail_'),write(St,Label),write(St,';}\n'),
    write(St,'\t\t\tp.variables['),write(St,N),write(St,'>>TAG_WIDTH]=('),write(St,I),write(St,'<<TAG_WIDTH)+TAG_INTEGER;\n'),
    write(St,'\t\t\tp.unwind_stack_decouple[p.top_unwind_stack_decouple++]='),write(St,N),write(St,'>>TAG_WIDTH;\n').
compile_clause_args1_aux2(St,Label,v(V),N,Used1,Used2) :-
    (member(V,Used1) ->
        Used2=Used1,
        write(St,'\t\t\tif(!p.unify(var'),write(St,V),write(St,','),write(St,N),write(St,')) {goto fail_'),write(St,Label),write(St,';}\n')
    ;
        Used2=[V|Used1],
        write(St,'\t\t\tvar'),write(St,V),write(St,'='),write(St,N),write(St,';\n'),
        write(St,'\t\t\tp.variables['),write(St,V),write(St,'+voffset]='),write(St,N),write(St,';\n'),
        write(St,'\t\t\tp.unwind_stack_decouple[p.top_unwind_stack_decouple++]='),write(St,V),write(St,'+voffset;\n')
    ).
compile_clause_args1_aux2(St,Label,list(H,T),N,Used1,Used3) :-
    H=v(Vh),
    atomics_to_string([N,'h'],ArgH),
    atomics_to_string([N,'t'],ArgT),
    write(St,'\t\t\tuint32_t '),write(St,ArgH),write(St,', '),write(St,ArgT),write(St,';\n'),
    write(St,'\t\t\tif(tag_'),write(St,N),write(St,'==TAG_LIST) {\n'),
    write(St,'\t\t\tList& '),write(St,N),write(St,'l=p.list_values['),write(St,N),write(St,'>>TAG_WIDTH];\n'),
    write(St,'\t\t\t'),write(St,ArgH),write(St,'='),write(St,N),write(St,'l.head;\n'),
    write(St,'\t\t\tuint8_t tag_'),write(St,ArgH),write(St,';\n'),
    write(St,'\t\t\tp.pointer_chase(tag_'),write(St,ArgH),write(St,','),write(St,ArgH),write(St,');\n'),
    compile_clause_args1_aux(St,Label,H,ArgH,Used1,Used2),
    write(St,'\t\t\t'),write(St,ArgT),write(St,'='),write(St,N),write(St,'l.tail;\n'),
    write(St,'\t\t\tuint8_t tag_'),write(St,ArgT),write(St,';\n'),
    write(St,'\t\t\tp.pointer_chase(tag_'),write(St,ArgT),write(St,','),write(St,ArgT),write(St,');\n'),
    compile_clause_args1_aux(St,Label,T,ArgT,Used2,Used3),
    write(St,'\t\t\t} else if(tag_'),write(St,N),write(St,'==TAG_VREF) {\n'),
    (member(Vh,Used1) -> Used1a=Used1 ; 
        Used1a=[Vh|Used1],
        write(St,'\t\t\tvar'),write(St,Vh),write(St,'=('),write(St,Vh),write(St,'<<TAG_WIDTH)+TAG_VREF'),write(St,'+(voffset<<TAG_WIDTH);\n'),
        write(St,'\t\t\tp.variables['),write(St,Vh),write(St,'+voffset]=0;\n')),
    (T=v(Vt) ->
        (member(Vt,Used1a) -> true ; 
            write(St,'\t\t\tvar'),write(St,Vt),write(St,'=('),write(St,Vt),write(St,'<<TAG_WIDTH)+TAG_VREF'),write(St,'+(voffset<<TAG_WIDTH);\n'),
            write(St,'\t\t\tp.variables['),write(St,Vt),write(St,'+voffset]=0;\n')),
        write(St,'\t\t\tuint32_t '),write(St,N),write(St,'lc=p.plcreate_list('),write(St,'var'),write(St,Vh),write(St,','),write(St,'var'),write(St,Vt),write(St,');\n')
    ; T=eol ->
        write(St,'\t\t\tuint32_t '),write(St,N),write(St,'lc=p.plcreate_list('),write(St,'var'),write(St,Vh),write(St,',TAG_EOL);\n')
    ; false),
    write(St,'\t\t\tp.variables['),write(St,N),write(St,'>>TAG_WIDTH]='),write(St,N),write(St,'lc;\n'),
    write(St,'\t\t\tp.unwind_stack_decouple[p.top_unwind_stack_decouple++]='),write(St,N),write(St,'lc>>TAG_WIDTH;\n'),
    write(St,'\t\t\t'),write(St,N),write(St,'='),write(St,N),write(St,'lc;\n'),
    write(St,'\t\t\t} else {goto fail_'),write(St,Label),write(St,';}\n').

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
        write(St,'\t\t\tvar'),write(St,V),write(St,'=('),write(St,V),write(St,'<<TAG_WIDTH)+TAG_VREF'),write(St,'+(voffset<<TAG_WIDTH);\n'),
        write(St,'\t\t\tp.variables['),write(St,V),write(St,'+voffset]=0;\n')).
        
compile_clause_body_args_prep_vars(_,i(_),Used,Used).
compile_clause_body_args_prep_vars(_,eol,Used,Used).
compile_clause_body_args_prep_vars(St,list(H,T),Used1,Used3) :-
    compile_clause_body_args_prep_vars(St,H,Used1,Used2),
    compile_clause_body_args_prep_vars(St,T,Used2,Used3).

compile_clause_get_expression(_,_,i(I),Name,UniqueId,UniqueId) :- atomics_to_string(['((',I,'<<TAG_WIDTH)+TAG_INTEGER)'],Name).
compile_clause_get_expression(St,Label,v(V),Name,UniqueId1,UniqueId2) :-
    UniqueId2 is UniqueId1+1,
    write(St,'\t\t\tuint8_t tag_'),write(St,UniqueId1),write(St,'_var'),write(St,V),write(St,';\n'),
    write(St,'\t\t\tp.pointer_chase(tag_'),write(St,UniqueId1),write(St,'_var'),write(St,V),write(St,',var'),write(St,V),write(St,');\n'),
    write(St,'\t\t\tif((var'),write(St,V),write(St,'&TAG_MASK)!=TAG_INTEGER) {goto fail_'),write(St,Label),write(St,';}\n'),
    atomics_to_string(['var',V],Name).
compile_clause_get_expression(St,Label,function(add,A1,A2),Name,UniqueId1,UniqueId3) :-
    compile_clause_get_expression(St,Label,A1,Name1,UniqueId1,UniqueId2),
    compile_clause_get_expression(St,Label,A2,Name2,UniqueId2,UniqueId3),
    atomics_to_string(['(',Name1,'+',Name2,'-TAG_INTEGER)'],Name).

compile_clause_body(St,Label,Pdict,fcall(Index,Args),Used1,Used2,UniqueId1,UniqueId2) :-
    UniqueId2 is UniqueId1+1,
    nth0(Index,Pdict,f(Name,Arity)),
    write(St,'\t\t\t{\n'),
    write(St,'\t\t\t\tFrameStore& frame'),write(St,UniqueId1),write(St,'=p.frames[p.frame_count++];\n'),
    %write(St,'\t\t\t\tframe'),write(St,UniqueId1),write(St,'.frame_index=fs->frame_index+1;\n'),
    write(St,'\t\t\t\tframe'),write(St,UniqueId1),write(St,'.clause_index=0;\n'),
    write(St,'\t\t\t\tframe'),write(St,UniqueId1),write(St,'.clause_count='),write(St,Name),write(St,'_'),write(St,Arity),write(St,'_fri.count;\n'),
    %write(St,'\t\t\t\tframe'),write(St,UniqueId1),write(St,'.stack_top=fs->stack_bottom;\n'),
    (trace_mode(1) -> write(St,'\t\t\t\tframe'),write(St,UniqueId1),write(St,'.call_depth=fs->call_depth+1;\n') ; true),
    foldl(compile_clause_body_args_prep_vars(St),Args,Used1,Used2),
    write(St,'\t\t\t\tuint32_t local_frame_count=p.frame_count;\n'),
    write(St,'\t\t\t\tbool found=false;\n'),
    write(St,'\t\t\t\twhile(p.frame_count>=local_frame_count && !found) {\n'),
    write(St,'\t\t\t\t\tfound='),write(St,Name),write(St,'_'),write(St,Arity),write(St,'(p'),
    maplist(compile_clause_body_args_with_comma(St),Args),
    write(St,', voffset_next, voffset_next, &frame'),write(St,UniqueId1),write(St,');\n'),
    write(St,'\t\t\t\t}\n'),
    write(St,'\t\t\t\tif(!found) {goto fail_'),write(St,Label),write(St,';}\n'),
    write(St,'\t\t\t}\n').
compile_clause_body(St,Label,_,function(test_neq,A1,A2),Used,Used,UniqueId1,UniqueId3) :-
    compile_clause_get_expression(St,Label,A1,Name1,UniqueId1,UniqueId2),
    compile_clause_get_expression(St,Label,A2,Name2,UniqueId2,UniqueId3),
    write(St,'\t\t\tif('),write(St,Name1),write(St,'=='),write(St,Name2),write(St,') {goto fail_'),write(St,Label),write(St,';}\n').
compile_clause_body(St,Label,_,function(assign,v(V),A2),Used1,Used2,UniqueId1,UniqueId2) :-
    compile_clause_get_expression(St,Label,A2,Name2,UniqueId1,UniqueId2),
    (member(V,Used1) ->
        Used2=Used1,
        write(St,'\t\t\tif(!var'),write(St,V),write(St,'!='),write(St,Name2),write(St,')) {goto fail_'),write(St,Label),write(St,';}\n')
    ;
        Used2=[V|Used1],
        write(St,'\t\t\tvar'),write(St,V),write(St,'='),write(St,Name2),write(St,';\n'),
        write(St,'\t\t\tp.variables['),write(St,V),write(St,'+voffset]=var'),write(St,V),write(St,';\n'),
        write(St,'\t\t\tp.unwind_stack_decouple[p.top_unwind_stack_decouple++]='),write(St,V),write(St,'+voffset;\n')
    ).
