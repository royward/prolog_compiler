#include <stdio.h>

#define MAX_N 16

// Function to solve N-Queens iteratively
void solve(int n) {
    int board[MAX_N] = {0}; // Array to track queen positions
    int row = 0;           // Start at the first row
    int col = -1;           // Start at the first column
    int colmask=(1<<(n+1))-1;
    while (row >= 0) {
        // Find the next valid position in the current row
        col=__builtin_ctz(colmask&((-1)<<(col+1)));
        while(col < n) {
            for (int i = 0; i < row; i++) {
                int b = board[i];
                int d = row-i;
                if (b == col - d ||     // Same major diagonal
                    b == col + d) {     // Same minor diagonal
                    goto conflict;
                }
            }
            colmask -= (1<<col);
            board[row] = col; // Place the queen
            goto found_solution;
conflict:;
            col=__builtin_ctz(colmask&((-1)<<(col+1)));
        }
        row--;
        if (row >= 0) {
            col = board[row]; // Try the next column in the previous row
            colmask += (1<<col);
        }
        continue;
found_solution:
        // Move to the next row
        if (row == n - 1) {
            // Found a solution
            printf("[");
            printf("%d",board[0]);
            for (int i = 1; i < MAX_N; i++) {
                printf(",%d",board[i]);
            }
            printf("]\n");
            colmask += (1<<col);
            col = board[row]; // Backtrack
        } else {
            row++;
            col = -1; // Start from the first column in the next row
        }
    }
}

int main() {
    solve(MAX_N);
    return 0;
}
