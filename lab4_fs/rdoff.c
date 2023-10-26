#include <assert.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>

int main(int argc, char *argv[]) {

  if (argc < 3) {
    fprintf(stderr, "Usage: %s filename offset_in_bytes bytes_to_read\n",
            argv[0]);
    exit(0);
  }

  int fd = open(argv[1], O_RDONLY);

  assert(fd > 0);

  int offs = atoi(argv[2]);
  int nbytes = atoi(argv[3]);

  char str[nbytes];

  ssize_t st = pread(fd, str, nbytes, offs);

  fprintf(stderr, "%s\n", str);
  fprintf(stderr, "Read %zd bytes from offset %d of file %s\n", st, offs,
          argv[1]);

  close(fd);

  return 1;
}
