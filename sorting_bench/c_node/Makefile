# Makefile for the C Node sorter
#
# Finds ei headers/libs from the Erlang installation automatically.

ERL_ROOT := $(shell erl -noshell -eval 'io:format("~s", [code:root_dir()]), halt().')
EI_DIR   := $(shell erl -noshell -eval 'io:format("~s", [code:lib_dir(erl_interface)]), halt().')

CFLAGS  = -O3 -Wall -Wextra -std=c11 -D_REENTRANT \
          -I$(EI_DIR)/include \
          -I$(ERL_ROOT)/usr/include
LDFLAGS = -L$(EI_DIR)/lib -L$(ERL_ROOT)/usr/lib \
          -lei -lpthread

.PHONY: all clean

all: sort_node

sort_node: sort_node.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f sort_node
