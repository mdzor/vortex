// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {Verifier} from "../src/Verifier.sol";
import {VortexHook} from "../src/VortexHook.sol";
import {HookMiner} from "./utils/HookMiner.sol";

contract VortexHookTest is Test, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    VortexHook hook;
    Verifier verifier;

    uint256[6] public publicSignals = [
        10348950757350049702628021365919022170479029582700334119946882062710206178767,
        7106845738133882086345912894961481425204400941108340403951013321794263700711,
        20174539379539423050504750187002670232292930346096343810711356488132818469794,
        9999999999,
        1000000000000000000,
        1234567890
    ];

    function setUp() public {
        // Deploy v4-core
        deployFreshManagerAndRouters();

        // Deploy, mint tokens, and approve all periphery contracts for two tokens
        (currency0, currency1) = deployMintAndApprove2Currencies();

        // Deploy Verifier contract
        verifier = new Verifier();

        // Deploy our hook with the proper flags
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);

        // Set gas price = 10 gwei and deploy our hook
        vm.txGasPrice(1 gwei);
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(VortexHook).creationCode,
            abi.encode(address(manager), address(verifier))
        );
        hook = new VortexHook{salt: salt}(
            IPoolManager(address(manager)),
            address(verifier)
        );
        require(
            address(hook) == hookAddress,
            "CounterTest: hook address mismatch"
        );

        // Initialize a pool
        (key, ) = initPool(
            currency0,
            currency1,
            hook,
            3000,
            SQRT_PRICE_4_1,
            ZERO_BYTES
        );

        // Add some liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 100 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    function testDeposit() public {
        // Set up the deposit param & swap
        IPoolManager.SwapParams memory depositParams = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: 1 ether,
            sqrtPriceLimitX96: SQRT_PRICE_1_1
        });
        bytes memory depositData = abi.encode(
            bytes32(keccak256("commitment_hash"))
        );

        swapRouter.swap(
            key,
            depositParams,
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            depositData
        );

        // Verify the deposit
        bytes32 commitment = keccak256(abi.encodePacked("commitment_hash"));
        (uint256 amount, , bool isDeposited) = hook.deposits(commitment);
        assertEq(amount, 1 ether);
        assertTrue(isDeposited);
    }

    function testDepositAndWithdrawal() public {
        // Set up the deposit param & swap
        IPoolManager.SwapParams memory depositParams = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: 1 ether,
            sqrtPriceLimitX96: SQRT_PRICE_1_1
        });

        bytes memory depositData = abi.encode(bytes32(publicSignals[1]));
        swapRouter.swap(
            key,
            depositParams,
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            depositData
        );

        // Verify the deposit
        bytes32 commitment = bytes32(publicSignals[1]);
        (uint256 amount, bytes32 cmt, bool isDeposited) = hook.deposits(
            commitment
        );
        assertEq(amount, 1 ether);
        assertTrue(isDeposited);

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

        bytes memory proof = abi.encode(pi_a, pi_b, pi_c, publicSignals);
        bytes memory withdrawalData = abi.encode(
            proof,
            publicSignals[0],
            publicSignals[1],
            address(this)
        );

        // Conduct a withdrawal
        swapRouter.swap(
            key,
            depositParams,
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            withdrawalData
        );

        // Verify the withdrawal
        (amount, cmt, isDeposited) = hook.deposits(commitment);
        assertFalse(isDeposited);
    }
}
