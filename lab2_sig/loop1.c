#include <unistd.h>
#include <stdio.h>
#include <signal.h>
#include <stdlib.h>

void sigintHandler(int sig){
    printf("\nsigint handled\n");
}

void sigusr2Handler(int sig){
    printf("sigusr2 handled\n");
}

int main(){

    struct sigaction s;
    struct sigaction i;
    s.sa_handler = &sigintHandler;
    i.sa_handler = &sigusr2Handler;
    
    sigaction(SIGINT, &s, NULL);
    sigaction(SIGUSR2, &i, NULL);
    while(1){

    }
}