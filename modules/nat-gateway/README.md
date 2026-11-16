# Module: nat-gateway

Creates a single NAT Gateway + Elastic IP in a given (Hub) public subnet.

Only one NAT Gateway is created in the reference architecture (in the `nat`
subnet, `us-east-2a`), matching the design document. Multi-AZ NAT redundancy
is a natural extension - see `OPERATIONS.md` "Future Improvements" - but is
intentionally out of scope here to match the provided reference architecture
exactly, per the "do not simplify, do not embellish beyond the source" rule.
