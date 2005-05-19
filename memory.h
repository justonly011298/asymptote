/****
 * memory.h
 *
 * Interface to the Boehm Garbage Collector.
 *****/

#ifndef MEMORY_H
#define MEMORY_H

#include <list>
#include <vector>
#include <deque>
#include <map>
#include <string>

#ifdef USEGC

#include <gc.h>

#undef GC_MALLOC
inline void *GC_MALLOC(size_t n) { \
  if (void *mem=GC_malloc(n))      \
    return mem;                    \
  throw std::bad_alloc();          \
}
  
#include <gc_allocator.h>
#include <gc_cpp.h>

#else // USEGC

template<class T>
class gc_allocator : public std::allocator<T> {
public:  
  gc_allocator() {}
  gc_allocator(const std::allocator<T>&) {}
};

template<class T>
class traceable_allocator : public std::allocator<T> {
public:  
  traceable_allocator() {}
  traceable_allocator(const std::allocator<T>&) {}
};

class gc {};

enum GCPlacement {UseGC, NoGC, PointerFreeGC};

inline void* operator new(size_t size, GCPlacement) {
  return operator new(size);
}

#endif // USEGC

namespace mem {

#define GC_CONTAINER(KIND)                                               \
  template <typename T>                                                  \
  struct KIND : public std::KIND<T, gc_allocator<T> > {                  \
    KIND() : std::KIND<T, gc_allocator<T> >() {};                        \
    KIND(size_t n) : std::KIND<T, gc_allocator<T> >(n) {};               \
    KIND(size_t n, const T& t) : std::KIND<T, gc_allocator<T> >(n,t) {}; \
  }

GC_CONTAINER(list);
GC_CONTAINER(vector);
GC_CONTAINER(deque);

#undef GC_CONTAINER

#define GC_CONTAINER(KIND)                                                    \
  template <typename Key, typename T, typename Compare = std::less<Key> >     \
  struct KIND : public                                                        \
  std::KIND<Key,T,Compare,gc_allocator<std::pair<Key,T> > > {                 \
    KIND() : std::KIND<Key,T,Compare,gc_allocator<std::pair<Key,T> > > () {}; \
  }

GC_CONTAINER(map);
GC_CONTAINER(multimap);

#undef GC_CONTAINER

#ifdef USEGC_STRING
#define GC_STRING \
  std::basic_string<char,std::char_traits<char>,gc_allocator<char> >
struct string : public GC_STRING
{
  string () {}
  string (char* str) : GC_STRING(str) {}
  string (std::string str) : GC_STRING(str.c_str(),str.size()) {}
  string (GC_STRING str) : GC_STRING(str) {}
  operator std::string () { return std::string(c_str(),size()); }
};
#undef GC_STRING
#else
using std::string;
#endif // USEGC


} // namespace mem

#endif 
