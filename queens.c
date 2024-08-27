// A version of nqueens written directly in C for speed comparison.
// https://gist.github.com/rohit-nsit08/1183731

#include<stdio.h>
#include<stdlib.h>

#define SIZE 12

int t[SIZE] = {-1};
int sol = 1;

void printsol()
{
	for(int i=0;i<SIZE;i++)
	{
		printf("%d,",t[i]+1);
    }
}
int empty(int i)
{
	int j=0;
	while((t[i]!=t[j])&&(abs(t[i]-t[j])!=(i-j))&&j<SIZE)j++;
	return i==j?1:0;
}

void queens(int i)
{
	for(t[i] = 0;t[i]<SIZE;t[i]++)
	{
		if(empty(i))
		{
			if(i==SIZE-1){
				printsol();
				printf("\n");
			}
			else
			queens(i+1);
		}
	}
}

int main()
{
	queens(0);
	return 0;
}
