#include <signal.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>

static volatile int s;

static void alarm_handler(int sig){
		printf("alarm");
		fflush(stdout);
	    s= 0;
}

int main() {
	struct sigaction a = {0};
	a.sa_handler = alarm_handler;
	sigaction(SIGALRM, &a, NULL);
	s = 1;
	unsigned long int count = 0;
	alarm(1);			    
	while(s){				    
		count++;
	}
	printf("\nThe loop ran %lu times.\n", count);
}
