#include "fs_support.h"
#include "rawdisk.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[]) {
  if (openDisk(DISK_FILE, BLOCK_SIZE * FS_NBLOCKS) < 0) {
    perror("open disk failure");
    return -1;
  }

  // first update the block map
  fs_block blk;
  // no need to read the block!
  // readBlock(BLKMAP_BID, blk.blockmap);
  // make sure all blocks are part of the free list, except block 1
  // which will have the directory entry
  blk.blockmap[0] = 2;

  for (unsigned short bid = 2; bid < FS_NBLOCKS; bid++) {
    blk.blockmap[bid] = bid + 1;
    printf("%u:%u ", bid, blk.blockmap[bid]);
  }
  blk.blockmap[FS_NBLOCKS - 1] = 0;
  if (writeBlock(BLKMAP_BID, blk.blockmap) < 0) {
    // some error occured
    perror("cannot write BLKMAP");
    return -1;
  }

  // also write 0 in the block 1, which means empty Directory
  bzero(blk.bytes, BLOCK_SIZE);
  writeBlock(ROOTDIR_BID, blk.bytes);

  // finish This
  closeDisk();
  // should also write 0 in all other blocks to make it secure
}
