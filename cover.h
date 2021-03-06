#ifndef COVER_H_
#define COVER_H_

/*
 * Handle a list of file names, and for each of them the set of lines in that
 * file that were actually executed.
 */

/* Needed for FILE declaration. */
#include <stdio.h>

/* for U32 */
#include  <EXTERN.h>
#include  <perl.h>
#include  "ppport.h"

/*
 * We will have one of these per file, stored in a singly linked list.
 */
typedef struct CoverNode {
  char* file;                 /* file name */
  U32            hash;        /* hash of the file_name */
  unsigned char* lines;       /* bit set with the "covered lines" */
  unsigned char* phases;      /* bit set with the phases of the "covered lines" */
  unsigned short alen;        /* current length of lines array */
  unsigned short bmax;        /* value of largest bit (line) seen so far */
  unsigned short bcnt;        /* number of different bits (lines) seen so far */
  struct CoverNode* next;     /* next element in list */
} CoverNode;

/*
 * A placeholder for the linked list with file coverage information.
 */
typedef struct CoverList {
  CoverNode** list;
  unsigned int used;
  unsigned int size;
} CoverList;

/*
 * Create a CoverList object.
 */
CoverList* cover_create(void);

/*
 * Destroy a CoverList object.
 */
void cover_destroy(CoverList* cover);

/*
 * Add an executed file:line to the CoverList; will create CoverNode
 * for file, if it doesn't already exist.
 */
void cover_add_covered(CoverList* cover, const char* file, int line, int phase);

/*
 * Add a file:line to the CoverList; will create CoverNode for file, if it
 * doesn't already exist.
 */
void cover_add_line(CoverList* cover, const char* file, int line);

/*
 * Dump all data to a given file stream.
 */
void cover_dump(CoverList* cover, FILE* fp);


#endif
