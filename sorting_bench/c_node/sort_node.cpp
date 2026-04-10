/*
 * C Node sorter — connects to the BEAM via distributed Erlang protocol.
 *
 * Uses C++ std::sort for faster sorting than C qsort (the comparator
 * is inlined rather than called through a function pointer on every compare).
 *
 * Usage: ./sort_node <alive_name> <cookie> <beam_node>
 * Example: ./sort_node sort_node sorting_bench bench@hostname
 *
 * Protocol:
 *   {pid, {:sort, binary}}  ->  sends {:sorted, binary} back to pid
 *   {pid, :stop}            ->  shuts down
 */

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <arpa/inet.h>

extern "C" {
#include <ei.h>
#include <ei_connect.h>
}

/* Pre-allocated buffer for the prepare_sort / trigger_sort protocol */
static int64_t *prepared_data = nullptr;
static size_t   prepared_len  = 0;

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

    /* Use ei_connect_xinit to avoid gethostbyname() — the hostname may not
       resolve via DNS (e.g. missing /etc/hosts entry).  We pass 127.0.0.1
       explicitly since C Nodes always connect over loopback. */
    char hostname[256];
    if (gethostname(hostname, sizeof(hostname)) != 0) {
        fprintf(stderr, "gethostname failed\n");
        return 1;
    }

    char nodename[512];
    snprintf(nodename, sizeof(nodename), "%s@%s", alive, hostname);

    struct in_addr loopback;
    loopback.s_addr = htonl(INADDR_LOOPBACK);

    if (ei_connect_xinit(&ec, hostname, alive, nodename,
                         (Erl_IpAddr)&loopback, cookie, 0) < 0) {
        fprintf(stderr, "ei_connect_xinit failed\n");
        return 1;
    }

    /* Connect to the BEAM node.
       ei_connect() calls gethostbyname() internally, which fails if the
       hostname isn't in DNS/hosts.  Extract the alive name from
       "alive@host" and use ei_xconnect() with the loopback address. */
    char beam_alive[256];
    strncpy(beam_alive, beam_node, sizeof(beam_alive) - 1);
    beam_alive[sizeof(beam_alive) - 1] = '\0';
    char *at = strchr(beam_alive, '@');
    if (at) *at = '\0';

    int fd = ei_xconnect(&ec, (Erl_IpAddr)&loopback, beam_alive);
    if (fd < 0) {
        fprintf(stderr, "ei_xconnect to '%s' failed (fd=%d)\n", beam_node, fd);
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

        ei_decode_atom(buf.buff, &index, atom_buf);

        /* Handle :prepare_sort — pre-generate data, store in static buffer */
        if (strcmp(atom_buf, "prepare_sort") == 0) {
            long num_elements;
            ei_decode_long(buf.buff, &index, &num_elements);

            free(prepared_data);
            prepared_data = static_cast<int64_t *>(malloc(num_elements * sizeof(int64_t)));
            prepared_len = num_elements;

            uint64_t rng = 0xdeadbeefcafe1234ULL;
            for (long i = 0; i < num_elements; i++) {
                rng ^= rng << 13;
                rng ^= rng >> 7;
                rng ^= rng << 17;
                prepared_data[i] = static_cast<int64_t>(rng % 1000000000);
            }

            ei_x_buff reply;
            ei_x_new_with_version(&reply);
            ei_x_encode_atom(&reply, "ready");
            ei_send(fd, &from, reply.buff, reply.index);
            ei_x_free(&reply);
            continue;
        }

        /* Handle :trigger_sort — sort pre-generated buffer, reply :ok */
        if (strcmp(atom_buf, "trigger_sort") == 0) {
            if (prepared_data && prepared_len > 0) {
                std::sort(prepared_data, prepared_data + prepared_len);
            }

            ei_x_buff reply;
            ei_x_new_with_version(&reply);
            ei_x_encode_atom(&reply, "ok");
            ei_send(fd, &from, reply.buff, reply.index);
            ei_x_free(&reply);
            continue;
        }

        /* Handle :generate_and_sort — pure native reference run */
        if (strcmp(atom_buf, "generate_and_sort") == 0) {
            long num_elements;
            ei_decode_long(buf.buff, &index, &num_elements);

            int64_t *arr = static_cast<int64_t *>(malloc(num_elements * sizeof(int64_t)));
            if (!arr) {
                fprintf(stderr, "[C Node] malloc for generate_and_sort failed\n");
                continue;
            }

            /* Fast xorshift64 PRNG */
            uint64_t rng = 0xdeadbeefcafe1234ULL;
            for (long i = 0; i < num_elements; i++) {
                rng ^= rng << 13;
                rng ^= rng >> 7;
                rng ^= rng << 17;
                arr[i] = static_cast<int64_t>(rng % 1000000000);
            }

            std::sort(arr, arr + num_elements);
            free(arr);

            /* Reply :ok */
            ei_x_buff reply;
            ei_x_new_with_version(&reply);
            ei_x_encode_atom(&reply, "ok");
            ei_send(fd, &from, reply.buff, reply.index);
            ei_x_free(&reply);
            continue;
        }

        if (strcmp(atom_buf, "sort") != 0) {
            fprintf(stderr, "[C Node] Unknown command: %s\n", atom_buf);
            continue;
        }

        /* Decode the binary */
        int type;
        int bin_size;
        ei_get_type(buf.buff, &index, &type, &bin_size);

        auto *bin_data = static_cast<unsigned char *>(malloc(bin_size));
        if (!bin_data) {
            fprintf(stderr, "[C Node] malloc(%d) failed\n", bin_size);
            continue;
        }

        long actual_size;
        ei_decode_binary(buf.buff, &index, bin_data, &actual_size);

        /* Sort the data as int64_t array */
        size_t num_elements = actual_size / sizeof(int64_t);
        auto *arr = reinterpret_cast<int64_t *>(bin_data);
        std::sort(arr, arr + num_elements);

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
