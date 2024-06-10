pragma circom 2.1.9;
include "../../node_modules/circomlib/circuits/pedersen.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";

template PedersenHash() {
    signal input message[2];
    signal output out[2];
    
    component pedersen = Pedersen(256);
    component inputBits0 = Num2Bits(128);
    component inputBits1 = Num2Bits(128);

    inputBits0.in <== message[0];
    inputBits1.in <== message[1];

    for(var i=0; i<128; i++){
        pedersen.in[i] <== inputBits0.out[i];
        pedersen.in[i+128] <== inputBits1.out[i];
    }

    out[0] <== pedersen.out[0];
    out[1] <== pedersen.out[1];
}