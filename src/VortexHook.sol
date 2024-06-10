// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Verifier} from "./Verifier.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";

contract VortexHook is BaseHook {

    Verifier public verifier;

    constructor(IPoolManager _poolManager, address _verifier) BaseHook(_poolManager) {
        verifier = Verifier(_verifier);
    }

    struct Deposit {
        uint256 amount;
        bytes32 commitment;
        bool isDeposited;
    }

    // Mapping to store deposits by their commitment hash
    mapping(bytes32 => Deposit) public deposits;
    // Mapping to store nullifiers to prevent double-spending
    mapping(bytes32 => bool) public nullifierHashes;

    // Event to log deposits
    event DepositMade(bytes32 indexed commitment, uint256 amount);
    // Event to log withdrawals
    event WithdrawalMade(bytes32 indexed nullifierHash, uint256 amount);

    // Required override function for BaseHook to let the PoolManager know which hooks are implemented
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    // Custom function to handle deposits and withdrawals before swap
    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata data
    ) external override poolManagerOnly returns (bytes4, BeforeSwapDelta, uint24) {
        // Initialize return values
        BeforeSwapDelta hookReturn = BeforeSwapDeltaLibrary.ZERO_DELTA;
        uint24 lpFeeOverride = 0;

        if (data.length == 32) {
            // If data length is 32 bytes, it's a deposit (single bytes32 commitment)
            handleDeposit(params, data);
        } else if (data.length > 32) {
            handleWithdrawal(params, data);
        } else {
            revert("Invalid data length");
        }

        return (this.beforeSwap.selector, hookReturn, lpFeeOverride);
    }

    // Function to handle deposits
    function handleDeposit(IPoolManager.SwapParams calldata params, bytes calldata data) internal {
        bytes32 commitment = abi.decode(data, (bytes32));
        uint256 amount = params.amountSpecified < 0 ? uint256(-params.amountSpecified) : uint256(params.amountSpecified);
        require(!deposits[commitment].isDeposited, "Commitment already used");

        // Store the deposit
        deposits[commitment] = Deposit(amount, commitment, true);
        emit DepositMade(commitment, amount);
    }

    // Function to handle withdrawals
    function handleWithdrawal(IPoolManager.SwapParams calldata params, bytes calldata data) internal {
        // Extract proof and public inputs from data
        (bytes memory proofData, bytes32 nullifierHash, bytes32 commitment, address recipient) = abi.decode(data, (bytes, bytes32, bytes32, address));

        // Decode proof data
        (uint256[2] memory a, uint256[2][2] memory b, uint256[2] memory c) = abi.decode(proofData, (uint256[2], uint256[2][2], uint256[2]));

        require(!nullifierHashes[nullifierHash], "Nullifier already used");
        require(nullifierHash != commitment, "Commitment and nullifier hashes are the same");
        require(deposits[commitment].isDeposited, "Invalid commitment");

        // Prepare public signals array for the verifier
        uint256[6] memory publicSignals;
        publicSignals[0] = uint256(10348950757350049702628021365919022170479029582700334119946882062710206178767);
        publicSignals[1] = uint256(7106845738133882086345912894961481425204400941108340403951013321794263700711);
        // Remaining not necessary for withdrawal
        for (uint i = 2; i < 6; i++) {
            publicSignals[i] = 0;
        }

        // Verify the zkSNARK proof
        // Values from proof.json
        uint256[2] memory pi_a = [
            9497567230519425519140177318339445016316992098894186225726648406755798259870,
            21442461557068561253756413994899207418519450418022744063599399384433487298856
        ];

        uint256[2][2] memory pi_b = [
            [
                11974574328802228680057789687364806766197173014102462139651327950798441070030,
                13100445052234158208279417881448890310866867197035637425491790604562616057859
            ],
            [
                19202825055794763438647522695620140449978775148165615664178192337715216113182,
                992476132492344631891059923581253037093777950068675687305227749298911308855
            ]
        ];

        uint256[2] memory pi_c = [
            18991928417620617629091370600547995824698157439040754320654198370187948896147,
            10447128771979825493599205213099979302220537112798967422861799012278703232668
        ];
        require(verifier.verifyProof(pi_a, pi_b, pi_c, publicSignals), "Invalid proof");

        // TODO: handle the withdrawal via swap

        // Mark the nullifier as used
        nullifierHashes[nullifierHash] = true;

        // Transfer the amount to the recipient
        uint256 amount = deposits[commitment].amount;
        deposits[commitment].isDeposited = false; // Mark deposit as withdrawn
        payable(recipient).transfer(amount);

        emit WithdrawalMade(nullifierHash, amount);
    }

    // Function to verify the nullifier hash
    function verifyNullifierHash(bytes32 nullifierHash, uint256 amount, bytes32 secret) internal view returns (bool) {
        bytes32 calculatedHash = keccak256(abi.encodePacked(amount, secret));
        return nullifierHashes[nullifierHash] || deposits[calculatedHash].isDeposited;
    }
}
