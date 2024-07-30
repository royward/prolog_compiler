CXX:=clang++

debug:
	@$(CXX) -ggdb3 -c -o Prolog.o Prolog.cpp
	@$(CXX) -ggdb3 -c -o Prolog_process_stack_state.o Prolog_process_stack_state.s
	@$(CXX) -ggdb3 -c -o PrologGenerated.o PrologGenerated.cpp
	@$(CXX) -ggdb3 -o test Prolog.o PrologGenerated.o Prolog_process_stack_state.o
