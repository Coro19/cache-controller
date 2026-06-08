# Cache Controller

A synthesizable Verilog implementation of a 4-way set-associative cache controller with an 11-state one-hot FSM, write-back/write-allocate policy, and LRU replacement.

## Cache Configuration

| Parameter     | Value                  |
|---------------|------------------------|
| Capacity      | 32 KB                  |
| Block size    | 64 B                   |
| Associativity | 4-way set associative  |
| Sets          | 128 (index: 7 bits)    |
| Tag width     | 21 bits                |
| Write policy  | Write-back             |
| Miss policy   | Write-allocate         |
| Replacement   | LRU (2-bit age fields) |


## Module Overview

### cache_ctrl — Top Level

Wires together the hit-detection logic, dirty-victim check, and the control unit.

*Key ports:*

| Port            | Direction | Width  | Description                          |
|-----------------|-----------|--------|--------------------------------------|
| clk, rst_b  | input     | 1      | Clock and active-low async reset     |
| cpu_req       | input     | 1      | CPU requests a cache access          |
| cpu_wr        | input     | 1      | 1 = write, 0 = read                  |
| mem_ready     | input     | 1      | Memory operation complete            |
| tags          | input     | 10752  | Packed tag array (all sets/ways)     |
| valid_bits    | input     | 512    | Valid bit array                      |
| dirty_bits    | input     | 512    | Dirty bit array                      |
| age_bits      | input     | 1024   | LRU age array (2 bits per way)       |
| index_to_test | input     | 7      | Set index for current access         |
| tag_to_test   | input     | 21     | Tag for current access               |
| cpu_done      | output    | 1      | Signals operation completion to CPU  |
| c             | output    | 15     | Control signals to datapath          |

### cache_ctrl_CU — FSM Control Unit

One-hot FSM with 11 states. All next-state logic and control signal assignments are implemented as combinational assign statements.

*States:*

| Bit  | State        | Description                              |
|------|--------------|------------------------------------------|
| s0   | IDLE         | Waiting for CPU request                  |
| s1   | TAG_CMP      | Comparing tags                           |
| s2   | READ_HIT     | Serving a read hit                       |
| s3   | WRITE_HIT    | Serving a write hit                      |
| s4   | EVICT_CHECK  | Checking whether victim block is dirty   |
| s5   | WRITE_BACK   | Initiating write-back of dirty victim    |
| s6   | WB_WAIT      | Waiting for write-back to complete       |
| s7   | MEM_FETCH    | Requesting memory fetch                  |
| s8   | FETCH_WAIT   | Waiting for memory fetch to complete     |
| s9   | REFILL       | Writing fetched data into cache          |
| s10  | DONE         | Signalling completion after refill       |

*Control signal bus c[14:0]:*

| Bit   | Signal            | Asserted in state(s)     |
|-------|-------------------|--------------------------|
| c[0]  | tag_cmp_en      | TAG_CMP                  |
| c[1]  | cache_rd_en     | READ_HIT                 |
| c[2]  | cache_wr_cpu    | WRITE_HIT                |
| c[3]  | set_dirty       | WRITE_HIT, REFILL+write  |
| c[4]  | clr_dirty       | REFILL (read miss)       |
| c[5]  | set_valid       | REFILL                   |
| c[6]  | tag_wr_en       | REFILL                   |
| c[7]  | mem_rd_req      | MEM_FETCH                |
| c[8]  | mem_wr_req      | WRITE_BACK               |
| c[9]  | lru_update      | READ_HIT, WRITE_HIT, DONE|
| c[10] | refill_en       | REFILL                   |
| c[11] | victim_sel      | EVICT_CHECK through WB_WAIT|
| c[12] | cache_wr_refill | REFILL (write-allocate)  |
| c[13] | stall           | All non-idle/hit states  |
| c[14] | evict_dirty_rd  | WRITE_BACK               |

### cache_hit / set_hit — Hit Detection

set_hit compares all four ways in a single set against the requested tag using XOR-based equality and masks with the valid bits. cache_hit instantiates one set_hit per set and muxes the results using the index.

### check_lru_dirty_4wayAssoc_cache / _set — Dirty Victim Detection

Determines whether the LRU victim in the addressed set has its dirty bit set. The per-set module decodes the 2-bit age fields to identify the LRU way (age = 2'b11), then checks the corresponding dirty and valid bits.

### d_ff — D Flip-Flop

Edge-triggered flip-flop with active-low asynchronous reset (rst_b), active-low asynchronous set (set_b), and a synchronous load enable. Used to build the state register in cache_ctrl_CU.

### mux / mux_1sel — Multiplexers

mux_1sel is a single-bit-select, N-bit-wide 2-to-1 MUX. mux is a parameterized tree of mux_1sel cells that implements an arbitrary 2^sel_size-to-1 multiplexer of input_size-bit words.

## FSM Operation


          cpu_req
IDLE ──────────────► TAG_CMP
 ▲                      │
 │           hit·~wr ◄──┤──► hit·wr
 │              │              │
 │          READ_HIT       WRITE_HIT
 │              │              │
 └──────────────┘──────────────┘
                │  ~hit
           EVICT_CHECK
           /          \
     dirty_victim   ~dirty_victim
          │                │
      WRITE_BACK       MEM_FETCH
          │                │
       WB_WAIT ──mem_ready─┘
          │
      MEM_FETCH
          │
      FETCH_WAIT ──mem_ready──► REFILL ──► DONE ──► IDLE


## Simulation

The testbench cache_ctrl_tb.v exercises the following scenarios:

- Read hit and write hit (no memory traffic)
- Read miss with clean victim (fetch only)
- Write miss with clean victim (fetch + write-allocate)
- Read/write miss with dirty victim (write-back then fetch)
- Cold-cache run with randomized accesses and hit/miss/cycle statistics


bash
iverilog -o cache_ctrl_tb \
    modules/d_ff.v \
    modules/mux_1sel.v \
    modules/mux.v \
    modules/set_hit.v \
    modules/cache_hit.v \
    modules/check_lru_dirty_4wayAssoc_set.v \
    modules/check_lru_dirty_4wayAssoc_cache.v \
    modules/cache_ctrl_CU.v \
    modules/cache_ctrl.v \
    test_benches/cache_ctrl_tb.v

vvp cache_ctrl_tb


## Design Notes

- The state register uses d_ff instances directly rather than an always block, keeping the design fully structural below the FSM level.
- state[0] (IDLE) uses an active-low *set* (set_b = rst_b) so the FSM powers up in IDLE on reset; all other state bits use an active-low *reset*.
- The mux module builds an O(log N) selection tree rather than a priority encoder, which maps cleanly to LUT-based FPGA fabric.
- Tag/valid/dirty/age arrays are passed in as flat buses; the external datapath is responsible for storage and update on the control signals asserted by c.
