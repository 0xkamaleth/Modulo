// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract BlottoRaffle is ERC721A, Ownable, ReentrancyGuard {


/// Set by Constructor
    uint     public price;
    uint     public maxPerWallet; 
    uint     public totalFree; 
    uint     public maxSupply;
    uint     public BlockDelay;
    address  public BlottoVault;


///  Variables
    uint   public  startTokenID = 1;       /// Start Token ID
    uint   public  totalFreeMinted = 0;  
    uint   public  maxPerFree = 1;
    uint   public  MinDrawBlock = 99999999999; // Starting Delay
    bool   public  drawEnabled = false;
    bool   public  Soldout = false;
    bool   public  WhitelistOnly = true;
    string public  baseURI = "ipfs://FilledByConstructor/";


    mapping(address => uint256) public mintedFreeAmount;
    mapping(address => uint256) public totalMintedAmount;
    mapping(address => bool)    public whitelistedAddresses;

    constructor(
        uint maxSupply_,
        uint totalFree_,
        uint maxPerWallet_,
        uint price_,
        uint BlockDelay_,
        string memory Name_,
        string memory Id_,
        string memory URI_
        )
    ERC721A(Name_, Id_) 
    {
        maxSupply = maxSupply_;
        totalFree = totalFree_;
        maxPerWallet = maxPerWallet_;
        price = price_;
        BlockDelay = BlockDelay_;
        baseURI = URI_;
        BlottoVault = msg.sender;

        /// Set Modulo deployer wallet not smart contract as owner
        _transferOwnership(tx.origin);

    }

//// Mint Methods - Start

   modifier mintChecks {
        require(msg.sender == tx.origin, "The minter is another contract");
        require(drawEnabled, "Ticket sales not live yet");
      _;
   }


    function free_Ticket() external mintChecks  {

        uint256 count = maxPerFree;

        if(WhitelistOnly == true){
            require(Check_WhiteList(msg.sender) == true, "Not on Whitelist");
        }

        require(totalSupply() + count <= maxSupply, "Sold Out!");
        require(totalFreeMinted + count <= totalFree, "Free tickets sold out");
        require(mintedFreeAmount[msg.sender] < maxPerFree, "Free ticket already claimed");
        require(totalMintedAmount[msg.sender] + count <= maxPerWallet, "Exceed maximum tickets per wallet");

        totalMintedAmount[msg.sender] += maxPerFree;
        mintedFreeAmount[msg.sender] = maxPerFree;

        totalFreeMinted += maxPerFree;
        _safeMint(msg.sender, count);

        /// Soldout flag
        if(_totalMinted() == maxSupply){
            MinDrawBlock = block.number + BlockDelay;
            Soldout = true;
        }

    }
    

    function paid_Ticket(uint256 count) external payable mintChecks {

        uint256 cost = price;

        require(totalSupply() + count <= maxSupply, "Sold Out!");
        require(totalMintedAmount[msg.sender] + count <= maxPerWallet, "Exceed maximum tickets per wallet");
        require(msg.value >= count * cost, "Please send the exact ETH amount");

        totalMintedAmount[msg.sender] += count;
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

    function Check_DelayOver() external  view returns (bool) {
        if(MinDrawBlock < block.number){
            return true;
        } else {
            return false;
        }

    }

    function Check_WhiteList(address _whitelistedAddress) public view returns(bool) {
        bool userIsWhitelisted = whitelistedAddresses[_whitelistedAddress];
        return userIsWhitelisted;
    }


///// Admin Methods

    function set_BaseUri(string memory baseURI_) external  onlyOwner {
        baseURI = baseURI_;
    }

    function toggle_WhiteList() external onlyOwner {
        WhitelistOnly = !WhitelistOnly;
    }


    function toggle_Raffle() external onlyOwner {
        drawEnabled = !drawEnabled;
    }

    function add_WhiteList(address _addressToWhitelist) external onlyOwner {

        whitelistedAddresses[_addressToWhitelist] = true;

    }

    function add_WhiteList_bulk(address[] calldata _addressToWhitelist) external onlyOwner {

       for(uint i =0; i < _addressToWhitelist.length; i++){  
        whitelistedAddresses[_addressToWhitelist[i]] = true;
        }   
    }

    function withdraw_Funds() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

}