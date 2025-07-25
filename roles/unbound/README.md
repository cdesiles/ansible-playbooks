# Testing

## DNS leaks

```
browse https://www.dnsleaktest.com/
```

## DNSSEC

Testing DNSSEC validation

At this point we have a working server with supposedly working DNSSEC validation. Obviously we work on ’trust, but verify’. To check that we have indeed a working validating server, we can run the following command:

```sh
dig www.nic.cz. +dnssec
```

The header section of the result should look like this:

```
; <<>> DiG 9.4.2-P2 <<>> www.nic.cz. +dnssec
;; global options:  printcmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 18417
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1
```

See the bolded ‘ad’ in the flags line? Now compare this to the output of the same command, but run on my MacBook using the ISP’s resolver:

```
; <<>> DiG 9.10.6 <<>> www.nic.cz. +dnssec
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12527
;; flags: qr rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1
```

The ISP’s resolver doesn’t support DNSSEC in this case, so you can see the ‘ad’ flag missing. That flag indicates that the result from the upstream server validated.

# Race condition with wireguard

On unbound side:

```
systemd[1]: Starting unbound.service - Unbound DNS server...
unbound[74430]: [1747167722] unbound[74430:0] error: can't bind socket: Cannot assign requested address for 192.168.27.1>
unbound[74430]: [1747167722] unbound[74430:0] fatal error: could not open ports
systemd[1]: unbound.service: Main process exited, code=exited, status=1/FAILURE
systemd[1]: unbound.service: Failed with result 'exit-code'.
systemd[1]: Failed to start unbound.service - Unbound DNS server.
```

On wireguard side:

```
systemd[1]: Starting wg-quick@wg0.service - WireGuard via wg-quick(8) for wg0...
wg-quick[72187]: [#] ip link add wg0 type wireguard
wg-quick[72187]: [#] wg setconf wg0 /dev/fd/63
wg-quick[72187]: [#] ip -4 address add 192.168.27.1/27 dev wg0
wg-quick[72187]: [#] ip link set mtu 1420 up dev wg0
wg-quick[72215]: [#] resolvconf -a tun.wg0 -m 0 -x
wg-quick[72261]: [1747167556] unbound-control[72261:0] warning: control-enable is 'no' in the config file.
wg-quick[72261]: [1747167556] unbound-control[72261:0] error: connect: Connection refused for 127.0.0.1 port 8953
wg-quick[72217]: run-parts: /etc/resolvconf/update.d/unbound exited with return code 1
wg-quick[72187]: [#] ip link delete dev wg0
systemd[1]: wg-quick@wg0.service: Main process exited, code=exited, status=1/FAILURE
systemd[1]: wg-quick@wg0.service: Failed with result 'exit-code'.
systemd[1]: Failed to start wg-quick@wg0.service - WireGuard via wg-quick(8) for wg0.
```
