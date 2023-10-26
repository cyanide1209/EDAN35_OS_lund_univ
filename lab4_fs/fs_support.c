#include "fs_support.h"
#include "rawdisk.h"
#include <stdio.h>
#include <string.h>

// caches for the directory and block map
// FIXME: could be converted to a table or another structure holding more blocks
// but for now we're using one block for directory, one for the block map
fs_block bdir;
fs_block bmap;

// returns a block to the free blocks list. assumes that blocks[0] points to
// the first free block. For simplicity, you can add blocks to the head of the
// list. Note that the blocks structure must be written back to the disk.
// This function returns the id of the old block pointed by the freed block
// (which might point to the next block in a chain).
unsigned short freeBlock(unsigned short *blocks, unsigned short freedId) {
  unsigned short bid = blocks[freedId];
  blocks[freedId] = blocks[0];
  blocks[0] = freedId;
  // FIXME: For security reasons, one might want to clear the freedId block on
  // the disk (write 0s in it). You could do this here.
  return bid;
}

// allocates a Block from the free list, if there are any. Returns either the
// newly allocated block id, or -1 if there are none.
unsigned short allocateBlock(unsigned short *blocks) {
  unsigned short bid = blocks[0];
  if (bid == 0) { // points back to itself, no more blocks
    printf("allocateBlock: block 0 points to self! no free blocks\n");
    return EOF_BLOCK;
  } else {                   // return the head of the list
    blocks[0] = blocks[bid]; // the list starts with the next free block
    blocks[bid] = EOF_BLOCK; // allocated block points nowere
    return bid;
  }
}

// loads the block map from the disk
unsigned short *load_blockmap() {
  readBlock(BLKMAP_BID, bmap.blockmap);
  return bmap.blockmap;
}

// allocates a new block using the loaded map. returns the id of the block
unsigned short alloc_block() { return allocateBlock(bmap.blockmap); }

// frees the given block in the loaded map. returns the block id the freed
// block points to
unsigned short free_block(unsigned short bid) {
  return freeBlock(bmap.blockmap, bid);
}

// saves the block map back on the disk
void save_blockmap() { writeBlock(BLKMAP_BID, bmap.blockmap); }

// loads the directory data structure from the disk
int load_directory() {
  // is a flat structure - one block directory at ROOTDIR_BID
  return readBlock(ROOTDIR_BID, bdir.bytes);
}

// this function finds the directory block containing the entry for the given
// file (path). The return values are as follows:
// if >0 the return value is the index in the directory entry while bdir
// and bdir_id (global vars) ``refer to the block containing the entry
// if -1 the entry could not be found
// FIXME: this assumes a flat structure now, where all files are in the root
// directory. For a more generic FS, it should allow subdirectories. To handle
// this, one would need to identify dirs top-down and read the right blocks
// from the disk. Useful functions: strsep, strdup, strcmp
int find_dir_entry(const char *path) {
  // now find the file
  unsigned short di = 0;
  // while not all entries inspected
  // and entry not empty
  // and entry not the one we are looking for
  while (di < DIR_ENTRIES_PER_BLOCK &&
         !dir_entry_is_empty(bdir.directory[di]) &&
         strncmp(path, bdir.directory[di].name, FS_NAME_LEN))
    di++;
  if (di == DIR_ENTRIES_PER_BLOCK || dir_entry_is_empty(bdir.directory[di]))
    return -1;
  else
    return di;
}

// Finds the first empty entry, after all the existing
// entries, in the last_block seen as a directiry.
// It returns the index of the entry.
int first_empty_dir_entry() {
  unsigned short di = 0;
  while (di < DIR_ENTRIES_PER_BLOCK && !dir_entry_is_empty(bdir.directory[di]))
    di++;
  if (di == DIR_ENTRIES_PER_BLOCK) // cannot add more entries
    return -1;
  else
    return di;
  // di contains the first empty entry in this block.
}

// assuming the latest block is a directory, it returns a pointer to entry i
dir_entry *index2dir_entry(unsigned short i) { return &bdir.directory[i]; }

// writes latest block to disk - something changed it in the memory
void save_directory() { writeBlock(ROOTDIR_BID, bdir.bytes); }
