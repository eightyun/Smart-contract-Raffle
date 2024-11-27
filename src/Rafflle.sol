// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

//  SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle Contract
 * @author Patrick Collins
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRF v2
 */
contract Raffle is VRFConsumerBaseV2
{
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen() ;

    /** Type declarations */
    enum RaffleState
    {
        OPEN,           // 0
        CALCULATING    // 1 

    } 

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;

    // @dev Duration of the lottery in seconds
    uint256 private immutable i_interval;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64  private immutable i_subscriptionId;
    uint32  private immutable i_callbackGasLimit;

    uint256 private s_lastTimeStamp ;
    address payable [] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event RaffleEnter(address indexed player);
    event PickedWinner(address indexed winner);

    constructor(uint256 entranceFee, 
                uint256 interval , 
                address vrfCoordinator , 
                bytes32 gasLane ,
                uint64 subscriptionId,
                uint32 callbackGasLimit) VRFConsumerBaseV2(vrfCoordinator)
    {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable
    {
        if(msg.value < i_entranceFee) 
        {
            revert Raffle__NotEnoughEthSent();
        }

        if(s_raffleState != RaffleState.OPEN)
        {
            revert Raffle__RaffleNotOpen() ;
        }

        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    function pickWinner() external
    {
        if(block.timestamp - s_lastTimeStamp < i_interval)
        {
            revert();
        }

        s_raffleState = RaffleState.CALCULATING;

        // get random number from chainlink vrf
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,              // gas lane
            i_subscriptionId,       // subscription id
            REQUEST_CONFIRMATIONS,  // request block 
            i_callbackGasLimit,       // callbackfunciont to use max gas
            NUM_WORDS              // The number of random numbers
        );
    }

    // override chainlink vrf function for was use 
    function fulfillRandomWords(uint256 requestId , uint256[] memory randomWords) internal override
    {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0); // reboot the array
        s_lastTimeStamp = block.timestamp;   // reboot the timestamp

        emit PickedWinner(winner) ;

        (bool success , ) = winner.call{value: address(this).balance}("");
        if(!success)
        {
            revert Raffle__TransferFailed();   
        }

        
    } 

    function getEntranceFee() public view returns (uint256)
    {
        return i_entranceFee;
    }
}