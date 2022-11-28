// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "erc721a/contracts/IERC721A.sol";
import "Contracts/Modulo_MultiContract/ModuloRaffle721A.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract ModuloDeployer is Ownable, VRFConsumerBaseV2 {

struct RaffleTracker {

    IERC721A AddressInstance;
    ModuloRaffle721A RaffleAddress;
    uint256 GameNo;
    address PrizeNFTAddress;
    uint256 PrizeNFTID;
    address Winner;
    bool    GameComplete;

}
/// Chainlink = start
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId = 2624;
    address vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
    bytes32 keyHash = 	0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
    uint32 callbackGasLimit = 2500000;
    uint16 requestConfirmations = 10;
    uint32   public numWords =  1;
    uint256  public s_requestId;
    uint256  public RandomNumber;
    uint     public fakerandom = 115792089237316195423570985008687907853269984665;
/////// Chainlink VRF - End

/// Game Settings
    uint     public price_d        = 1 ether;
    uint     public maxPerFree_d   = 1; 
    uint     public maxPerWallet_d = 10; 
    uint     public totalFree_d    = 250; 
    uint     public maxSupply_d    = 250;
    uint     public BlockDelay_d   = 10000;


/// Reference to current game and past games
    uint256       public currentGameNo; 
    RaffleTracker public CurrentRaffle;
    mapping(uint256 => RaffleTracker) public RaffleTrackerMapper;

    constructor()
    VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    }

    function create_New_Raffle(
                string calldata RaffleName_, 
                string calldata RaffleID_,
                address PrizeNFTAddress_,
                uint256 PrizeNFTID_) external onlyOwner  {


        require(CurrentRaffle.GameNo < 1 || 
                CurrentRaffle.GameComplete == true, "Game in Progress");


        IERC721A PrizeNFT = IERC721A(PrizeNFTAddress_);
        address  DeployerOwnerNFT = PrizeNFT.ownerOf(PrizeNFTID_);

        require(DeployerOwnerNFT == address(this), "Deposit NFT first");


        /// Do we need to save an old raffle?
        if(currentGameNo > 0){

            RaffleTrackerMapper[currentGameNo] = CurrentRaffle;
            delete CurrentRaffle;

        }

        /// Keep track of current game and use this as the Number
        currentGameNo = currentGameNo + 1;

        /// create a new Raffle
         CurrentRaffle.RaffleAddress = new ModuloRaffle721A(
            maxSupply_d,
            totalFree_d,
            maxPerWallet_d,
            maxPerFree_d,
            price_d,
            BlockDelay_d,
            RaffleName_,
            RaffleID_
        );

        /// Setup Raffle Details
        CurrentRaffle.GameNo          = currentGameNo;
        CurrentRaffle.PrizeNFTAddress = PrizeNFTAddress_;
        CurrentRaffle.PrizeNFTID      = PrizeNFTID_;
        CurrentRaffle.AddressInstance = PrizeNFT;

    }

    function change_GameSettings(
                uint _price,
                uint _maxPerFree,
                uint _maxPerWallet,
                uint _totalFree,
                uint _maxSupply,
                uint _BlockDelay) external onlyOwner {

        require(CurrentRaffle.GameComplete == true, "Game in Progress");

        price_d        = _price;
        maxPerFree_d   = _maxPerFree;
        maxPerWallet_d = _maxPerWallet;
        totalFree_d    = _totalFree;
        maxSupply_d    = _maxSupply;
        BlockDelay_d   = _BlockDelay;

    }

/// Chainlink - Start

    function call_Chainlink()  external onlyOwner   {

        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );

    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        RandomNumber = randomWords[0];
        PickWinner();

    }

    function PickWinner()  private  {

        uint256 WinningTokenID =  (RandomNumber % maxSupply_d) + 1;
        CurrentRaffle.Winner = CurrentRaffle.AddressInstance.ownerOf(WinningTokenID);
        require(CurrentRaffle.Winner != address(0), "Error getting Winner");
        CurrentRaffle.AddressInstance.transferFrom(address(this), CurrentRaffle.Winner, CurrentRaffle.PrizeNFTID);
        CurrentRaffle.GameComplete = true;

    }



    function withdraw_Funds() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function withdraw_Prize_NFT() external onlyOwner {
        CurrentRaffle.AddressInstance.transferFrom(address(this), msg.sender, CurrentRaffle.PrizeNFTID);

    }

}