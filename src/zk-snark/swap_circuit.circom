pragma circom 2.0.0;

include "./pedersen_hash.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";

template Swap() {
    signal input secret;
    signal input amount;
    signal input nullifier;

    signal output commitment; 
    signal output nullifierHash[2];

    component poseidonAmount = Poseidon(2);
    poseidonAmount.inputs[0] <== amount;
    poseidonAmount.inputs[1] <== secret;

    // Init PedersenHash & calculate nullifierHash
    component pedersenNullifier = PedersenHash();
    pedersenNullifier.message[0] <== nullifier;
    pedersenNullifier.message[1] <== secret;

    commitment <== poseidonAmount.out;
    nullifierHash <== pedersenNullifier.out;
}

component main { public [secret, amount, nullifier] } = Swap();