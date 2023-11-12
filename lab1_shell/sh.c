#include "list.h"
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define PERM (0644)   /* default permission rw-r--r-- */
#define MAXBUF (512)  /* max length of input line. */
#define MAX_ARG (100) /* max number of cmd line arguments. */

typedef enum {
  AMPERSAND, /* & */
  NEWLINE,   /* end of line reached. */
  NORMAL,    /* file name or command option. */
  INPUT,     /* input redirection (< file) */
  OUTPUT,    /* output redirection (> file) */
  PIPE,      /* | for instance: ls *.c | wc -l */
  SEMICOLON  /* ; */
} token_type_t;

static char *progname;             /* name of this shell program. */
static char input_buf[MAXBUF];     /* input is placed here. */
static char token_buf[2 * MAXBUF]; /* tokens are placed here. */
static char *input_char;           /* next character to check. */
static char *token;                /* a token such as /bin/ls */

static list_t *path_dir_list; /* list of directories in PATH. */
static int input_fd;          /* for i/o redirection or pipe. */
static int output_fd;         /* for i/o redirection or pipe */

/* fetch_line: read one line from user and put it in input_buf. */
int fetch_line(char *prompt) {
  int c;
  int count;

  input_char = input_buf;
  token = token_buf;

  printf("%s", prompt);
  fflush(stdout);

  count = 0;

  for (;;) {

    c = getchar();

    if (c == EOF)
      return EOF;

    if (count < MAXBUF)
      input_buf[count++] = c;

    if (c == '\n' && count < MAXBUF) {
      input_buf[count] = 0;
      return count;
    }

    if (c == '\n') {
      printf("too long input line\n");
      return fetch_line(prompt);
    }
  }
}

/* end_of_token: true if character c is not part of previous token. */
static bool end_of_token(char c) {
  switch (c) {
  case 0:
  case ' ':
  case '\t':
  case '\n':
  case ';':
  case '|':
  case '&':
  case '<':
  case '>':
    return true;

  default:
    return false;
  }
}

/* gettoken: read one token and let *outptr point to it. */
int gettoken(char **outptr) {
  token_type_t type;

  *outptr = token;

  while (*input_char == ' ' || *input_char == '\t')
    input_char++;

  *token++ = *input_char;

  switch (*input_char++) {
  case '\n':
    type = NEWLINE;
    break;

  case '<':
    type = INPUT;
    break;

  case '>':
    type = OUTPUT;
    break;

  case '&':
    type = AMPERSAND;
    break;

  case '|':
    type = PIPE;
    break;
    
   case ';':
     type = SEMICOLON;
     break;

  default:
    type = NORMAL;

    while (!end_of_token(*input_char))
      *token++ = *input_char++;
  }

  *token++ = 0; /* null-terminate the string. */

  return type;
}

/* error: print error message using formatting string similar to printf. */
void error(char *fmt, ...) {
  va_list ap;

  fprintf(stderr, "%s: error: ", progname);

  va_start(ap, fmt);
  vfprintf(stderr, fmt, ap);
  va_end(ap);

  /* print system error code if errno is not zero. */
  if (errno != 0) {
    fprintf(stderr, ": ");
    perror(0);
  } else
    fputc('\n', stderr);
}

/* run_program: fork and exec a program. */
void run_program(char **argv, int argc, bool foreground, bool doing_pipe) {
  /* you need to fork, search for the command in argv[0],
   * setup stdin and stdout of the child process, execv it.
   * the parent should sometimes wait and sometimes not wait for
   * the child process (you must figure out when). if foreground
   * is true then basically you should wait but when we are
   * running a command in a pipe such as PROG1 | PROG2 you might
   * not want to wait for each of PROG1 and PROG2...
   *
   * hints:
   *  snprintf is useful for constructing strings.
   *  access is useful for checking wether a path refers to an
   *      executable program.
   *
   *
   */
  pid_t child_pid;
   

  // Check if the specified program exists in the path
  char* program = argv[0];
  char program_path[1024]; // Assuming a maximum path length
  bool program_found = false;
  char* oldDir = NULL;
  if (strcmp("cd", program)==0) {
    char * temp = NULL;
    temp = getcwd(NULL,0);
		if(strcmp(argv[1], "-") == 0){
      if (oldDir == NULL) {
        printf("parent: no previous working directory found");
        return;
      }
      if(chdir(oldDir)!= 0){
        printf("cd failed");
      }
			oldDir = temp;
						
		}
		else if(chdir(argv[1]) != 0){
			error("could not change dir");		
	
		}
    else{
			oldDir = temp;
		}
  }

  //   if (argc < 2) {
  //     // Handle 'cd' without arguments (change to the home directory)
  //     oldDir = 
  //     char *homedir = getenv("HOME");
  //     if (homedir == NULL) {
  //       fprintf(stderr, "cd: HOME not set\n");
  //     } else if (chdir(homedir) != 0) {
  //       printf("cd failed");
  //     }
  //   } 
  //   else if (strcmp(argv[1], "-") == 0) {
  //     if (oldDir == NULL) {
  //       printf("parent: no previous working directory found");
  //       return;
  //     }
  //     if(chdir(oldDir)!= 0){
  //       printf("cd failed");
  //     }
  //     printf("%s\n", oldDir);
  //     strcpy(oldDir, program_path);
  //   } 
  //   else if (chdir(argv[1]) == 0) {
  //     printf("switched to dir: %s",argv[1]);
  //     strcpy(argv[1],program_path);
  //   } 
  //   else {
  //       printf("parent: failed to switch dir: %s by using %s", argv[1], program);
  //       return;
  //   }
  //   return;
  // }

  if (program[0] == '/') {
    // Explicit path provided, use it directly
    strncpy(program_path, program, sizeof(program_path));
    program_path[sizeof(program_path) - 1] = '\0';

    // Check if the program file is accessible and executable
    if (access(program_path, X_OK) == 0) {
      program_found = true;
    }
  } else {
    // Search for the program in directories listed in $PATH
    list_t *path_entry = path_dir_list;
    do {
      snprintf(program_path, sizeof(program_path), "%s/%s", (char *)path_entry->data, program);
      program_path[sizeof(program_path) - 1] = '\0';

      // Check if the program file is accessible and executable
      if (access(program_path, X_OK) == 0) {
        program_found = true;
        break; // Program found, break the loop
      }

      path_entry = path_entry->succ;
    } while (path_entry != path_dir_list);
  }

  if (!program_found) {
    fprintf(stderr, "Program '%s' not found or not executable.\n", program);
    return;
  }

  child_pid = fork();
  if (child_pid == -1) {
    perror("Fork failed");
    exit(EXIT_FAILURE);
  } else if (child_pid == 0) {
    // Child process

    if (input_fd != 0) {
      // Redirect standard input to the input file descriptor
      dup2(input_fd, STDIN_FILENO);
      close(input_fd);
    }

    if (output_fd != 0) {
      // Redirect standard output to the output file descriptor
      dup2(output_fd, STDOUT_FILENO);
      close(output_fd);
    }

    // Execute the program with its full path
    execv(program_path, argv);

    // If execv fails, report the error and exit
    perror("Exec failed");
    exit(EXIT_FAILURE);
  } else {
    // Parent process
    if (foreground) {
      int status;
      waitpid(child_pid, &status, 0);
      if (WIFEXITED(status)) {
        int exit_code = WEXITSTATUS(status);
        printf("Program exited with status code %d\n", exit_code);
      }
    }
  }
}

void parse_line(void) {
  char* argv[MAX_ARG + 1];
  int argc;
  //	int		pipe_fd[2];	/* 1 for producer and 0 for consumer. */
  token_type_t type;
  bool foreground;
  bool doing_pipe;

  input_fd = 0;
  output_fd = 0;
  argc = 0;

  for (;;) {

    foreground = true;
    doing_pipe = false;

    type = gettoken(&argv[argc]);

    switch (type) {
    case NORMAL:
      argc += 1;
      break;

    case INPUT:
      type = gettoken(&argv[argc]);
      if (type != NORMAL) {
        error("expected file name: but found %s", argv[argc]);
        return;
      }

      input_fd = open(argv[argc], O_RDONLY);

      if (input_fd < 0)
        error("cannot read from %s", argv[argc]);

      break;

    case OUTPUT:
      type = gettoken(&argv[argc]);
      if (type != NORMAL) {
        error("expected file name: but found %s", argv[argc]);
        return;
      }

      output_fd = open(argv[argc], O_CREAT | O_WRONLY, PERM);

      if (output_fd < 0)
        error("cannot write to %s", argv[argc]);
      break;

    case PIPE:
      doing_pipe = true;

      /*FALLTHROUGH*/

    case AMPERSAND:
      foreground = false;

      /*FALLTHROUGH*/

    case NEWLINE:
    case SEMICOLON:

      if (argc == 0)
        return;

      argv[argc] = NULL;

      run_program(argv, argc, foreground, doing_pipe);

      input_fd = 0;
      output_fd = 0;
      argc = 0;

      if (type == NEWLINE)
        return;

      break;
    }
  }
}

/* init_search_path: make a list of directories to look for programs in. */
static void init_search_path(void) {
  char *dir_start;
  char *path;
  char *s;
  list_t *p;
  bool proceed;

  path = getenv("PATH");

  /* path may look like "/bin:/usr/bin:/usr/local/bin"
   * and this function makes a list with strings
   * "/bin" "usr/bin" "usr/local/bin"
   *
   */

  dir_start = malloc(1 + strlen(path));
  if (dir_start == NULL) {
    error("out of memory.");
    exit(1);
  }

  strcpy(dir_start, path);

  path_dir_list = NULL;

  if (path == NULL || *path == 0) {
    path_dir_list = new_list("");
    return;
  }

  proceed = true;

  while (proceed) {
    s = dir_start;
    while (*s != ':' && *s != 0)
      s++;
    if (*s == ':')
      *s = 0;
    else
      proceed = false;

    insert_last(&path_dir_list, dir_start);

    dir_start = s + 1;
  }

  p = path_dir_list;

  if (p == NULL)
    return;

#if 0
	do {
		printf("%s\n", (char*)p->data);
		p = p->succ;
	} while (p != path_dir_list);
#endif
}

/* main: main program of simple shell. */
int main(int argc, char **argv) {
  char *prompt = (argc >= 2 && !strncmp(argv[1], "-n", 3)) ? "" : "% ";

  progname = argv[0];

  init_search_path();

  while (fetch_line(prompt) != EOF)
    parse_line();

  return 0;
}
