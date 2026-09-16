# DICE Integration on Arm CCA

Proof-of-Concept implementation of the **Device Identifier Composition Engine (DICE)** key derivation process integrated into the **Arm Confidential Computing Architecture (CCA)** stack.

The project provides a DICE-based cryptographic identity to CCA Realms.
The identity is derived through the software stack and is intended to depend on the underlying firmware state and the DICE root material.
The implementation also preserves compatibility with the traditional CCA explicit attestation mechanism.

## Requirements

The build system uses [Shrinkwrap](https://shrinkwrap.docs.arm.com/en/2026.6.0/) to build and run the firmware stack in containers. As a result, a specific compiler or QEMU version is not required for the normal build and execution flow.

The required host dependency is **tuxmake**.

Install it with:

```bash
pip3 install -U tuxmake
```

If the distribution prevents global installation from PyPI:

```bash
pip3 install -U tuxmake --break-system-packages
```

Alternatively, install it with `pipx`:

```bash
pipx install tuxmake
```

## Installation
### 1. Prepare the CCA workspace

Create the workspace and clone the CCA Shrinkwrap configuration:

```bash
mkdir cca-v10
cd cca-v10
mkdir workspace

git clone https://gitlab.com/Linaro/cca-public/shrinkwrap.git -b cca/v10
```

Export the required environment variables from the `cca-v10` directory:

```bash
export PATH=$PWD/shrinkwrap/shrinkwrap:$PATH
export WORKSPACE=$PWD/workspace
export SHRINKWRAP_BUILD=$PWD/workspace
export SHRINKWRAP_PACKAGE=$PWD/workspace/package
```

### 2. Build the base CCA stack

Run the initial CCA build:

```bash
shrinkwrap build cca-3world.yaml \
  --overlay=qemu/cca.yaml \
  --overlay=buildroot-cca.yaml
```

This downloads the required repositories and builds the base CCA software configuration.

### 3. Clone this repository

From the `cca-v10` directory:

```bash
git clone https://github.com/adiponzio/arm-cca-dice-poc.git
```

Enter the repository and run the installation script:

```bash
cd arm-cca-dice-poc
chmod +x install.sh
./install.sh
```

The installation script:

- applies the PoC patches to the **RMM**, **TF-A**, **Linux**, and **Buildroot external CCA** repositories;
- clones **Mbed TLS v3.6.3**;
- installs the custom Shrinkwrap configuration files required by the PoC.

## Build
From the `cca-v10` workspace, build the PoC with:

```bash
shrinkwrap build cca-3world.yaml \
  --overlay=qemu/cca.yaml \
  --overlay=buildroot-cca.yaml \
  --overlay=dice_layering.yaml \
  --overlay=dice_performance_measure.yaml \
  --no-sync-all
```

The `--no-sync-all` option prevents Shrinkwrap from synchronising the repositories at every build.

## Run

Start the emulated CCA environment with:

```bash
shrinkwrap run cca-3world.yaml
```

Shrinkwrap runs the emulation in a container by default.

### Using a fixed container image

To keep the same toolchain/runtime between builds and executions, a specific Shrinkwrap image can be selected.

For example:

```bash
shrinkwrap --image=shrinkwraptool/base-slim:2025.12.0 \
  build cca-3world.yaml \
  --overlay=qemu/cca.yaml \
  --overlay=buildroot-cca.yaml \
  --overlay=dice_layering.yaml \
  --overlay=dice_performance_measure.yaml \
  --no-sync-all
```

Run using the same image:

```bash
shrinkwrap --image=shrinkwraptool/base-slim:2025.12.0 \
  run cca-3world.yaml
```

## Using a Realm

Once the emulation has started, log into the normal-world console as `root`.

Launch a Realm with:

```bash
gen-run-vmm.sh --tap
```

To use `kvmtool` instead of QEMU:

```bash
gen-run-vmm.sh --tap --kvmtool
```

After the Realm has booted, log in as `root`.

The Realm provides the `cca_dice_demo` command for accessing the DICE operations exposed by the lower layers:

```bash
cca_dice_demo
```

Usage:

```text
Usage: cca_dice_demo <operation>

Available operations:
sign-rak : Sign payload using RAK
sign-rik : Sign payload using RIK
cert-rak : Get RAK public key certificate
cert-rik : Get RIK public key certificate
cert-chain : Get machine certificate chain
```

## DICE Operations

The demo application provides access to the cryptographic identity generated for the Realm environment.

The available operations allow you to:

| Operation | Description |
|---|---|
| `sign-rak` | Sign a payload using the Realm Attestation Key (RAK). |
| `sign-rik` | Sign a payload using the Realm Identity Key (RIK). |
| `cert-rak` | Retrieve the RAK public-key certificate. |
| `cert-rik` | Retrieve the RIK public-key certificate. |
| `cert-chain` | Retrieve the machine certificate chain. |


## Important PoC Limitation

The lower DICE layer is not available on the **QEMU SBSA** machine used by this PoC. Consequently, the cryptographic identity of the TF-A layer is hardcoded.

The hardcoded values are defined in:

```text
drivers/dice_layering/dice_layering_hardcoded.c
```

In particular, the file contains the functions used to provide:

- the initial CDI;
- the TF-A secret key;
- the TF-A certificate.

The CDI can be modified for experimentation. The secret key and certificate must, however, be generated consistently. The certificate included in the PoC is self-signed and is assumed by the upper layers when validating the certificate chain.

## Debugging

For debugging the firmware stack, QEMU can be launched directly on the host instead of inside the Shrinkwrap container.

This requires QEMU to be installed on the host.

Run:

```bash
shrinkwrap --runtime=null run cca-3world.yaml --overlay=qemu-dbg.yaml
```

The debug configuration starts QEMU with a GDB server and pauses execution until a debugger connects.

By default, the GDB server is available on:

```text
localhost:1234
```

A corresponding `.gdbinit` entry can be:

```text
target remote :1234
set architecture aarch64
```

### TF-A symbols

The TF-A binaries can be mapped in GDB with:

```text
add-symbol-file workspace/build/cca-3world/tfa/qemu_sbsa/debug/bl1/bl1.elf 0x0
add-symbol-file workspace/build/cca-3world/tfa/qemu_sbsa/debug/bl2/bl2.elf
add-symbol-file workspace/build/cca-3world/tfa/qemu_sbsa/debug/bl31/bl31.elf
```

### RMM symbols

For the RMM core, the following address is used with the PoC configuration:

```text
add-symbol-file workspace/build/cca-3world/rmm/Debug/rmm_core.elf 0x10000040000
```

The address may need to be adjusted when the number of compiled RMM applications changes.

### EL0 applications

EL0 applications share the same address space, so a breakpoint on an application address may be hit by another application instance.

The suggested debugging procedure is:

1. Pass the application's ELF file to GDB.
2. Set a breakpoint on the RMM stub that calls the target application function.
3. Continue execution until the stub breakpoint is hit.
4. Set a breakpoint on the target application function.
5. Continue execution.

## Configuration

The main Shrinkwrap configuration for the DICE integration is:

```text
dice_layering.yaml
```

The configuration enables the DICE layering functionality and specifies the Mbed TLS version used by the PoC.

Relevant configuration parameters include:

```text
DEBUG
LOG_LEVEL
DICE_LAYERING
MBEDTLS_DIR
CRYPTO_SUPPORT
PSA_CRYPTO
```

`DICE_LAYERING` controls whether the DICE functionality is enabled.

## Related Documentation

- [Arm CCA Shrinkwrap documentation](https://shrinkwrap.docs.arm.com/en/2026.6.0/)
- [Linaro CCA build instructions](https://gitlab.com/Linaro/cca-public/build-instructions/-/tree/cca/v10)
- [Tuxmake](https://tuxmake.org/)

## Thesis

This repository contains the Proof-of-Concept described in the Master's thesis:

**Integrating DICE with Arm CCA for Measurement Based Cryptographic Identity**
