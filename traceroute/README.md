# Traceroute

## `traceroute` commands

```bash
# Use 1s timeout and the UDP protocol
traceroute -w 1 -P UDP fly.io
# Use 1s timeout and the ICMP protocol
traceroute -w 1 -P ICMP fly.io
```

## Comparisons

Tracing `fly.io` through ICMP:

```bash
# Output of "traceroute -w 1 -P ICMP fly.io
$ traceroute -w 1 -P ICMP fly.io
traceroute to fly.io (37.16.18.81), 64 hops max, 48 byte packets
 1  192.168.0.1 (192.168.0.1)  0.880 ms  0.519 ms  0.387 ms
 2  --redacted-- (--redacted--)  1.417 ms  1.249 ms  1.165 ms
 3  --redacted-- (--redacted--)  2.778 ms  3.787 ms  2.270 ms
 4  * * *
 5  * * *
 6  * * *
 7  nl-ams14a-ri1-ae-8-0.aorta.net (84.116.135.38)  4.702 ms  4.157 ms  4.039 ms
 8  * * *
 9  ae7.cr4-ams1.ip4.gtt.net (213.200.117.170)  5.396 ms  6.107 ms  5.824 ms
10  ip4.gtt.net (46.33.82.122)  4.452 ms  4.556 ms  4.473 ms
11  * * *
12  ip-37-16-18-81.customer.flyio.net (37.16.18.81)  4.641 ms  4.447 ms  4.311 ms

# Output of Traceroute.run/2
iex(1)> Traceroute.run("fly.io", protocol: :icmp)
1 192.168.0.1 (192.168.0.1) 0.733ms
2 --redacted-- (--redacted--) 1.232ms
3 --redacted-- (--redacted--) 3.76ms
4 * * *
5 * * *
6 * * *
7 nl-ams14a-ri1-ae-8-0.aorta.net (84.116.135.38) 4.452ms
8 * * *
9 ae7.cr4-ams1.ip4.gtt.net (213.200.117.170) 6.12ms
10 ip4.gtt.net (46.33.82.122) 5.006ms
11 * * *
12 ip-37-16-18-81.customer.flyio.net (37.16.18.81) 4.913ms
```