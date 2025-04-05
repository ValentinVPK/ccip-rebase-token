// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console, Test} from "forge-std/Test.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

import {RebaseToken} from "../src/RebaseToken.sol";

import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";

import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract CrossChainTest is Test {
    address owner = makeAddr("owner");
    address user = makeAddr("user");
    uint256 SEND_VALUE = 1e5;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;

    Vault vault;

    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepoliaPool;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    RegistryModuleOwnerCustom registryModuleOwnerCustomSepolia;
    RegistryModuleOwnerCustom registryModuleOwnerCustomArbSepolia;

    TokenAdminRegistry tokenAdminRegistrySepolia;
    TokenAdminRegistry tokenAdminRegistryArbSepolia;

    function setUp() public {
        address[] memory allowlist = new address[](0);

        // sourceDeployer = new SourceDeployer();

        // 1. Setup the Sepolia and arb forks
        sepoliaFork = vm.createSelectFork("sepolia-eth");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        //NOTE: what does this do?
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // 2. Deploy and configure on the source chain: Sepolia
        //sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        //(sourceRebaseToken, sourcePool, vault) = sourceDeployer.run(owner);
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        console.log("source rebase token address");
        console.log(address(sepoliaToken));
        console.log("Deploying token pool on Sepolia");
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            allowlist,
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        // deploy the vault
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        // add rewards to the vault
        vm.deal(address(vault), 1e18);
        // Set pool on the token contract for permissions on Sepolia
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        sepoliaToken.grantMintAndBurnRole(address(vault));
        // Claim role on Sepolia
        registryModuleOwnerCustomSepolia =
            RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress);
        registryModuleOwnerCustomSepolia.registerAdminViaOwner(address(sepoliaToken));
        // Accept role on Sepolia
        tokenAdminRegistrySepolia = TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress);
        tokenAdminRegistrySepolia.acceptAdminRole(address(sepoliaToken));
        // Link token to pool in the token admin registry on Sepolia
        tokenAdminRegistrySepolia.setPool(address(sepoliaToken), address(sepoliaPool));
        vm.stopPrank();

        // 3. Deploy and configure on the destination chain: Arbitrum
        // Deploy the token contract on Arbitrum
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        console.log("Deploying token on Arbitrum");
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        arbSepoliaToken = new RebaseToken();
        console.log("dest rebase token address");
        console.log(address(arbSepoliaToken));
        // Deploy the token pool on Arbitrum
        console.log("Deploying token pool on Arbitrum");
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            allowlist,
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        // Set pool on the token contract for permissions on Arbitrum
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        // Claim role on Arbitrum
        registryModuleOwnerCustomArbSepolia =
            RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress);
        registryModuleOwnerCustomArbSepolia.registerAdminViaOwner(address(arbSepoliaToken));
        // Accept role on Arbitrum
        tokenAdminRegistryArbSepolia = TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress);
        tokenAdminRegistryArbSepolia.acceptAdminRole(address(arbSepoliaToken));
        // Link token to pool in the token admin registry on Arbitrum
        tokenAdminRegistryArbSepolia.setPool(address(arbSepoliaToken), address(arbSepoliaPool));
        vm.stopPrank();

        configureTokenPool(
            sepoliaFork,
            TokenPool(address(sepoliaPool)),
            TokenPool(address(arbSepoliaPool)),
            IRebaseToken(address(arbSepoliaToken)),
            arbSepoliaNetworkDetails
        );
        configureTokenPool(
            arbSepoliaFork,
            TokenPool(address(arbSepoliaPool)),
            TokenPool(address(sepoliaPool)),
            IRebaseToken(address(sepoliaToken)),
            sepoliaNetworkDetails
        );
    }

    function configureTokenPool(
        uint256 fork,
        TokenPool localPool,
        TokenPool remotePool,
        IRebaseToken remoteToken,
        Register.NetworkDetails memory remoteNetworkDetails
    ) public {
        vm.selectFork(fork);
        vm.startPrank(owner);
        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1);
        // bytes[] memory remotePoolAddresses = new bytes[](1);
        // remotePoolAddresses[0] = abi.encode(address(remotePool));
        chains[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteNetworkDetails.chainSelector,
            remotePoolAddress: abi.encode(address(remotePool)),
            allowed: true,
            remoteTokenAddress: abi.encode(address(remoteToken)),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });
        localPool.applyChainUpdates(chains);
        vm.stopPrank();
    }

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        // Create the message to send tokens cross-chain
        vm.selectFork(localFork);
        vm.startPrank(user);
        Client.EVMTokenAmount[] memory tokenToSendDetails = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount =
            Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});
        tokenToSendDetails[0] = tokenAmount;
        // Approve the router to burn tokens on users behalf
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user), // we need to encode the address to bytes
            data: "", // We don't need any data for this example
            tokenAmounts: tokenToSendDetails, // this needs to be of type EVMTokenAmount[] as you could send multiple tokens
            extraArgs: "", // We don't need any extra args for this example
            feeToken: localNetworkDetails.linkAddress // The token used to pay for the fee
        });
        // Get and approve the fees
        vm.stopPrank();
        // Give the user the fee amount of LINK
        ccipLocalSimulatorFork.requestLinkFromFaucet(
            user, IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message)
        );
        vm.startPrank(user);
        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress,
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message)
        ); // Approve the fee
        // log the values before bridging
        uint256 balanceBeforeBridge = IERC20(address(localToken)).balanceOf(user);
        console.log("Local balance before bridge: %d", balanceBeforeBridge);

        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message); // Send the message
        uint256 sourceBalanceAfterBridge = IERC20(address(localToken)).balanceOf(user);
        console.log("Local balance after bridge: %d", sourceBalanceAfterBridge);
        assertEq(sourceBalanceAfterBridge, balanceBeforeBridge - amountToBridge);
        vm.stopPrank();

        vm.selectFork(remoteFork);
        // Pretend it takes 15 minutes to bridge the tokens
        vm.warp(block.timestamp + 900);
        // get initial balance on Arbitrum
        uint256 initialArbBalance = IERC20(address(remoteToken)).balanceOf(user);
        console.log("Remote balance before bridge: %d", initialArbBalance);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        console.log("Remote user interest rate: %d", remoteToken.getUserInterestRate(user));
        uint256 destBalance = IERC20(address(remoteToken)).balanceOf(user);
        console.log("Remote balance after bridge: %d", destBalance);
        assertEq(destBalance, initialArbBalance + amountToBridge);
    }

    function testBridgeAllTokens() public {
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_VALUE);
        vm.prank(user);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();

        assertEq(sepoliaToken.balanceOf(user), SEND_VALUE);
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaToken,
            arbSepoliaToken
        );

        vm.selectFork(arbSepoliaFork);
        vm.warp(block.timestamp + 20 minutes);
        bridgeTokens(
            arbSepoliaToken.balanceOf(user),
            arbSepoliaFork,
            sepoliaFork,
            arbSepoliaNetworkDetails,
            sepoliaNetworkDetails,
            arbSepoliaToken,
            sepoliaToken
        );
    }
}
