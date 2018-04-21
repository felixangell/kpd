#include <assert.h>

#include "array.h"

struct array* 
new_array(size_t capacity) {
	struct array* a = malloc(sizeof(*a));
	a->capacity = capacity;
	a->size = 0;
	a->items = malloc(sizeof(*a->items) * capacity);
	return a;
}

void
array_add(struct array* a, void* item) {
	if (a->size >= a->capacity) {
		a->capacity *= 2;
		a->items = realloc(a->items, sizeof(*a->items) * a->capacity);
	}
	a->items[a->size] = item;
	a->size += 1;
}

void*
array_get(struct array* a, size_t index) {
	assert(index < a->size);
	return a->items[index];
}

void 
destroy_array(struct array* a) {
	free(a->items);
	free(a);
}