# Observing RSS on ixgbe: Advanced RSS Configuration - RSS Hash Indirection Table

This case study leverages commands which may be unsafe in your environment
(i.e. commands which change interface configuration, send packets with spoofed
source address, etc.). Be sure you understand the implications of, and have
taken suitable precations for, each command before running.

Setup details:
* `ixgbe0` is an `82599ES 10-Gigabit SFI/SFP+ Network Connection (Ethernet
    Server Adapter X520-2)` using the **in-tree** ixgbe driver
* `eth0` is a nic in the same layer 2 network as `ixgbe0`
* `localhost` is the host which contains `ixgbe0`
* `remotehost` is the host which contains `eth0`
* `192.168.24.10/24` is the ipv4 address assigned to `ixgbe0`
* `192.168.24.11/24` is the ipv4 address assigned to `eth0`
* Flow Director is disabled as documented in [Advanced RSS Configuration](./observing-rss-on-ixgbe-advanced-rss-configuration.md)

We'll again be using the traditional verification data provided by Microsoft
(first seen in [Basic RSS Validation](./observing-rss-on-ixgbe-basic-rss-validation.md)).

https://docs.microsoft.com/en-us/windows-hardware/drivers/network/verifying-the-rss-hash-calculation

We saw in [Basic RSS Validation](./observing-rss-on-ixgbe-basic-rss-validation.md)
that once a hash value is calculated, it's mapped to a queue via a masking
operation and an indirection table lookup. [`rss.sh`](../../contrib/rss/) was
used in that document to keep things simple.
```
[user@localhost:~/rxtxcpu/contrib/rss]$ ethtool -x ixgbe0 | ./rss.sh 153.39.163.191 44251 202.188.127.2 1303
hash:  10e828a2
idx:   34
queue: 2
```

Let's take a deeper look now.

The masking operation is a bitwise AND of the hash value and the highest
index in the indirection table. Given that indexing of the indirection table
starts at zero, this is the same as the table cardinality minus one. With ixgbe
we have 128 entries (commonly referred to as "buckets"), indexed as 0 to 127.
Our masking operation is, therefore, `hash & 127`. This works as a shortcut for
`hash % 128` when cardinality is a power of 2 (which is true for the
indirection table cardinality on every nic I've encountered). Performing the
masking operation with a hash value of 0x10e828a2 and a cardinality of 128
results in 34.
```
[user@localhost:~]$ echo $((0x10e828a2 & 127))
34
[user@localhost:~]$ echo $((0x10e828a2 % 128))
34
```

The result of the masking operation is used as the index to select a bucket.
The bucket maps index to queue. Given the following configuration, a masking
operation result of 34 will be mapped to rx queue 2.
```
[user@localhost:~]$ ethtool -x ixgbe0
RX flow hash indirection table for ixgbe0 with 16 RX ring(s):
    0:      0     1     2     3     4     5     6     7
    8:      8     9    10    11    12    13    14    15
   16:      0     1     2     3     4     5     6     7
   24:      8     9    10    11    12    13    14    15
   32:      0     1     2     3     4     5     6     7
   40:      8     9    10    11    12    13    14    15
   48:      0     1     2     3     4     5     6     7
   56:      8     9    10    11    12    13    14    15
   64:      0     1     2     3     4     5     6     7
   72:      8     9    10    11    12    13    14    15
   80:      0     1     2     3     4     5     6     7
   88:      8     9    10    11    12    13    14    15
   96:      0     1     2     3     4     5     6     7
  104:      8     9    10    11    12    13    14    15
  112:      0     1     2     3     4     5     6     7
  120:      8     9    10    11    12    13    14    15
RSS hash key:
6d:5a:56:da:25:5b:0e:c2:41:67:25:3d:43:a3:8f:b0:d0:ca:2b:cb:ae:7b:30:b4:77:cb:2d:a3:80:30:f2:0c:6a:42:b7:3b:be:ac:01:fa
```

Our results in [Basic RSS Validation](./observing-rss-on-ixgbe-basic-rss-validation.md)
allowed us to observe that this flow did in fact land on queue 2.
```
[user@localhost:~]$ sudo rxqueue -w test.pcap ixgbe0
^C
0 packets captured on queue 0.
0 packets captured on queue 1.
3 packets captured on queue 2.
...
```
```
[user@localhost:~]$ for i in test-{2,8,10,15}.pcap; do tcpdump -Snnr "$i"; done
reading from file test-2.pcap, link-type EN10MB (Ethernet)
13:10:47.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 2041024194, win 512, length 0
13:10:47.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 937089782, win 512, length 0
13:10:47.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 821660352, win 512, length 0
...
```

Now let's make some changes.

First let's add a route on `remotehost` for the flow we're examining like the
one [`rss-validate-across-wire.sh`](../../contrib/rss-validate-across-wire/)
added for us in previous documents. With this in place we can freely run
`hping3` to send packets for our chosen flow.
```
[user@remotehost:~]$ sudo ip r add 202.188.127.2/32 via 192.168.24.10 dev eth0
[user@remotehost:~]$ 
```

Before we look at direct indirection table manipulation, note how changing the
queue count also changes the indirection table. Now, a masking operation result
of 34 will be mapped to rx queue 4.
```
[user@localhost:~]$ sudo ethtool -L ixgbe0 combined 10
[user@localhost:~]$ ethtool -x ixgbe0
RX flow hash indirection table for ixgbe0 with 10 RX ring(s):
    0:      0     1     2     3     4     5     6     7
    8:      8     9     0     1     2     3     4     5
   16:      6     7     8     9     0     1     2     3
   24:      4     5     6     7     8     9     0     1
   32:      2     3     4     5     6     7     8     9
   40:      0     1     2     3     4     5     6     7
   48:      8     9     0     1     2     3     4     5
   56:      6     7     8     9     0     1     2     3
   64:      4     5     6     7     8     9     0     1
   72:      2     3     4     5     6     7     8     9
   80:      0     1     2     3     4     5     6     7
   88:      8     9     0     1     2     3     4     5
   96:      6     7     8     9     0     1     2     3
  104:      4     5     6     7     8     9     0     1
  112:      2     3     4     5     6     7     8     9
  120:      0     1     2     3     4     5     6     7
RSS hash key:
6d:5a:56:da:25:5b:0e:c2:41:67:25:3d:43:a3:8f:b0:d0:ca:2b:cb:ae:7b:30:b4:77:cb:2d:a3:80:30:f2:0c:6a:42:b7:3b:be:ac:01:fa
```

To keep things brief, I'll be omitting reminders to start `rxqueue` before
`hping3`.

I'll also be omitting the `hping3` command beyond the following one. It won't
be changing in essentials for the remainder of this document.
```
[user@remotehost:~]$ sudo hping3 -S -c 3 -i u1 -I eth0 -a 153.39.163.191 -ks 44251 202.188.127.2 -p 1303
HPING 202.188.127.2 (eth0 202.188.127.2): S set, 40 headers + 0 data bytes

--- 202.188.127.2 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
```

We can see that with our reduced queue count the flow landed on queue 4 via
bucket 34 as expected.
```
[user@localhost:~]$ sudo rxqueue -w test.pcap ixgbe0
^C
0 packets captured on queue 0.
0 packets captured on queue 1.
0 packets captured on queue 2.
0 packets captured on queue 3.
3 packets captured on queue 4.
0 packets captured on queue 5.
0 packets captured on queue 6.
0 packets captured on queue 7.
0 packets captured on queue 8.
0 packets captured on queue 9.
3 packets captured total.
```
```
[user@localhost:~]$ tcpdump -Snnr test-4.pcap
reading from file test-4.pcap, link-type EN10MB (Ethernet)
11:52:38.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 242483865, win 512, length 0
11:52:38.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 569739886, win 512, length 0
11:52:38.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 962541026, win 512, length 0
```

Let's return to 16 queues.
```
[user@localhost:~]$ sudo ethtool -L ixgbe0 combined 16
[user@localhost:~]$ 
```

`ethtool` provides a couple methods by which the indirection table can be
manipulated. Let's start with the weight method. With this method you pass an
numerical weight argument for each configured queue.

First, we'll zero-weight all even queues.
```
[user@localhost:~]$ sudo ethtool -X ixgbe0 weight 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1
[user@localhost:~]$ ethtool -x ixgbe0
RX flow hash indirection table for ixgbe0 with 16 RX ring(s):
    0:      1     1     1     1     1     1     1     1
    8:      1     1     1     1     1     1     1     1
   16:      3     3     3     3     3     3     3     3
   24:      3     3     3     3     3     3     3     3
   32:      5     5     5     5     5     5     5     5
   40:      5     5     5     5     5     5     5     5
   48:      7     7     7     7     7     7     7     7
   56:      7     7     7     7     7     7     7     7
   64:      9     9     9     9     9     9     9     9
   72:      9     9     9     9     9     9     9     9
   80:     11    11    11    11    11    11    11    11
   88:     11    11    11    11    11    11    11    11
   96:     13    13    13    13    13    13    13    13
  104:     13    13    13    13    13    13    13    13
  112:     15    15    15    15    15    15    15    15
  120:     15    15    15    15    15    15    15    15
RSS hash key:
6d:5a:56:da:25:5b:0e:c2:41:67:25:3d:43:a3:8f:b0:d0:ca:2b:cb:ae:7b:30:b4:77:cb:2d:a3:80:30:f2:0c:6a:42:b7:3b:be:ac:01:fa
```
Bucket 34 maps to queue 5, as does our flow.
```
[user@localhost:~]$ sudo rxqueue -w test.pcap ixgbe0
^C
0 packets captured on queue 0.
0 packets captured on queue 1.
0 packets captured on queue 2.
0 packets captured on queue 3.
0 packets captured on queue 4.
3 packets captured on queue 5.
0 packets captured on queue 6.
0 packets captured on queue 7.
0 packets captured on queue 8.
0 packets captured on queue 9.
0 packets captured on queue 10.
0 packets captured on queue 11.
0 packets captured on queue 12.
0 packets captured on queue 13.
0 packets captured on queue 14.
0 packets captured on queue 15.
3 packets captured total.
```
```
[user@localhost:~]$ tcpdump -Snnr test-5.pcap
reading from file test-5.pcap, link-type EN10MB (Ethernet)
12:00:19.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 699522541, win 512, length 0
12:00:19.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 719535358, win 512, length 0
12:00:19.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 813724605, win 512, length 0
```

Now, we'll weight such that 7/8ths of buckets map to an even queue.
```
[user@localhost:~]$ sudo ethtool -X ixgbe0 weight 7 1 7 1 7 1 7 1 7 1 7 1 7 1 7 1
[user@localhost:~]$ ethtool -x ixgbe0
RX flow hash indirection table for ixgbe0 with 16 RX ring(s):
    0:      0     0     0     0     0     0     0     0
    8:      0     0     0     0     0     0     1     1
   16:      2     2     2     2     2     2     2     2
   24:      2     2     2     2     2     2     3     3
   32:      4     4     4     4     4     4     4     4
   40:      4     4     4     4     4     4     5     5
   48:      6     6     6     6     6     6     6     6
   56:      6     6     6     6     6     6     7     7
   64:      8     8     8     8     8     8     8     8
   72:      8     8     8     8     8     8     9     9
   80:     10    10    10    10    10    10    10    10
   88:     10    10    10    10    10    10    11    11
   96:     12    12    12    12    12    12    12    12
  104:     12    12    12    12    12    12    13    13
  112:     14    14    14    14    14    14    14    14
  120:     14    14    14    14    14    14    15    15
RSS hash key:
6d:5a:56:da:25:5b:0e:c2:41:67:25:3d:43:a3:8f:b0:d0:ca:2b:cb:ae:7b:30:b4:77:cb:2d:a3:80:30:f2:0c:6a:42:b7:3b:be:ac:01:fa
```
Bucket 34 maps to queue 4, as does our flow.
```
[user@localhost:~]$ sudo rxqueue -w test.pcap ixgbe0
^C
0 packets captured on queue 0.
0 packets captured on queue 1.
0 packets captured on queue 2.
0 packets captured on queue 3.
3 packets captured on queue 4.
0 packets captured on queue 5.
0 packets captured on queue 6.
0 packets captured on queue 7.
0 packets captured on queue 8.
0 packets captured on queue 9.
0 packets captured on queue 10.
0 packets captured on queue 11.
0 packets captured on queue 12.
0 packets captured on queue 13.
0 packets captured on queue 14.
0 packets captured on queue 15.
3 packets captured total.
```
```
[user@localhost:~]$ tcpdump -Snnr test-4.pcap
reading from file test-4.pcap, link-type EN10MB (Ethernet)
12:02:19.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 699344929, win 512, length 0
12:02:19.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 1591562909, win 512, length 0
12:02:19.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 1488176263, win 512, length 0
```

Next, we'll use the equal method. With this method you pass a numerical count
of queues to be used with equal weighting.

Let's use a subset of queues.
```
[user@localhost:~]$ sudo ethtool -X ixgbe0 equal 4
[user@localhost:~]$ ethtool -x ixgbe0
RX flow hash indirection table for ixgbe0 with 16 RX ring(s):
    0:      0     1     2     3     0     1     2     3
    8:      0     1     2     3     0     1     2     3
   16:      0     1     2     3     0     1     2     3
   24:      0     1     2     3     0     1     2     3
   32:      0     1     2     3     0     1     2     3
   40:      0     1     2     3     0     1     2     3
   48:      0     1     2     3     0     1     2     3
   56:      0     1     2     3     0     1     2     3
   64:      0     1     2     3     0     1     2     3
   72:      0     1     2     3     0     1     2     3
   80:      0     1     2     3     0     1     2     3
   88:      0     1     2     3     0     1     2     3
   96:      0     1     2     3     0     1     2     3
  104:      0     1     2     3     0     1     2     3
  112:      0     1     2     3     0     1     2     3
  120:      0     1     2     3     0     1     2     3
RSS hash key:
6d:5a:56:da:25:5b:0e:c2:41:67:25:3d:43:a3:8f:b0:d0:ca:2b:cb:ae:7b:30:b4:77:cb:2d:a3:80:30:f2:0c:6a:42:b7:3b:be:ac:01:fa
```
Bucket 34 maps to queue 2, as does our flow.
```
[user@localhost:~]$ sudo rxqueue -w test.pcap ixgbe0
^C
0 packets captured on queue 0.
0 packets captured on queue 1.
3 packets captured on queue 2.
0 packets captured on queue 3.
0 packets captured on queue 4.
0 packets captured on queue 5.
0 packets captured on queue 6.
0 packets captured on queue 7.
0 packets captured on queue 8.
0 packets captured on queue 9.
0 packets captured on queue 10.
0 packets captured on queue 11.
0 packets captured on queue 12.
0 packets captured on queue 13.
0 packets captured on queue 14.
0 packets captured on queue 15.
3 packets captured total.
```
```
[user@localhost:~]$ tcpdump -Snnr test-2.pcap
reading from file test-2.pcap, link-type EN10MB (Ethernet)
12:03:10.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 234234720, win 512, length 0
12:03:10.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 158509102, win 512, length 0
12:03:10.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 1317574346, win 512, length 0
```

We can use this command to restore the default indirection table configuration.
This does the same thing in our configuration as `equal 16`, but without
needing to know the queue count.
```
[user@localhost:~]$ sudo ethtool -X ixgbe0 default
[user@localhost:~]$ 
```

Time to clean up `remotehost`.
```
[user@remotehost:~]$ sudo ip r del 202.188.127.2/32 via 192.168.24.10 dev eth0
[user@remotehost:~]$ 
```

RSS hash indirection table configuration has been observed.
