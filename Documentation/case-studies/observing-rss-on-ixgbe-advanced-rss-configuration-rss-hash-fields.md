# Observing RSS on ixgbe: Advanced RSS Configuration - RSS Hash Fields

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
(as we did previously in [Basic RSS Validation](./observing-rss-on-ixgbe-basic-rss-validation.md)).

https://docs.microsoft.com/en-us/windows-hardware/drivers/network/verifying-the-rss-hash-calculation

In order to get the same hash values, we need to set the same hash key as is
provided in the verification document. You will need the same number of queues
as I use to get the same queue results. For additional details on these
statements, see [Basic RSS Validation](./observing-rss-on-ixgbe-basic-rss-validation.md).
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

For ipv4 tcp (hereafter "tcp4"), ixgbe defaults to computing RSS hash on source
ip, source port, destination ip, and destination port. The driver also doesn't
permit changes to the tcp4 hash fields configuration.

Thankfully, for ipv4 udp ("udp4"), the RSS hash calculation, masking technique,
and indirection table lookup all work in exactly the same way; they simply
consider different configuration for hash fields.

For udp4, ixgbe defaults to computing RSS hash on only source and destination
ips. I've included the command to set udp4 to its default to provide the recipe
to revert any changes we make without having to reinitialize the driver.
```
[user@localhost:~]$ sudo ethtool -N ixgbe0 rx-flow-hash udp4 sd
[user@localhost:~]$ ethtool -n ixgbe0 rx-flow-hash udp4
UDP over IPV4 flows use these fields for computing Hash flow key:
IP SA
IP DA

```

Now that we have RSS configured for verification, we need to use the
verification data to finish the mappings to specific queues.
[`rss.sh`](../../contrib/rss/) makes this trivial. Since ports are not being
considered, we need to supply `0` for the port arguments.
```
[user@localhost:~/rxtxcpu/contrib/rss]$ ethtool -x ixgbe0 | ./rss.sh 66.9.149.187 0 161.142.100.80 0
hash:  323e8fc2
idx:   66
queue: 2
[user@localhost:~/rxtxcpu/contrib/rss]$ ethtool -x ixgbe0 | ./rss.sh 199.92.111.2 0 65.69.140.83 0
hash:  d718262a
idx:   42
queue: 10
[user@localhost:~/rxtxcpu/contrib/rss]$ ethtool -x ixgbe0 | ./rss.sh 24.19.198.95 0 12.22.207.184 0
hash:  d2d0a5de
idx:   94
queue: 14
[user@localhost:~/rxtxcpu/contrib/rss]$ ethtool -x ixgbe0 | ./rss.sh 38.27.205.30 0 209.142.163.6 0
hash:  82989176
idx:   118
queue: 6
[user@localhost:~/rxtxcpu/contrib/rss]$ ethtool -x ixgbe0 | ./rss.sh 153.39.163.191 0 202.188.127.2 0
hash:  5d1809c5
idx:   69
queue: 5
```

We now know what results we expect; time to see what actually we get. Using
`rxqueue` we'll collect per-queue packet captures of `ixgbe0`.
```
[user@localhost:~]$ sudo rxqueue -w test.pcap ixgbe0
...
```

We'll leave `rxqueue` running on `localhost`.

As was done for tcp in [Basic RSS Validation](./observing-rss-on-ixgbe-basic-rss-validation.md),
[`rss-validate-across-wire.sh`](../../contrib/rss-validate-across-wire/) can be
used on `remotehost` to send udp packets for each ipv4 4-tuple in the
verification data. Alternatively, the following commands preceeded by `+` can
be run manually.
```
[user@remotehost:~/rxtxcpu/contrib/rss-validate-across-wire]$ ./rss-validate-across-wire.sh eth0 192.168.24.10 udp
+ sudo ip r add 161.142.100.80/32 via 192.168.24.10 dev eth0
+ sudo ip r add 65.69.140.83/32 via 192.168.24.10 dev eth0
+ sudo ip r add 12.22.207.184/32 via 192.168.24.10 dev eth0
+ sudo ip r add 209.142.163.6/32 via 192.168.24.10 dev eth0
+ sudo ip r add 202.188.127.2/32 via 192.168.24.10 dev eth0
+ sudo hping3 --udp -S -c 3 -i u1 -I eth0 -a 66.9.149.187 -ks 2794 161.142.100.80 -p 1766
HPING 161.142.100.80 (eth0 161.142.100.80): udp mode set, 28 headers + 0 data bytes

--- 161.142.100.80 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo hping3 --udp -S -c 3 -i u1 -I eth0 -a 199.92.111.2 -ks 14230 65.69.140.83 -p 4739
HPING 65.69.140.83 (eth0 65.69.140.83): udp mode set, 28 headers + 0 data bytes

--- 65.69.140.83 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo hping3 --udp -S -c 3 -i u1 -I eth0 -a 24.19.198.95 -ks 12898 12.22.207.184 -p 38024
HPING 12.22.207.184 (eth0 12.22.207.184): udp mode set, 28 headers + 0 data bytes

--- 12.22.207.184 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo hping3 --udp -S -c 3 -i u1 -I eth0 -a 38.27.205.30 -ks 48228 209.142.163.6 -p 2217
HPING 209.142.163.6 (eth0 209.142.163.6): udp mode set, 28 headers + 0 data bytes

--- 209.142.163.6 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo hping3 --udp -S -c 3 -i u1 -I eth0 -a 153.39.163.191 -ks 44251 202.188.127.2 -p 1303
HPING 202.188.127.2 (eth0 202.188.127.2): udp mode set, 28 headers + 0 data bytes

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
3 packets captured on queue 5.
3 packets captured on queue 6.
0 packets captured on queue 7.
0 packets captured on queue 8.
0 packets captured on queue 9.
3 packets captured on queue 10.
0 packets captured on queue 11.
0 packets captured on queue 12.
0 packets captured on queue 13.
3 packets captured on queue 14.
0 packets captured on queue 15.
15 packets captured total.
```

Using `tcpdump` we can see that the packets did in fact land on the queues we
expected.
```
[user@localhost:~]$ for i in test-{2,5,6,10,14}.pcap; do tcpdump -Snnr "$i"; done
reading from file test-2.pcap, link-type EN10MB (Ethernet)
15:04:15.000000 IP 66.9.149.187.2794 > 161.142.100.80.1766: UDP, length 0
15:04:15.000000 IP 66.9.149.187.2794 > 161.142.100.80.1766: UDP, length 0
15:04:15.000000 IP 66.9.149.187.2794 > 161.142.100.80.1766: UDP, length 0
reading from file test-5.pcap, link-type EN10MB (Ethernet)
15:04:15.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: UDP, length 0
15:04:15.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: UDP, length 0
15:04:15.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: UDP, length 0
reading from file test-6.pcap, link-type EN10MB (Ethernet)
15:04:15.000000 IP 38.27.205.30.48228 > 209.142.163.6.2217: UDP, length 0
15:04:15.000000 IP 38.27.205.30.48228 > 209.142.163.6.2217: UDP, length 0
15:04:15.000000 IP 38.27.205.30.48228 > 209.142.163.6.2217: UDP, length 0
reading from file test-10.pcap, link-type EN10MB (Ethernet)
15:04:15.000000 IP 199.92.111.2.14230 > 65.69.140.83.4739: UDP, length 0
15:04:15.000000 IP 199.92.111.2.14230 > 65.69.140.83.4739: UDP, length 0
15:04:15.000000 IP 199.92.111.2.14230 > 65.69.140.83.4739: UDP, length 0
reading from file test-14.pcap, link-type EN10MB (Ethernet)
15:04:15.000000 IP 24.19.198.95.12898 > 12.22.207.184.38024: UDP, length 0
15:04:15.000000 IP 24.19.198.95.12898 > 12.22.207.184.38024: UDP, length 0
15:04:15.000000 IP 24.19.198.95.12898 > 12.22.207.184.38024: UDP, length 0
```

Now, let's change the udp4 hash field configuration to consider ports as well.
```
[user@localhost:~]$ sudo ethtool -N ixgbe0 rx-flow-hash udp4 sdfn
[user@localhost:~]$ ethtool -n ixgbe0 rx-flow-hash udp4
UDP over IPV4 flows use these fields for computing Hash flow key:
IP SA
IP DA
L4 bytes 0 & 1 [TCP/UDP src port]
L4 bytes 2 & 3 [TCP/UDP dst port]

```

And workout what queues to expect.
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

Kick off and leave running `rxqueue` on `localhost`.
```
[user@localhost:~]$ sudo rxqueue -w test.pcap ixgbe0
...
```

Send udp packets from `remotehost`.
```
[user@remotehost:~/rxtxcpu/contrib/rss-validate-across-wire]$ ./rss-validate-across-wire.sh eth0 192.168.24.10 udp
+ sudo ip r add 161.142.100.80/32 via 192.168.24.10 dev eth0
+ sudo ip r add 65.69.140.83/32 via 192.168.24.10 dev eth0
+ sudo ip r add 12.22.207.184/32 via 192.168.24.10 dev eth0
+ sudo ip r add 209.142.163.6/32 via 192.168.24.10 dev eth0
+ sudo ip r add 202.188.127.2/32 via 192.168.24.10 dev eth0
+ sudo hping3 --udp -S -c 3 -i u1 -I eth0 -a 66.9.149.187 -ks 2794 161.142.100.80 -p 1766
HPING 161.142.100.80 (eth0 161.142.100.80): udp mode set, 28 headers + 0 data bytes

--- 161.142.100.80 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo hping3 --udp -S -c 3 -i u1 -I eth0 -a 199.92.111.2 -ks 14230 65.69.140.83 -p 4739
HPING 65.69.140.83 (eth0 65.69.140.83): udp mode set, 28 headers + 0 data bytes

--- 65.69.140.83 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo hping3 --udp -S -c 3 -i u1 -I eth0 -a 24.19.198.95 -ks 12898 12.22.207.184 -p 38024
HPING 12.22.207.184 (eth0 12.22.207.184): udp mode set, 28 headers + 0 data bytes

--- 12.22.207.184 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo hping3 --udp -S -c 3 -i u1 -I eth0 -a 38.27.205.30 -ks 48228 209.142.163.6 -p 2217
HPING 209.142.163.6 (eth0 209.142.163.6): udp mode set, 28 headers + 0 data bytes

--- 209.142.163.6 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo hping3 --udp -S -c 3 -i u1 -I eth0 -a 153.39.163.191 -ks 44251 202.188.127.2 -p 1303
HPING 202.188.127.2 (eth0 202.188.127.2): udp mode set, 28 headers + 0 data bytes

--- 202.188.127.2 hping statistic ---
3 packets transmitted, 0 packets received, 100% packet loss
round-trip min/avg/max = 0.0/0.0/0.0 ms
+ sudo ip r del 161.142.100.80/32 via 192.168.24.10 dev eth0
+ sudo ip r del 65.69.140.83/32 via 192.168.24.10 dev eth0
+ sudo ip r del 12.22.207.184/32 via 192.168.24.10 dev eth0
+ sudo ip r del 209.142.163.6/32 via 192.168.24.10 dev eth0
+ sudo ip r del 202.188.127.2/32 via 192.168.24.10 dev eth0
```

Stop our `rxqueue` with Ctrl-C or similar.
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
15:12:33.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: UDP, length 0
15:12:33.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: UDP, length 0
15:12:33.000000 IP 153.39.163.191.44251 > 202.188.127.2.1303: UDP, length 0
reading from file test-8.pcap, link-type EN10MB (Ethernet)
15:12:33.000000 IP 66.9.149.187.2794 > 161.142.100.80.1766: UDP, length 0
15:12:33.000000 IP 66.9.149.187.2794 > 161.142.100.80.1766: UDP, length 0
15:12:33.000000 IP 66.9.149.187.2794 > 161.142.100.80.1766: UDP, length 0
reading from file test-10.pcap, link-type EN10MB (Ethernet)
15:12:33.000000 IP 199.92.111.2.14230 > 65.69.140.83.4739: UDP, length 0
15:12:33.000000 IP 199.92.111.2.14230 > 65.69.140.83.4739: UDP, length 0
15:12:33.000000 IP 199.92.111.2.14230 > 65.69.140.83.4739: UDP, length 0
15:12:33.000000 IP 24.19.198.95.12898 > 12.22.207.184.38024: UDP, length 0
15:12:33.000000 IP 24.19.198.95.12898 > 12.22.207.184.38024: UDP, length 0
15:12:33.000000 IP 24.19.198.95.12898 > 12.22.207.184.38024: UDP, length 0
reading from file test-15.pcap, link-type EN10MB (Ethernet)
15:12:33.000000 IP 38.27.205.30.48228 > 209.142.163.6.2217: UDP, length 0
15:12:33.000000 IP 38.27.205.30.48228 > 209.142.163.6.2217: UDP, length 0
15:12:33.000000 IP 38.27.205.30.48228 > 209.142.163.6.2217: UDP, length 0
```

RSS hash field configuration has been observed.
