#include <stdio.h>
#include <stdint.h>
#include <emmintrin.h>
#include <immintrin.h>

#define MAX_N 16

// Function to solve N-Queens iteratively
int solve(int n) {
    int solutions=0;
    __m128i diffs = _mm_set_epi8(16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1);
    __m128i diffsn = _mm_sub_epi8(_mm_setzero_si128(),diffs);
    __m128i vboard = _mm_set1_epi8(127);
    int row = 0;           // Start at the first row
    int col = -1;           // Start at the first column
    int colmask=(1<<(n+1))-1;
    while (row >= 0) {
        // Find the next valid position in the current row
        col=__builtin_ctz(colmask&(0xFFFFFFFFFFFFFFFFULL<<(col+1)));
        while(col < n) {
            __m128i t=_mm_sub_epi8(vboard,_mm_set1_epi8(col));
            __m128i c=_mm_or_si128(_mm_cmpeq_epi8(t,diffs),_mm_cmpeq_epi8(t,diffsn));
            if(!_mm_test_all_zeros(c,c)) {
                goto conflict;
            }
            colmask -= (1<<col);
            vboard=_mm_insert_epi8(_mm_bslli_si128(vboard,1),col,0);
            goto found_solution;
conflict:;
            col=__builtin_ctz(colmask&(0xFFFFFFFFFFFFFFFFULL<<(col+1)));
        }
        row--;
        if (row >= 0) {
            col=_mm_extract_epi8(vboard,0);
            vboard=_mm_insert_epi8(_mm_bsrli_si128(vboard,1),127,15);
            colmask += (1<<col);
        }
        continue;
found_solution:
        // Move to the next row
        if (row == n - 1) {
            int8_t board[16];
            _mm_store_si128((__m128i*)board,vboard);
            solutions++;
            // Found a solution
            printf("[");
            printf("%d",board[MAX_N-1]);
            for (int i = MAX_N-2; i >=0; i--) {
                printf(",%d",board[i]);
            }
            printf("]\n");
            colmask += (1<<col);
            col=_mm_extract_epi8(vboard,0);
            vboard=_mm_insert_epi8(_mm_bsrli_si128(vboard,1),127,15);
        } else {
            row++;
            col = -1; // Start from the first column in the next row
        }
    }
    return solutions;
}

int main() {
    int solutions=solve(MAX_N);
    printf("Number of Solutions=%d\n",solutions);
    return 0;
}
