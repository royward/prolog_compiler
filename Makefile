CXX:=clang++

OPT:= -ggdb3

debug:
	@$(CXX) $(OPT) -c -o Prolog.o Prolog.cpp
	@$(CXX) $(OPT) -c -o Prolog_process_stack_state.o Prolog_process_stack_state.s
	@$(CXX) $(OPT) -c -o PrologGenerated.o PrologGenerated.cpp
	@$(CXX) $(OPT) -z noexecstack -o test Prolog.o PrologGenerated.o Prolog_process_stack_state.o
