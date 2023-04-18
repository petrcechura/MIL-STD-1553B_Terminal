# Introduction
As a part of my Bachelor's thesis, I am creating a component of remote terminal, that is able to communicate via MIL-STD-1553B standard and can be implemented to an FPGA with clock frequency 32 MHz (bus frequency is defined by the standard to 1 MHz). Terminal is then completely verificated due to requirements that are summarized below. As terminal represents slave in master-slave bus topology, verification enviroment contains BFM, which simulates the master (Bus Controller in MIL-STD-1553B).

# Structure of terminal
The terminal contains three main blocks in general – FSM_brain, ManchesterEncoder, ManchesterDecoder. Each of those blocks contains various cells (counters, FSMs, registers...) that work all together, but main blocks can be used independetly as they all are used for one (or more) specific purpose. 

## FSM_brain
Controller of terminal; takes outputs from decoder and encoder and decides "what is going on". Directly communicates with memory when is instructed to via commands from the BFM.

## ManchesterDecoder
Since all communication on the bus is done with Manchester code, decoder should be able to receive and decode all transfers on the bus. Every received data are then sent to a terminal as paralel word. Every occured on the bus (wrong parity, invalid synchronization) should decoder be able to analyze and report to a FSM_brain which decides how to react.

## ManchesterEncoder
Encoder receives data from FSM_brain, encodes it with Manchester code, adds calculated parity and sends it on the bus by the MIL-STD-1553B standard.

### Memory
Received bits are stored in simple proprietary memory which is not part of thesis and just represents possible device that terminal should be able to communicate with.

# Verification
Simple verification enviroment is in use, which contains BFM (bus functional model), Enviroment and Verification_package. Verification package defines all procedures and constants that are used for verification (in BFM and Enviroment). BFM simulates Bus Controller and is controlled by Enviroment to transmitt and recieve data on the bus. Enviroment is then used to specify test to be done.

# Requirements
* Frequency of FPGA: 32 MHz
* Frequency of the bus: 1 MHz
* Decode Manchester code
* Encode to a Manchester code
* Receive data from a Bus Controller and save them to memory
* Receive command from a Bus Controller to send data from memory (and make it happen)
* Detect an error in data transfer and deal with it by the standard MIL-STD-1553B
* Detect an invalid command from Bus Controller (invalid memory address) and deal with it by the standard MIL-STD-1553B
* Have ability to receive (and send) message in Broadcast mode
* Have ability to perform specific Mode codes (see MIL-STD-1553B)