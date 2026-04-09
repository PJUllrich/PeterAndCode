/*
 * C Node sorter — connects to the BEAM via distributed Erlang protocol.
 *
 * This demonstrates the fastest possible native sorting (C qsort) but with
 * the highest copy cost: data is serialized into the distribution protocol,
 * sent over a TCP socket, deserialized, sorted, re-serialized, sent back,
 * and deserialized again by the BEAM.
 *
 * Usage: ./sort_node <alive_name> <cookie> <beam_node>
 * Example: ./sort_node sort_node sorting_bench bench@hostname
 *
 * Protocol:
 *   {pid, {:sort, binary}}  →  sends {:sorted, binary} back to pid
 *   {pid, :stop}            →  shuts down
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <ei.h>
#include <ei_connect.h>

static int compare_i64(const void *a, const void *b) {
    int64_t ia = *(const int64_t *)a;
    int64_t ib = *(const int64_t *)b;
    if (ia < ib) return -1;
    if (ia > ib) return 1;
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <alive_name> <cookie> <beam_node>\n", argv[0]);
        return 1;
    }

    char *alive = argv[1];
    char *cookie = argv[2];
    char *beam_node = argv[3];

    /* Initialize this C node */
    ei_cnode ec;
    if (ei_connect_init(&ec, alive, cookie, 0) < 0) {
        fprintf(stderr, "ei_connect_init failed\n");
        return 1;
    }

    /* Connect to the BEAM node */
    int fd = ei_connect(&ec, beam_node);
    if (fd < 0) {
        fprintf(stderr, "ei_connect to '%s' failed (fd=%d)\n", beam_node, fd);
        return 1;
    }

    fprintf(stderr, "[C Node] Connected to %s on fd %d\n", beam_node, fd);

    /* Message loop */
    erlang_msg emsg;
    ei_x_buff buf;
    ei_x_new_with_version(&buf);

    while (1) {
        buf.index = 0;
        int got = ei_xreceive_msg(fd, &emsg, &buf);

        if (got == ERL_TICK) {
            /* Keepalive tick — ignore */
            continue;
        }

        if (got == ERL_ERROR) {
            fprintf(stderr, "[C Node] Connection lost (erl_errno=%d)\n", erl_errno);
            break;
        }

        if (got != ERL_MSG) continue;

        /* Decode: {pid, command} */
        int index = 0;
        int version;
        ei_decode_version(buf.buff, &index, &version);

        int arity;
        if (ei_decode_tuple_header(buf.buff, &index, &arity) < 0 || arity != 2) {
            fprintf(stderr, "[C Node] Bad message format\n");
            continue;
        }

        /* First element: sender PID */
        erlang_pid from;
        if (ei_decode_pid(buf.buff, &index, &from) < 0) {
            fprintf(stderr, "[C Node] Failed to decode PID\n");
            continue;
        }

        /* Check if it's the :stop atom */
        int saved = index;
        char atom_buf[256];
        if (ei_decode_atom(buf.buff, &index, atom_buf) == 0) {
            if (strcmp(atom_buf, "stop") == 0) {
                fprintf(stderr, "[C Node] Received :stop, shutting down\n");
                break;
            }
            /* Not :stop — shouldn't happen, skip */
            continue;
        }
        index = saved;

        /* Second element: {:sort, binary} */
        int inner_arity;
        if (ei_decode_tuple_header(buf.buff, &index, &inner_arity) < 0 || inner_arity != 2) {
            fprintf(stderr, "[C Node] Bad command tuple\n");
            continue;
        }

        ei_decode_atom(buf.buff, &index, atom_buf); /* :sort */
        if (strcmp(atom_buf, "sort") != 0) {
            fprintf(stderr, "[C Node] Unknown command: %s\n", atom_buf);
            continue;
        }

        /* Decode the binary */
        int type;
        int bin_size;
        ei_get_type(buf.buff, &index, &type, &bin_size);

        unsigned char *bin_data = malloc(bin_size);
        if (!bin_data) {
            fprintf(stderr, "[C Node] malloc(%d) failed\n", bin_size);
            continue;
        }

        long actual_size;
        ei_decode_binary(buf.buff, &index, bin_data, &actual_size);

        /* Sort the data */
        size_t num_elements = actual_size / sizeof(int64_t);
        qsort(bin_data, num_elements, sizeof(int64_t), compare_i64);

        /* Send reply: {:sorted, binary} */
        ei_x_buff reply;
        ei_x_new_with_version(&reply);
        ei_x_encode_tuple_header(&reply, 2);
        ei_x_encode_atom(&reply, "sorted");
        ei_x_encode_binary(&reply, bin_data, actual_size);

        if (ei_send(fd, &from, reply.buff, reply.index) < 0) {
            fprintf(stderr, "[C Node] ei_send failed\n");
        }

        ei_x_free(&reply);
        free(bin_data);
    }

    ei_x_free(&buf);
    close(fd);
    return 0;
}
