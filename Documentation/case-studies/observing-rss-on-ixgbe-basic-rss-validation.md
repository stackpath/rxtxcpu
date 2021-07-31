# Observing RSS on ixgbe: Basic RSS Validation

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

In order to keep this document simple, we've left Flow Director enabled. Since
we'll only be testing with packets on 4-tuples never seen in the tx direction,
we should be fine. However, if you intend to do any bidirectional testing
please disable Flow Director as documented in [Advanced RSS Configuration](./observing-rss-on-ixgbe-advanced-rss-configuration.md).
Otherwise, more than RSS will play a part in receive queue selection.

We'll be using the traditional verification data provided by Microsoft (no,
this verification data is not specific to Windows).

https://docs.microsoft.com/en-us/windows-hardware/drivers/network/verifying-the-rss-hash-calculation

In order to get the same hash values, we need to set the same hash key as is
provided in the verification document. Although this hash key is the standard
for verification, and is misused as a default in a great deal of code, the hash
key is properly secret data to prevent volumetric attacks against a single
queue. Saving and restoring the original hash key is suggested. In my case the
second interface of the X520-DA2 persists the original hash key.

The verification data doesn't include specifics for the final steps of RSS;
mapping a hash value to a queue via masking and an indirection table lookup.
However, you will need the same number of queues as I use to get the same
queue results. Let's use 16 queues.
```
[user@localhost:~]$ sudo ethtool -X ixgbe0 hkey 6d:5a:56:da:25:5b:0e:c2:41:67:25:3d:43:a3:8f:b0:d0:ca:2b:cb:ae:7b:30:b4:77:cb:2d:a3:80:30:f2:0c:6a:42:b7:3b:be:ac:01:fa
[user@localhost:~]$ sudo ethtool -L ixgbe0 combined 16
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

Now that we have RSS configured for verification, we need to use the
verification data to finish the mappings to specific queues.
[`rss.sh`](../../contrib/rss/) makes this trivial.
```
[user@localhost:~/rxtxcpu/contrib/rss]$ ethtool -x ixgbe0 | ./rss.sh 66.9.149.187 2794 161.142.100.80 1766
hash:  51ccc178
idx:   120
queue: 8
[user@localhost:~/rxtxcpu/contrib/rss]$ ethtool -x ixgbe0 | ./rss.sh 199.92.111.2 14230 65.69.140.83 4739
hash:  c626b0ea
idx:   106
queue: 10
[user@localhost:~/rxtxcpu/contrib/rss]$ ethtool -x ixgbe0 | ./rss.sh 24.19.198.95 12898 12.22.207.184 38024
hash:  5c2b394a
idx:   74
queue: 10
[user@localhost:~/rxtxcpu/contrib/rss]$ ethtool -x ixgbe0 | ./rss.sh 38.27.205.30 48228 209.142.163.6 2217
hash:  afc7327f
idx:   127
queue: 15
[user@localhost:~/rxtxcpu/contrib/rss]$ ethtool -x ixgbe0 | ./rss.sh 153.39.163.191 44251 202.188.127.2 1303
hash:  10e828a2
idx:   34
queue: 2
```

We now know what results we expect; time to see what actually we get. Using
`rxqueue` we'll collect per-queue packet captures of `ixgbe0`.
```
[user@localhost:~]$ sudo rxqueue -w test.pcap ixgbe0
...
```

We'll leave `rxqueue` running on `localhost`.

On `remotehost` we'll use `hping3` to send tcp packets for each ipv4 4-tuple in
the verification data. We leverage routes so that these packets are given a mac
address and configure the routes to be via `ixgbe0`'s ipv4 address so that
these packets are given `ixgbe0`'s mac address (no need for promiscuous mode).
[`rss-validate-across-wire.sh`](../../contrib/rss-validate-across-wire/) can be used
for this or the following commands preceeded by `+` can be run manually.
```
[user@remotehost:~/rxtxcpu/contrib/rss-validate-across-wire]$ ./rss-validate-across-wire.sh eth0 192.168.24.10
+ sudo ip r add 161.142.100.80/32 via 192.168.24.10 dev eth0
+ sudo ip r add 65.69.140.83/32 via 192.168.24.10 dev eth0
+ sudo ip r add 12.22.207.184/32 via 192.168.24.10 dev eth0
+ sudo ip r add 209.142.163.6/32 via 192.168.24.10 dev eth0
+ sudo ip r add 202.188.127.2/32 via 192.168.24.10 dev eth0
+ sudo hping3 -S -c 3 -i u1 -I eth0 -a 66.9.149.187 -ks 2794 161.142.100.80 -p 1766
HPING 161.142.100.80 (eth0 161.142.100.80): S set, 40 headers + 0 data bytes

--- 161.142.100.80 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo hping3 -S -c 3 -i u1 -I eth0 -a 199.92.111.2 -ks 14230 65.69.140.83 -p 4739
HPING 65.69.140.83 (eth0 65.69.140.83): S set, 40 headers + 0 data bytes

--- 65.69.140.83 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo hping3 -S -c 3 -i u1 -I eth0 -a 24.19.198.95 -ks 12898 12.22.207.184 -p 38024
HPING 12.22.207.184 (eth0 12.22.207.184): S set, 40 headers + 0 data bytes

--- 12.22.207.184 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo hping3 -S -c 3 -i u1 -I eth0 -a 38.27.205.30 -ks 48228 209.142.163.6 -p 2217
HPING 209.142.163.6 (eth0 209.142.163.6): S set, 40 headers + 0 data bytes

--- 209.142.163.6 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo hping3 -S -c 3 -i u1 -I eth0 -a 153.39.163.191 -ks 44251 202.188.127.2 -p 1303
HPING 202.188.127.2 (eth0 202.188.127.2): S set, 40 headers + 0 data bytes

--- 202.188.127.2 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo ip r del 161.142.100.80/32 via 192.168.24.10 dev eth0
+ sudo ip r del 65.69.140.83/32 via 192.168.24.10 dev eth0
+ sudo ip r del 12.22.207.184/32 via 192.168.24.10 dev eth0
+ sudo ip r del 209.142.163.6/32 via 192.168.24.10 dev eth0
+ sudo ip r del 202.188.127.2/32 via 192.168.24.10 dev eth0
```

Over on `localhost` we can now stop our `rxqueue` with Ctrl-C or similar.
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
3 packets captured on queue 8.
0 packets captured on queue 9.
6 packets captured on queue 10.
0 packets captured on queue 11.
0 packets captured on queue 12.
0 packets captured on queue 13.
0 packets captured on queue 14.
3 packets captured on queue 15.
15 packets captured total.
```

Using `tcpdump` we can see that the packets did in fact land on the queues we
expected.
```
[user@localhost:~]$ for i in test-{2,8,10,15}.pcap; do tcpdump -Snnr "$i"; done
reading from file test-2.pcap, link-type EN10MB (Ethernet)
13:10:47.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 2041024194, win 512, length 0
13:10:47.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 937089782, win 512, length 0
13:10:47.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: Flags [S], seq 821660352, win 512, length 0
reading from file test-8.pcap, link-type EN10MB (Ethernet)
13:10:47.000000 IP 66.9.149.187.2794 > 161.142.100.80.1766: Flags [S], seq 2041024194, win 512, length 0
13:10:47.000000 IP 66.9.149.187.2794 > 161.142.100.80.1766: Flags [S], seq 937089782, win 512, length 0
13:10:47.000000 IP 66.9.149.187.2794 > 161.142.100.80.1766: Flags [S], seq 821660352, win 512, length 0
reading from file test-10.pcap, link-type EN10MB (Ethernet)
13:10:47.000000 IP 199.92.111.2.14230 > 65.69.140.83.4739: Flags [S], seq 2041024194, win 512, length 0
13:10:47.000000 IP 199.92.111.2.14230 > 65.69.140.83.4739: Flags [S], seq 937089782, win 512, length 0
13:10:47.000000 IP 199.92.111.2.14230 > 65.69.140.83.4739: Flags [S], seq 821660352, win 512, length 0
13:10:47.000000 IP 24.19.198.95.12898 > 12.22.207.184.38024: Flags [S], seq 2041024194, win 512, length 0
13:10:47.000000 IP 24.19.198.95.12898 > 12.22.207.184.38024: Flags [S], seq 937089782, win 512, length 0
13:10:47.000000 IP 24.19.198.95.12898 > 12.22.207.184.38024: Flags [S], seq 821660352, win 512, length 0
reading from file test-15.pcap, link-type EN10MB (Ethernet)
13:10:47.000000 IP 38.27.205.30.48228 > 209.142.163.6.2217: Flags [S], seq 2041024194, win 512, length 0
13:10:47.000000 IP 38.27.205.30.48228 > 209.142.163.6.2217: Flags [S], seq 937089782, win 512, length 0
13:10:47.000000 IP 38.27.205.30.48228 > 209.142.163.6.2217: Flags [S], seq 821660352, win 512, length 0
```

RSS has been observed.
