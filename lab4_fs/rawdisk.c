
#include "rawdisk.h"
#include <fcntl.h>
#include <unistd.h>

static int disk_fd = -1; /* file descriptor for the file emulating the disk */
static int disk_bsize = -1; /* disk size in bytes */

/* Open filename file as the raw disk. File size fixed at nbytes.
   Creates a new one if it does not exist. */
int openDisk(char *filename, int nbytes) {
  /* attempt to open existing file */
  disk_fd = open(filename, O_RDWR);
  if (disk_fd < 0) {
    /* file does not exist, create it */
    disk_fd = open(filename, O_RDWR | O_CREAT);
    if (disk_fd != -1) {
      /* make sure the file is nbytes large. Just write garbage for now. */
      disk_bsize = write(disk_fd, &disk_fd, nbytes);
    }
  } else {
    /* file exists. let's assume is nbytes large */
    disk_bsize = nbytes;
  }
  return disk_bsize;
}

/* Reads raw block blocknr from the open disk and
   puts the data in the given buffer. */
int readBlock(int blocknr, void *block) {
  if (lseek(disk_fd, BLOCK_SIZE * blocknr, SEEK_SET) >= 0)
    return read(disk_fd, block, BLOCK_SIZE);
  else
    return -1;
}

/* Writes the raw block blocknr from the given buffer to the open disk. */
int writeBlock(int blocknr, void *block) {
  if (lseek(disk_fd, BLOCK_SIZE * blocknr, SEEK_SET) >= 0)
    return write(disk_fd, block, BLOCK_SIZE);
  else
    return -1;
}

/* Closes the disk file. Forces outstanding writes to disk. */
int closeDisk() { return close(disk_fd); }
