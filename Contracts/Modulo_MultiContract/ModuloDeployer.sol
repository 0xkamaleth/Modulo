// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "erc721a/contracts/IERC721A.sol";
import "Contracts/Modulo_MultiContract/ModuloRaffle721A.sol";

contract ModuloDeployer is Ownable, ReentrancyGuard {

struct RaffleTracker {

    ModuloRaffle721A RaffleAddress;
    uint256 GameNo;
    address Winner;
    address PrizeNFTAddress;
    uint256 PrizeNFTID;
    uint256 ChainlinkRequestID;
    uint256 ChainlinkRandomNumber;
    bool    GameComplete;

}

/// Game Settings
    uint     public Raffle_price        = 0.01 ether;
    uint     public Raffle_maxPerFree   = 1; 
    uint     public Raffle_maxPerWallet = 10; 
    uint     public Raffle_totalFree    = 249; 
    uint     public Raffle_maxSupply    = 999;
    uint     public Raffle_BlockDelay   = 10000;


/// Reference to current game and past games
    uint256       public currentGameNo; 
    RaffleTracker public CurrentRaffle;
    mapping(uint256 => RaffleTracker) public RaffleTrackerMapper;




    function create_New_Raffle(
                string calldata RaffleName_, 
                string calldata RaffleID_,
                address PrizeNFTAddress_,
                uint256 PrizeNFTID_) external onlyOwner  {


        require(CurrentRaffle.GameNo < 1 || 
                CurrentRaffle.GameComplete == true, "Game in Progress - Cannot start a new one");


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
            Raffle_maxSupply,
            Raffle_totalFree,
            Raffle_maxPerWallet,
            Raffle_maxPerFree,
            Raffle_price,
            Raffle_BlockDelay,
            RaffleName_,
            RaffleID_
        );

        /// Setup Raffle Details
        CurrentRaffle.GameNo          = currentGameNo;
        CurrentRaffle.PrizeNFTAddress = PrizeNFTAddress_;
        CurrentRaffle.PrizeNFTID      = PrizeNFTID_;

    }

    function change_GameSettings(
                uint _price,
                uint _maxPerFree,
                uint _maxPerWallet,
                uint _totalFree,
                uint _maxSupply,
                uint _BlockDelay) external onlyOwner {

        require(CurrentRaffle.GameComplete == true, "Game in Progress - Cannot changes settings");

        Raffle_price        = _price;
        Raffle_maxPerFree   = _maxPerFree;
        Raffle_maxPerWallet = _maxPerWallet;
        Raffle_totalFree    = _totalFree;
        Raffle_maxSupply    = _maxSupply;
        Raffle_BlockDelay   = _BlockDelay;


    }

    function withdraw_Funds() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function withdraw_Prize_NFT() external onlyOwner nonReentrant {

        /// Only used for emergencies 
        IERC721A PrizeNFT = IERC721A(CurrentRaffle.PrizeNFTAddress);
        PrizeNFT.transferFrom(address(this), msg.sender, CurrentRaffle.PrizeNFTID);

    }

}