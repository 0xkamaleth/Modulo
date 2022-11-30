// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "erc721a/contracts/ERC721A.sol";

contract SimpleNFT is ERC721A {


///  Variables
    uint   public startTokenID = 1;       /// Start Token ID
    string public baseURI = "ipfs://abcdef/";


    constructor()
    ERC721A("Simple NFT", "XYZ") 
    {

    }


    function mint() external  {
        _safeMint(msg.sender, 1);
    }
    
    function _baseURI() internal view override returns (string memory) {
            return baseURI;
    }


    function _startTokenId() internal view virtual override returns (uint256) {
        return startTokenID;
    }

}