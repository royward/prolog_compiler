CXX:=clang++

OPT:= -ggdb3

FAST:= -O3

debug:
	@$(CXX) $(OPT) -c -o Prolog.o Prolog.cpp
	@$(CXX) $(OPT) -c -o Prolog_process_stack_state.o Prolog_process_stack_state.s
	@$(CXX) $(OPT) -c -o PrologGenerated.o PrologGenerated.cpp
	@$(CXX) $(OPT) -z noexecstack -o test Prolog.o PrologGenerated.o Prolog_process_stack_state.o

release:
	@$(CXX) $(FAST) -c -o Prolog.o Prolog.cpp
	@$(CXX) $(FAST) -c -o Prolog_process_stack_state.o Prolog_process_stack_state.s
	@$(CXX) $(FAST) -c -o PrologGenerated.o PrologGenerated.cpp
	@$(CXX) $(FAST) -z noexecstack -o test.release Prolog.o PrologGenerated.o Prolog_process_stack_state.o
