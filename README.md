# Vortex Protocol
_ZK-SNARK Mixer Based on UniV4 Hook._

</header>

**fully decentralized**  **non-custodial**  **protocol** allowing private transactions  
 Using CFMM stablecoin pool - LPs will benefit from high fee utility pool with no impermanent loss.

Vortex Protocol uses [Pedersen](https://iden3-docs.readthedocs.io/en/latest/iden3_repos/research/publications/zkproof-standards-workshop-2/pedersen-hash/pedersen.html) Hash and [Circom](https://docs.circom.io/) Circuit Compiler.

![VortexProtocol](https://lw3cdn.learnweb3.io/hackathons/hookathon-c1/submissions/0288ead9-9208-49ae-acb0-df5832a17c94/dd15229b-cdf6-4109-b63b-9053437cd8a1)

---
**Install**

    git clone https://github.com/iden3/circom.git
    cd circom
    cargo build --release
    cargo install --path circom

**Compile & Test Circuit**

    circom swap_circuit.circom --r1cs --wasm --sym
    snarkjs powersoftau new bn128 12 pot12_0000.ptau
    snarkjs powersoftau contribute pot12_0000.ptau pot12_0001.ptau --name="First contribution" -v
    snarkjs powersoftau prepare phase2 pot12_0001.ptau pot12_final.ptau
    snarkjs groth16 setup swap_circuit.r1cs pot12_final.ptau swap_circuit.zkey
    snarkjs zkey contribute swap_circuit.zkey swap_circuit_final.zkey --name="First contribution" -v
    snarkjs zkey export verificationkey swap_circuit_final.zkey verification_key.json
    node swap_circuit_js/generate_witness.js swap_circuit_js/swap_circuit.wasm input.json witness.wtns
    snarkjs groth16 prove swap_circuit_final.zkey witness.wtns proof.json public.json
    snarkjs groth16 verify verification_key.json public.json proof.json
    snarkjs zkey export solidityverifier swap_circuit_final.zkey Verifier.sol
