#include <stdio.h>
#include <stdlib.h>

#define N 14

int solutions = 0;

// This function checks if placing a queen at board[row][col] is safe
int isSafe(int board[], int row, int col) {
    for (int i = 0; i < row; i++) {
        if (board[i] == col ||                    // Check same column
            board[i] - i == col - row ||          // Check main diagonal
            board[i] + i == col + row) {          // Check anti-diagonal
            return 0;
        }
    }
    return 1;
}

// This function uses backtracking to place queens
void solveNQueens(int board[], int row) {
    if (row == N) {
        // If all queens are placed, print solution
        solutions++;
        printf("[");
		printf("%d,",board[0]);
        for (int i = 1; i < N; i++) {
            printf(",%d",board[i]);
        }
        printf("]\n");
        return;
    }

    for (int col = 0; col < N; col++) {
        if (isSafe(board, row, col)) {
            board[row] = col;
            solveNQueens(board, row + 1);  // Recur to place the rest of the queens
        }
    }
}

int main() {
    int board[N];  // Array to store the position of queens
    solveNQueens(board, 0);
    printf("Total solutions: %d\n", solutions);
    return 0;
}
