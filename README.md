#aws-lotus-packer

Packer script to generate an AMI for AWS configured to run lotus for filecoin mining on Amazon Web Services. Used for Filecoin Space Race 1.

Uses g4dn.8xlarge instance and the deep learning Ubuntu AMI. Lotus must be compiled on the instance that you plan to use.

Installs Go, Rust + Cargo, numactl, compiles NVTOP for monitoring GPU processes, edits ulimits, and adds useful shortcuts to bashrc.

Prefetchs filecoin proofs for 32GiB sectors.

Expected build time ~1-2 hours.

Note: Packer scripts run as root user
