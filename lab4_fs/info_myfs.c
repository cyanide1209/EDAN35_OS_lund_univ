#include "fs_support.h"
#include "rawdisk.h"
#include <stdio.h>
#include <string.h>

// Used to display information about the file system
// Could be made even more detailed, by marking accessible blocks - and
// detecting the missing ones this way.

int main(int argc, char *argv[]) {
  if (openDisk(DISK_FILE, BLOCK_SIZE * FS_NBLOCKS) < 0) {
    perror("open disk failure");
    return -1;
  }

  // first display the block map
  fs_block blkmap;
  readBlock(BLKMAP_BID, blkmap.blockmap);
  // display list
  for (unsigned short i = 0; i < FS_NBLOCKS; i++) {
    if (i % 10)
      printf("\n");
    printf("%i:%u ", i, blkmap.blockmap[i]);
  }
  printf("\n");
  // let's get some statistics:
  unsigned short usedblks = 0;
  unsigned short freeblks = 0;
  unsigned short crtfb = blkmap.blockmap[0];
  while (crtfb != 0) {
    crtfb = blkmap.blockmap[crtfb];
    freeblks++;
  }

  fs_block blkdir;
  // display the directory
  readBlock(ROOTDIR_BID, blkdir.directory);
  for (unsigned short i = 0; i < DIR_ENTRIES_PER_BLOCK; i++) {
    if (!dir_entry_is_empty(blkdir.directory[i])) {
      printf("%u -- %.20s starts:%u\n", i, blkdir.directory[i].name,
             blkdir.directory[i].first_block);
      // let's count the blocks used in this file
      crtfb = blkdir.directory[i].first_block;
      while (crtfb != EOF_BLOCK) {
        crtfb = blkmap.blockmap[crtfb];
        usedblks++;
      }
    } else {
      printf("%u -- empty entry\n", i);
    }
  }
  printf("Free blocks accounted for: %u\n", freeblks);
  printf("Used blocks accounted for: %u\n", usedblks);
  printf("Using 1 block for free map, 1 block for directory.\n");
  printf("Missing blocks: %u\n", FS_NBLOCKS - freeblks - usedblks - 2);

  closeDisk();
  // should also write 0 in all other blocks to make it secure
}
