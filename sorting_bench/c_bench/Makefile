# Makefile for standalone C sort benchmark (Google Benchmark)

CXX      = g++
BENCH_PREFIX = $(shell brew --prefix google-benchmark 2>/dev/null)
CXXFLAGS = -O3 -Wall -Wextra -std=c++23 -I$(BENCH_PREFIX)/include
LDFLAGS  = -L$(BENCH_PREFIX)/lib -lbenchmark -lpthread

.PHONY: all clean

all: bench_sort

bench_sort: bench_sort.cpp
	$(CXX) $(CXXFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f bench_sort
