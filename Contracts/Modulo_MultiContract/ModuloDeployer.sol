// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "erc721a/contracts/IERC721A.sol";
import "Contracts/Modulo_MultiContract/ModuloRaffle721A.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract ModuloDeployer is Ownable, VRFConsumerBaseV2, ReentrancyGuard {

struct RaffleTracker {

    ModuloRaffle721A RaffleAddress;
    address Winner;
    address PrizeNFTAddress;
    uint256 PrizeNFTID;
    uint256 GameNo;
    bool    GameComplete;

}

struct PrizeVault {

    address PrizeNFTAddress;
    uint256 PrizeNFTID;

}

    mapping(uint256 => RaffleTracker) public RaffleTrackerMapper;
    mapping(address => PrizeVault[])  public PrizeVaultMapper;

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
/////// Chainlink VRF - End

/// Game Settings
    uint     public price_d        = 0.01 ether;
    uint     public maxPerFree_d   = 1; 
    uint     public maxPerWallet_d = 10; 
    uint     public totalFree_d    = 10; 
    uint     public maxSupply_d    = 10;
    uint     public BlockDelay_d   = 1000;


/// Reference to current game 
    uint256       public currentGameNo; 
    RaffleTracker public CurrentGame;

    constructor()
    VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    }

    function create_New_Raffle(
                string calldata RaffleName_, 
                string calldata RaffleID_,
                address PrizeNFTAddress_,
                uint256 PrizeNFTID_) external onlyOwner  {


        require(CurrentGame.GameNo < 1 || 
                CurrentGame.GameComplete == true, "Game in Progress");


        IERC721A PrizeNFT = IERC721A(PrizeNFTAddress_);
        address  DeployerOwnerNFT = PrizeNFT.ownerOf(PrizeNFTID_);

        require(DeployerOwnerNFT == address(this), "Deposit NFT first");


        /// Do we need to save an old raffle?
        if(currentGameNo > 0){

            RaffleTrackerMapper[currentGameNo] = CurrentGame;
            delete CurrentGame;

        }

        /// Keep track of current game and use this as the Number
        currentGameNo = currentGameNo + 1;

        /// create a new Raffle
         CurrentGame.RaffleAddress = new ModuloRaffle721A(
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
        CurrentGame.GameNo          = currentGameNo;
        CurrentGame.PrizeNFTAddress = PrizeNFTAddress_;
        CurrentGame.PrizeNFTID      = PrizeNFTID_;

    }

    function change_GameSettings(
                uint _price,
                uint _maxPerFree,
                uint _maxPerWallet,
                uint _totalFree,
                uint _maxSupply,
                uint _BlockDelay) external onlyOwner {

        require(CurrentGame.GameComplete == true, "Game in Progress");

        price_d        = _price;
        maxPerFree_d   = _maxPerFree;
        maxPerWallet_d = _maxPerWallet;
        totalFree_d    = _totalFree;
        maxSupply_d    = _maxSupply;
        BlockDelay_d   = _BlockDelay;

    }

/// Chainlink - Start

    function call_Chainlink()  external onlyOwner   {

        bool isSoldout = Check_Soldout();

        require(isSoldout == true, "Raffle Not sold out yet");

        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );

    }

    function Check_Soldout() public  view returns (bool) {
        bool isSoldout = CurrentGame.RaffleAddress.Check_Soldout();
        return isSoldout;

    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        RandomNumber = randomWords[0];
        PickWinner();

    }

    function PickWinner()  private  {

        uint256 WinningTokenID =  (RandomNumber % maxSupply_d) + 1;
        CurrentGame.Winner = CurrentGame.RaffleAddress.ownerOf(WinningTokenID);
        require(CurrentGame.Winner != address(0), "Error getting Winner");
 
        /// Update Prize Tracker with winner
        PrizeVault memory Prize;

        Prize.PrizeNFTAddress = CurrentGame.PrizeNFTAddress;
        Prize.PrizeNFTID = CurrentGame.PrizeNFTID;

        /// Add to a list of winning NFT's
        PrizeVaultMapper[CurrentGame.Winner].push(Prize);

        // Current Raffle is Complete
        CurrentGame.GameComplete = true;
            
    }

    function is_Winner() public view returns (bool) {

        PrizeVault[] memory Prizes = PrizeVaultMapper[msg.sender];

        if(Prizes.length > 0){
            return true;
        } else {
            return false;
        }

    }

    function Withdraw_Prize() public nonReentrant {

        require(is_Winner() == true, "Not a Winner");
        PrizeVault[] storage Prizes = PrizeVaultMapper[msg.sender];

        _withdraw_NFT(Prizes[Prizes.length - 1].PrizeNFTAddress, Prizes[Prizes.length - 1].PrizeNFTID);
        Prizes.pop();
    
    }

    function _withdraw_NFT(address NFTAddress_, uint256 NFTID_) private {

        IERC721A PrizeNFT = IERC721A(NFTAddress_);

        PrizeNFT.transferFrom(
                    address(this),
                    msg.sender,
                    NFTID_);


    }

/// Owner Withdraw functions

    function withdraw_Funds() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function withdraw_NFT(address NFTAddress_, uint256 NFTID_) external onlyOwner nonReentrant {
            _withdraw_NFT(NFTAddress_, NFTID_);

    }

}