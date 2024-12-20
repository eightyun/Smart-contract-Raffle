//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18 ;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {console , Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test
{
    /**Event */
    event RaffleEnter(address indexed player) ;

    Raffle raffle ;
    HelperConfig helperConfig ;

    uint256 entranceFee;
    uint256 interval ;
    address vrfCoordinator ;
    bytes32 gasLane ;
    uint64 subscriptionId ;
    uint32 callbackGasLimit ;
    address link ;

    address public PLAYER = makeAddr("player") ;
    uint256 public constant STARTING_USER_BALANCE = 10 ether ;

    function setUp() external
    {
        DeployRaffle deployer = new DeployRaffle() ;
        (raffle , helperConfig) = deployer.run() ;

        (
            entranceFee,
            interval ,
            vrfCoordinator ,
            gasLane ,
            subscriptionId ,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig() ;

        vm.deal(PLAYER, STARTING_USER_BALANCE) ; // make player address has some eth
    }

    function testRaffleInitializesInOpenState() public view 
    {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN) ;
    }

    //////////////////////
    // enterRaffle      //
    //////////////////////

    function testRaffleRevertsWhenYouDontPayEnough() public
    {
        vm.prank(PLAYER) ; // mock
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public 
    {
        vm.prank(PLAYER) ; // mock
        raffle.enterRaffle{value: entranceFee} ();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public
    {
        vm.prank(PLAYER);
        vm.expectEmit(true , false , false , false , address(raffle));  // make sure next emit can run
        emit RaffleEnter(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // make sure exceed the interval
        vm.roll(block.number + 1); 
        raffle.performUpkepp("") ;

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////////////////
    // cheakUpkeep      //
    //////////////////////
    function testCheckUpkeepReturnsFalseIfIthasNobalance() public
    {
        // Arrange
        vm.warp(block.timestamp + interval + 1); // make sure spend enough time
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded , ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded == false);

    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public
    {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // make sure spend enough time
        vm.roll(block.number + 1);
        raffle.performUpkepp("");

        // Act
        (bool upkeepNeeded , ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded == false);
    }

    //////////////////////
    // performUpkeep    //
    //////////////////////
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public
    {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // make sure spend enough time
        vm.roll(block.number + 1);

        //Act / Assert
        raffle.performUpkepp("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public
    {
        uint256 currenBalance = 0 ;
        uint256 numPlayers = 0 ;
        uint256 raffleState = 0 ;
        vm.expectRevert(
            abi.encodeWithSelector(
            Raffle.Raffle__UpkeepNotNeeded.selector, 
            currenBalance , 
            numPlayers ,
            raffleState
            )
        );
 
        raffle.performUpkepp("");
    }

    modifier raffleEnteredAndTimePassed()
    {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // make sure spend enough time
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed
    {
        // get requestId from emit
        vm.recordLogs();
        raffle.performUpkepp("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    //////////////////////
    // fulfillRandomWords  //
    //////////////////////
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEnteredAndTimePassed()
    {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));

    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed()
    {
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++)
        {
            address player = address(uint160(i));
            hoax(player , STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}(); 
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        // get requestId from emit
        vm.recordLogs();
        raffle.performUpkepp("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp() ;

        // pretend to be chainlink vrf to get random number & pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + prize - entranceFee);
    }
}