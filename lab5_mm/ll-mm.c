#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>

// for align
#include <stdalign.h>
#include <stddef.h>
#define ALIGNMENT (alignof(max_align_t))
#define META_SIZE (sizeof(block))

typedef struct block_s {
  bool is_free; // true if this block is actually unused
  struct block_s* next; // next block or sbrk(0) if last
} block __attribute__((aligned(ALIGNMENT)));

// head of our list
static block* first = NULL;

/*
 Helper functions to be used throughout.
 */
// Actual size of sz bytes with the given alignment
static size_t aligned_size(size_t sz) {
  return (sz + ALIGNMENT - 1) & ~(ALIGNMENT - 1);
}

// total size of a block - next is the start of next block
static size_t block_total_size(block* pb) {
  if(pb == NULL) return 0;
  else return (uint8_t*)pb->next - (uint8_t*)pb;
}

// size of only data part in a block
static size_t block_data_size(block* pb) {
  if(pb == NULL) return 0;
  return block_total_size(pb) - META_SIZE;
}

// translates block pointer to its data part address
static void* block_to_data(block* pb) {
  if (pb == NULL) return NULL;
  // check whether this is a block?
  return pb + 1;
}

// translates a data address to its block pointer
// note: does not check whether the block is valid
static block* data_to_block(void* p) {
  if (p == NULL) return NULL;
  return (block*)p - 1;
}
/* end Helper functions */

/*
  The following functions are only required for the testing rig.
 */
// sum of occupied data in blocks
size_t used_size() {
  if(first == NULL) return 0;
  size_t s = 0;
  void* last_addr = sbrk(0);
  for (block* pb = first; pb != last_addr; pb = pb->next) {
    if (!pb->is_free) s += block_data_size(pb);
  }
  return s;
}

// sum of data in free blocks
size_t unused_size() {
  if(first == NULL) return 0;
  size_t s = 0;
  void* last_addr = sbrk(0);
  for (block* pb = first; pb != last_addr; pb = pb->next) {
    if (pb->is_free) s += block_data_size(pb);
  }
  return s;
}

// display list information at stderr
void display_list() {
  size_t us = 0, es = 0;
  void* last_addr = sbrk(0);
  fprintf(stderr, "sbrk(0) = %p\n", last_addr);
  fprintf(stderr, "align: %u, meta: %u\n", (unsigned)ALIGNMENT,
          (unsigned)META_SIZE);
  if(first != NULL) {
    for (block* pb = first; pb != last_addr; pb = pb->next) {
      fprintf(stderr, "(block @ %p) %p:%8ld [%1d]\n", pb, pb + 1, block_data_size(pb),
              pb->is_free);
      if (!pb->is_free)
        us += block_data_size(pb);
      else
        es += block_data_size(pb);
    }
  }
  fprintf(stderr, "---- used: %zu unused: %zu ----\n", us, es);
  fflush(stderr);
}

// decreases the limit back to the initial
void reset() {
  if (first != NULL) {
    uint8_t* crtp = sbrk(0);
//    fprintf(stderr, "Memory used: %p .. %p -- shrink %d\n", (uint8_t*)first, crtp,
//            (int)((uint8_t*)first - crtp));
    uint8_t* pend = sbrk((uint8_t*)first - crtp);
    if ((ssize_t)pend == -1) {
      // something went wrong!
      fprintf(stderr, "BRK error!\n");
    }
    first = NULL;
//    fprintf(stderr, "New sbrk = %p\n", sbrk(0));
//    fflush(stderr);
  }
}

/*
  List level block operations. To be used by allocation functions.
 */

// Creates a new block by allocating memory with sbrk()
// the new block is created as occupied and is by default attached
// as the last block in the list (by the use of next).
static block* new_block(size_t size) {
  // align block
  size_t toalloc = aligned_size(size + META_SIZE);
  block* nb = sbrk(toalloc);
  if ((ssize_t)nb == -1) {  // could not allocate more
    errno = ENOMEM;
    return NULL;
  }
  nb->is_free = false;  // not free
  nb->next = sbrk(0);
  return nb;
}

// Finds the block associated with data pointer ptr.
// If there is no such block returns NULL.
static block* find_block(void* ptr) {
  if(first == NULL) return NULL;
  block* tofind = data_to_block(ptr);
  void* last_addr = sbrk(0);
  for(block* pb = first; pb != last_addr; pb = pb->next) {
    if(pb == tofind) return pb;
  }
  return NULL;
}

// Splits block pb in two: first one as big as size, the second as big as the
// rest here size must be smaller than the current block size.
// The second block is marked as free.
// Note: does not check for valid input block
static ssize_t split_block(block* pb, size_t size) {
  ssize_t rest = block_data_size(pb) - aligned_size(size + META_SIZE);
  if (rest >= 0) {
    // can add another block
    block* pn = (block*)((uint8_t*)pb + aligned_size(size + META_SIZE));
    pn->next = pb->next;
    pn->is_free = true;
    pb->next = pn;
  }
  return rest;
}

// Merges all free adjacent blocks in the list, starting at block pb.
// Note: does not check for valid input block
static void merge_blocks(block* pb) {
  void* last_addr = sbrk(0);
  if(pb == NULL || pb == last_addr) return;
  while (pb->next != last_addr) { // while there is a next
    block* pn = pb->next;
    if (pb->is_free && pn->is_free) {
      // can merge
      pb->next = pn->next;
    } else {
      // move to next
      pb = pn;
    }
  }
}
/* end of List level operations */

/* ------ Your assignment starts HERE! ------- */

// Specification taken from man pages for each function.
/*
       The free() function frees the memory space pointed to by ptr,
       which must have been returned by a previous call to malloc() or
       related functions.  Otherwise, or if ptr has already been freed,
       undefined behavior occurs.  If ptr is NULL, no operation is
       performed.
*/
void free(void* ptr) {
  /* TODO: Implement this */
  block* pntblck;
  pntblck = find_block(ptr);
  if (pntblck == NULL){
    return;
  } else if (pntblck.is_free){
    return;
  }
  pntblck.is_free = TRUE;
  int size;
  size = block_total_size(pntblck);
  sbrk(-size);
  return;

}

/*
       The malloc() function allocates size bytes and returns a pointer
       to the allocated memory.  The memory is not initialized.  If size
       is 0, then malloc() returns a unique pointer value that can later
       be successfully passed to free().
*/
void* malloc(size_t size) {
  /* TODO: Implement this */
  if (size == 0) {
    return NULL;
  }
  void *ptr = sbrk(0);
  void *test = sbrk(size);
  if(size == 0){
    return ptr;
  }
    ptr == test;
    return ptr;
  
}

/*
       The calloc() function allocates memory for an array of nmemb
       elements of size bytes each and returns a pointer to the
       allocated memory.  The memory is set to zero.  If nmemb or size
       is 0, then calloc() returns a unique pointer value that can later
       be successfully passed to free().

       If the multiplication of nmemb and size would result in integer
       overflow, then calloc() returns an error.  By contrast, an
       integer overflow would not be detected in the following call to
       malloc(), with the result that an incorrectly sized block of
       memory would be allocated:

           malloc(nmemb * size);
*/
/* TO DO: Add proper tests in the framework */
void* calloc(size_t nitems, size_t item_size) {
//  fprintf(stderr, "Try calloc %d, %d\n", nitems, item_size);
  size_t size = 0;
  if (__builtin_umull_overflow(nitems, item_size, &size)) {
    // overflow occured
    errno = ENOMEM;
    return NULL;
  }
  void* ptr = malloc(size);
  if(ptr != NULL) memset(ptr, 0, size);
  return ptr;
}

/*
       The realloc() function changes the size of the memory block
       pointed to by ptr to size bytes.  The contents of the memory will
       be unchanged in the range from the start of the region up to the
       minimum of the old and new sizes.  If the new size is larger than
       the old size, the added memory will not be initialized.

       If ptr is NULL, then the call is equivalent to malloc(size), for
       all values of size.

       If size is equal to zero, and ptr is not NULL, then the call is
       equivalent to free(ptr) (but see "Nonportable behavior" for
       portability issues).

       Unless ptr is NULL, it must have been returned by an earlier call
       to malloc or related functions.  If the area pointed to was
       moved, a free(ptr) is done.
*/
void* realloc(void* ptr, size_t size) {
  /* TODO: Implement this */
  if (ptr == NULL) {
    return malloc(size);
  }

  block* block_ptr = find_block(ptr);
  if (block_ptr->size >= size) {
    return ptr;
  }

  void* new_ptr;
  new_ptr = malloc(size);
  if (new_ptr == NULL) {
    return NULL; // TODO: set errno on failure.
  }
  memcpy(new_ptr, ptr, block_ptr->size);
  free(ptr);
  return new_ptr;
}
