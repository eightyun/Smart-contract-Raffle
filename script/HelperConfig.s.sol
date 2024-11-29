//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18 ;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocsk/LinkToken.sol";

contract HelperConfig is Script 
{
    struct NewworkConfig
    {
        uint256 entranceFee;
        uint256 interval ; 
        address vrfCoordinator ; 
        bytes32 gasLane ;
        uint64 subscriptionId ;
        uint32 callbackGasLimit ;
        address link ;
    }

    NewworkConfig public activeNetworkConfig;

    constructor()
    {
        if(block.chainid == 11155111)
        {
            activeNetworkConfig = getSepoliaEthConfig();
        }
        else
        {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NewworkConfig memory) 
    {
        return NewworkConfig
        ({
            entranceFee: 0.01 ether,
            interval: 30 ,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34F823bc56c,
            subscriptionId: 1893,  
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NewworkConfig memory) 
    {
        if(activeNetworkConfig.vrfCoordinator != address(0))
        {
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether ;// 0.25LINK
        uint96 gasPrice = 1e9 ; // 1 gwei
        
        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(baseFee, gasPrice);
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return NewworkConfig
        ({
            entranceFee: 0.01 ether,
            interval: 30 ,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34F823bc56c,
            subscriptionId: 0,  
            callbackGasLimit: 500000, // 500,000 gas!
            link: address(link)
        });
    }
}