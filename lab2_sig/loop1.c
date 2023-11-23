#include <unistd.h>
#include <stdio.h>
#include <signal.h>
#include <stdlib.h>

void sigintHandler(int sig){
    printf("\nsigint handled\n");
    while(1){

    }
}

void sigusr2Handler(int sig){
    printf("sigusr2 handled\n");
}

int main(){

    struct sigaction s;
    struct sigaction i;
    s.sa_handler = &sigintHandler;
    i.sa_handler = &sigusr2Handler;
    struct sigaction new_action_usr1;
    new_action_usr1.sa_handler = SIG_IGN;
    
    sigaction(SIGINT, &s, NULL);
    sigaction(SIGUSR2, &i, NULL);
    sigaction(SIGUSR1, &new_action_usr1, NULL);
    while(1){

    }
}