/**
  This header is describing the structure of the file system. Modify it to suit
  your needs.
 **/

#include "rawdisk.h"
#include <sys/stat.h>

/**

A disk should have:
1. boot (store info about the "disk") - we'll skip this here
2. a structure defining which blocks belong to which file. For simplicity, use
   a liked list of block ids. A content M at index N says block N is follwed by
   block M. Use this for the free block list as well. For instance block 0
   could always point towards the first free block (note that block 0 will be
   occupied by this very structure anyway... so it will never be part of a file)
3. data/files. These can be of two types:
    a. regular files (these are simply data blocks specified by the sequence
       in the block list, where the first is specified by the directory entry.
       For the last block, you either have a special marker in the list, or you
       use a block count in the directory entry)
    b. directories (these are tables of entries with the files/directories
       it contains). Consider having the number of entries as the first
       value in the directory. (To think about: what happens if the Directory
       extends over several blocks?)

Note that the root directory must be at a fixed location: say the first block
after the boot and the block list (fixed size).

Think about what directory entries should contain. For instance:
- file name (fixed size? for simplicity, 8.3 chars, like in FAT)
- status (see the file system structure - pick some relevant info)
- size in bytes
- first block of the file in the block list

Other alternatives of organizing your file system are possible. Pick the one
you like and have time to implement.

Hint: you could cache your block list and use the memory copy to get faster
access to your block sequences (without reloading them every time). Make sure
you flush your modifications to the disk!!
 **/

#ifndef __FS_SUPPORT_H__
#define __FS_SUPPORT_H__

#define DISK_FILE "RAWDISK_SSFS"
// number of blocks in the file system
#define FS_NBLOCKS 10
// block map block id
#define BLKMAP_BID 0
// root directory block id
#define ROOTDIR_BID 1
// lenght of file name in chars
#define FS_NAME_LEN 12
// value meaning invalid or end of file block (no more blocks)
#define EOF_BLOCK 0xFFFF

typedef struct {
  char name[FS_NAME_LEN];
  // ... some stats - say mode, owner, modtime
  mode_t mode;
  unsigned long size_bytes;
  unsigned short first_block;
} dir_entry;

#define DIR_ENTRIES_PER_BLOCK (BLOCK_SIZE / sizeof(dir_entry))
#define BLOCKIDS_PER_BLOCK (BLOCK_SIZE / sizeof(unsigned short))

typedef union fs_block_t {
  char bytes[BLOCK_SIZE];                      // bytewise access
  unsigned short blockmap[BLOCKIDS_PER_BLOCK]; // FAT16 like
  // more possibilities... ?
  dir_entry directory[DIR_ENTRIES_PER_BLOCK];
} fs_block;

// some helpers
// Working with the directory
#define dir_entry_is_empty(d) (d.name[0] == 0)
int load_directory();
int find_dir_entry(const char *path);
int first_empty_dir_entry();
dir_entry *index2dir_entry(unsigned short);
void save_directory();

// Working with the block map
unsigned short *load_blockmap();
unsigned short alloc_block();
unsigned short free_block(unsigned short bid);
void save_blockmap();

#endif // __FS_SUPPORT_H__
