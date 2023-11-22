#include <unistd.h>
#include <stdio.h>
#include <signal.h>
#include <stdlib.h>

void print_blocked(sigset_t* set) {
    printf("\nsignals blocked:\n");
    for (int i = 0; i < NSIG; i++){
        if (sigismember(set, i) == 1) {
            printf("%d blocked.\n", i);
        }
    }
}

int main(){
    int x = 0;
    sigset_t set1, set2;
	sigfillset(&set1);
    sigemptyset(&set2);
    sigprocmask(SIG_BLOCK, &set1, NULL);
    printf("begin\n");
    while (x<10){
        sleep(1);
        x++;
    }
    sigpending(&set2);
    print_blocked(&set2);
}
