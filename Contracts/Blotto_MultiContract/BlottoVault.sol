// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "erc721a/contracts/IERC721A.sol";
import "Contracts/Blotto_MultiContract/BlottoRaffle.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract BlottoVault is Ownable, VRFConsumerBaseV2, ReentrancyGuard {

struct RaffleTracker {

    BlottoRaffle RaffleAddress;
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
    VRFCoordinatorV2Interface private COORDINATOR;
    uint64   private s_subscriptionId = 2624;
    address  private vrfCoordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
    bytes32  private keyHash = 	0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
    uint32   private callbackGasLimit = 2500000;
    uint16   private requestConfirmations = 10;
    uint32   private numWords =  1;
    uint256  private s_requestId;
    uint256  private RandomNumber;
/////// Chainlink VRF - End

/// Game Settings
    uint     public price_d        = 0.01 ether;
    uint     public maxPerWallet_d = 2; 
    uint     public totalFree_d    = 5; 
    uint     public maxSupply_d    = 10;
    uint     public BlockDelay_d   = 200000;


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
                string calldata URI_,
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
         CurrentGame.RaffleAddress = new BlottoRaffle(
            maxSupply_d,
            totalFree_d,
            maxPerWallet_d,
            price_d,
            BlockDelay_d,
            RaffleName_,
            RaffleID_,
            URI_
        );

        /// Setup Raffle Details
        CurrentGame.GameNo          = currentGameNo;
        CurrentGame.PrizeNFTAddress = PrizeNFTAddress_;
        CurrentGame.PrizeNFTID      = PrizeNFTID_;

    }

    function change_GameSettings(
                uint _price,
                uint _maxPerWallet,
                uint _totalFree,
                uint _maxSupply,
                uint _BlockDelay) external onlyOwner {

        require(CurrentGame.GameComplete == true, "Game in Progress");

        price_d        = _price;
        maxPerWallet_d = _maxPerWallet;
        totalFree_d    = _totalFree;
        maxSupply_d    = _maxSupply;
        BlockDelay_d   = _BlockDelay;

    }

/// Chainlink - Start

    function call_Chainlink()  external onlyOwner   {

        bool isReady = Check_DrawReady();

        require(isReady == true, "Raffle Not sold out yet");
        require(CurrentGame.GameComplete = false, "Winner Already picked!");

        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );

    }

    function Check_DrawReady() public view returns (bool) {
        bool isSoldout;
        
        isSoldout = CurrentGame.RaffleAddress.Check_Soldout();
        isSoldout = CurrentGame.RaffleAddress.Check_DelayOver();

        return isSoldout;

    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        
        RandomNumber = randomWords[0];

        require(requestId == s_requestId, "Request ID not the same");
        require(CurrentGame.GameComplete = false, "Winner Already picked!");
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

    function Withdraw_Prize() external  nonReentrant {

        require(is_Winner() == true, "Not a Winner");
        PrizeVault[] storage Prizes = PrizeVaultMapper[msg.sender];

        /// Always withdraw the last prize
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