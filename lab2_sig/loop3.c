#include <signal.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>

int signal;

static void alarm(int sig){
	    signal = 0;
}

int main() {
	struct sigaction a = {0};
	a.sa_handler = alarm;
	sigaction(SIGALRM, &a, NULL);
	signal = 1;
	int count = 0;
	alarm(10);			    
	while(signal){				    
		count++;
	}
	printf("\nThe loop ran  %d times.\n", count);
}
