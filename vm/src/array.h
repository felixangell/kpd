#ifndef ARRAY_H
#define ARRAY_H

#include <stdlib.h>

struct array {
	size_t size;
	void** items;
	size_t capacity;
};

struct array* 
new_array(size_t capacity);

void
array_add(struct array*, void* item);

void*
array_get(struct array*, size_t index);

void 
destroy_array(struct array*);

#endif