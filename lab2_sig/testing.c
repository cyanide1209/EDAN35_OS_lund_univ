#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

int main() {
    pid_t pid = fork();
    sleep(2); // Give the child some time to run
    kill(pid, SIGTERM); // Terminate the child process with SIGTERM

    return 0;
}
