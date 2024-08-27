CXX:=g++

FLAGS:= -DUSE_AVX=1
OPT:= -ggdb3 -mavx
FAST:= -O3 -mavx

release:
	@$(CXX) $(FAST) $(FLAGS) -c -o Prolog.o Prolog.cpp
	@$(CXX) $(FAST) $(FLAGS) -c -o Prolog_process_stack_state.o Prolog_process_stack_state.S
	@$(CXX) $(FAST) $(FLAGS) -c -o PrologGenerated.o PrologGenerated.cpp
	@$(CXX) $(FAST) -z noexecstack -o test Prolog.o PrologGenerated.o Prolog_process_stack_state.o

debug:
	@$(CXX) $(OPT) $(FLAGS) -c -o Prolog.o Prolog.cpp
	@$(CXX) $(OPT) $(FLAGS) -c -o Prolog_process_stack_state.o Prolog_process_stack_state.S
	@$(CXX) $(OPT) $(FLAGS) -c -o PrologGenerated.o PrologGenerated.cpp
	@$(CXX) $(OPT) -z noexecstack -o test.debug Prolog.o PrologGenerated.o Prolog_process_stack_state.o
