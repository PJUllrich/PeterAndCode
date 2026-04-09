# Makefile for standalone C sort benchmark (Google Benchmark)

CXX      = g++
CXXFLAGS = -O3 -Wall -Wextra -std=c++17
LDFLAGS  = -lbenchmark -lpthread

.PHONY: all clean

all: bench_sort

bench_sort: bench_sort.cpp
	$(CXX) $(CXXFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f bench_sort
