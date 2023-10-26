
#ifndef __RAWDISK_H__
#define __RAWDISK_H__

/* Let's set the block size to 512 bytes */
#define BLOCK_SIZE 512

/* All functions return -1 on failure, and various positive values on success */

/* Open filename file as the raw disk. File size fixed at nbytes.
   Creates a new one if it does not exist. */
int openDisk(char *filename, int nbytes);

/* Reads raw block blocknr from the open disk and
   puts the data in the given buffer. */
int readBlock(int blocknr, void *block);

/* Writes the raw block blocknr from the given buffer to the open disk. */
int writeBlock(int blocknr, void *block);

/* Closes the disk file. Forces outstanding writes to disk. */
int closeDisk();

#endif // __RAWDISK_H__
