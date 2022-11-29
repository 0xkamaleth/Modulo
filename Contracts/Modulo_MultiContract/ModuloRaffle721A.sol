// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract ModuloRaffle721A is ERC721A, Ownable, ReentrancyGuard {


/// Set by Constructor
    uint     public price;
    uint     public maxPerFree; 
    uint     public maxPerWallet; 
    uint     public totalFree; 
    uint     public maxSupply;
    address  public ModuloDeployer;
    uint     public BlockDelay;


///  Variables
    uint   public startTokenID = 1;       /// Start Token ID
    uint   public totalFreeMinted = 0;
    uint   public MinDrawBlock;
    bool   public drawEnabled = false;
    bool   public Soldout = false;
    string public baseURI = "ipfs://COMINGSOON/";


    mapping(address => uint256) public _mintedFreeAmount;
    mapping(address => uint256) public _totalMintedAmount;

    constructor(
        uint maxSupply_,
        uint totalFree_,
        uint maxPerWallet_,
        uint maxPerFree_,
        uint price_,
        uint BlockDelay_,
        string memory Name,
        string memory Id
        )
    ERC721A(Name, Id) 
    {
        maxSupply = maxSupply_;
        totalFree = totalFree_;
        maxPerWallet = maxPerWallet_;
        maxPerFree = maxPerFree_;
        price = price_;
        BlockDelay = BlockDelay_;
        ModuloDeployer = msg.sender;

        /// Set Modulo deployer wallet not smart contract as owner
        _transferOwnership(tx.origin);

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
        if(_totalMinted() == maxSupply){
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
        if(_totalMinted() == maxSupply){
            MinDrawBlock = block.number + BlockDelay;
            Soldout = true;
        }

    }

//// Mint Methods - End


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

    function Check_Soldout() external  view returns (bool) {
        return Soldout;

    }


///// Admin Methods

    function setBaseUri(string memory baseURI_) external  onlyOwner {
        baseURI = baseURI_;
    }


    function toggleRaffle() external onlyOwner {
        drawEnabled = !drawEnabled;
    }

    function withdrawFunds() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }



}