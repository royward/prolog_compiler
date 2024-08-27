# Prolog Compiler: A Proof of Concept for writing a prolog compiler

This guide provides instructions on setting up and using the Prolog compiler within the SWI-Prolog environment. The compiler is designed to transpile Prolog code into C++ executables.

## Prerequisites

- SWI-Prolog
- GNU Make
- C++ Compiler (e.g., GCC or Clang)
- Standard development tools (e.g., `gcc`, `make`)

## Usage Guide

### 1. Installing Required Packages

Before starting, you need to install the `dcg4pt` package within SWI-Prolog:

```prolog
?- pack_install(dcg4pt).
```

Having `dcg4pt` properly installed and working is essential before attempting to install or use additional tools like `plammar`.

### 2. Editing the `dcg4pt.pl` File (Required for Compatibility)

In order to ensure compatibility with newer versions of SWI-Prolog, you may need to edit the `dcg4pt.pl` file:

1. Open the `dcg4pt.pl` file for editing:

   ```bash
   <EDITOR> ~/.local/share/swi-prolog/pack/dcg4pt/prolog/dcg4pt.pl
   ```

2. Locate the two spots where an unquoted comma `(,)` is used. Replace the unquoted comma with a quoted one `(',')` to make the code compatible with SWI-Prolog.

3. Save the file and exit the editor.

### 3. Installing `plammar`

After making the necessary edits to `dcg4pt`, you can now proceed to install `plammar`:

```prolog
?- pack_install(plammar).
```

### 4. Transpiling Prolog Files to C++

Start by launching SWI-Prolog with your custom files:

This command loads the `interpreter.pl` and `compiler.pl` files, which are required for the compilation process.

```bash
swipl -l interpreter.pl -l compiler.pl
```

To transpile a Prolog file to C++, use the `compile/2` predicate. It takes two arguments: the file name and a test query as a string.

Example:

```prolog
?- compile(file("nqueens.pl"), string("queens(4, Q).")).
true.
```

You can modify the file and query string as needed for different predicates. Here are some sample queries:

```prolog
% Sample queries
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

```

### 5. Generating the C++ File

The compilation process generates a C++ file named `PrologGenerated.cpp`, which contains the translated code.

To inspect the generated file and compile it, run:

```bash
cat PrologGenerated.cpp
make
```

### 6. Running the Compiled Binary

Once compiled, run the generated binary to see the output of your Prolog queries:

```bash
./test
```

### Common Issues

- **Compatibility Warning:** Newer versions of SWI-Prolog may break compatibility with specific custom Prolog constructs like `dcg4pt`. Ensure compatibility by editing the `dcg4pt.pl` file as described above.
- **Directory Requirements:** Ensure that your files are in the correct directory structure as expected by the SWI-Prolog `pack` system, or adjust your environment accordingly.
