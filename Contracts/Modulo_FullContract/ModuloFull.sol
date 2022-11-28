// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/IERC721A.sol";


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";


contract ModuloNFT is ERC721A, Ownable, ReentrancyGuard, VRFConsumerBaseV2 {

    address  public constant ModuloDeployer = 0x20e3FB6e2726E1a9B947263d24790910838a5616;

    string public baseURI = "ipfs://COMINGSOON/";
    uint   public price             = 0.01 ether;
    uint   public startTokenID      = 1;       /// Start Token ID
    uint   public maxPerFree        = 1;       /// Max amount of free tickets per wallet
    uint   public maxPerWallet      = 5;      /// Max Per wallet - free + paid
    uint   public totalFree         = 3;      /// Total Free Tickets
    uint   public maxSupply         = 10;    /// Total Tickets
    uint   public totalFreeMinted = 0;
    bool   public drawEnabled = true;
    bool   public Soldout = false;

/// Chainlink = start
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId = 2624;
    address vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;
    bytes32 keyHash = 	0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    uint32 callbackGasLimit = 2500000;
    uint16 requestConfirmations = 10;
    uint32 private numWords =  1;
    uint256 private s_requestId;
    uint256 public RandomNumber;
/////// Chainlink VRF - End

/// Modulo Raffle Variables
    // uint     public fakerandom = 11579208923731619542357098500868790785326998466564056403945758400;
    IERC721A public PrizeNFT;
    uint     public NFTid;
    uint     public MinDrawBlock; /// block number to perform draw
    uint     public BlockDelay = 100; /// Amount of blocks to delay
    uint256  public WinningTokenID;
    address  public WinningTokenHolder;
    bool     public ChainlinkStarted = false;


    mapping(address => uint256) public _mintedFreeAmount;
    mapping(address => uint256) public _totalMintedAmount;

    constructor()
    ERC721A("Modulo Test", "MOD#1") 
    VRFConsumerBaseV2(vrfCoordinator) {

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);


    }


//// Mint Methods - Start

    function freeTicket() external  {

        uint256 count = maxPerFree;

        require(msg.sender == tx.origin, "The minter is another contract");
        require(drawEnabled, "Ticket sales not live yet");
        require(totalSupply() + count <= maxSupply, "Sold Out!");

        require(totalFreeMinted + count <= totalFree, "Free tickets sold out");
        require(_mintedFreeAmount[msg.sender] < maxPerFree, "Free ticket already claimed");

        _totalMintedAmount[msg.sender] += maxPerFree;
        _mintedFreeAmount[msg.sender] = maxPerFree;

        totalFreeMinted += maxPerFree;
        _safeMint(msg.sender, count);

        /// Soldout flag
        if(totalSupply() == maxSupply){
            MinDrawBlock = block.number + BlockDelay;
            Soldout = true;
        }

    }
    

    function paidTicket(uint256 count) external payable {

        uint256 cost = price;

        require(msg.sender == tx.origin, "The minter is another contract");
        require(drawEnabled, "Ticket sales not live yet");
        require(totalSupply() + count <= maxSupply, "Sold Out!");
        require(_totalMintedAmount[msg.sender] + count <= maxPerWallet, "Exceed maximum tickets per wallet");
        require(msg.value >= count * cost, "Please send the exact ETH amount");

        _totalMintedAmount[msg.sender] += count;
        _safeMint(msg.sender, count);

        /// Soldout flag
        if(totalSupply() == maxSupply){
            MinDrawBlock = block.number + BlockDelay;
            Soldout = true;
        }

    }

//// Mint Methods - End

/// Pick Winner with Chainlink VRF

    function startChainlink()  external onlyOwner   {

        require(block.number > MinDrawBlock, "Draw can't be started yet");
        require(Soldout == true, "Draw not soldout yet");
        require(ChainlinkStarted == false, "Draw already started");

        // Start Chainlink - CallBack will start the draw
        ChainlinkStarted = true;

        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );



    }

    // Callback for random number   
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        RandomNumber = randomWords[0];
        PickWinner();
    }


    function PickWinner()  private  {

        WinningTokenID =  (RandomNumber % maxSupply) + 1;
        // WinningTokenID =  (fakerandom % maxSupply) + 1;
        WinningTokenHolder = ownerOf(WinningTokenID);
        SendNFT();

    }

    function SendNFT()  private  {

        PrizeNFT.transferFrom(address(this), WinningTokenHolder, NFTid);

    }



//// Public Methods - Start

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {

        require(_exists(_tokenId),"ERC721Metadata: URI query for nonexistent token");
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI,Strings.toString(_tokenId),".json"))
            : "";
    }

    function _baseURI() internal view override returns (string memory) {
            return baseURI;
    }


    function _startTokenId() internal view virtual override returns (uint256) {
        return startTokenID;
    }


///// Admin Methods

    function setBaseUri(string memory baseURI_) external  onlyOwner {
        baseURI = baseURI_;
    }


    function setNFTPrize(address NFTAddress_, uint NFTid_) external onlyOwner {

        PrizeNFT = IERC721A(NFTAddress_);
        address Holder = PrizeNFT.ownerOf(NFTid_);

        require(Holder == address(this), "Deposit NFT first");
        NFTid = NFTid_;


    }

    function toggleRaffle() external onlyOwner {
      drawEnabled = !drawEnabled;
    }

    function withdrawFunds() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }



}