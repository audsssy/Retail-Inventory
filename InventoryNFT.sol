// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import "./ERC721.sol";

contract InventoryNFT is ERC721 {

    /*///////////////////////////////////////////////////////////////
                            INVENTORY STORAGE

        - A brand should only need 1 InventoryNFT contract
        - A brand may have multiple products
        - Each product may have multiple items 
        - Each item is repped by a token id
    //////////////////////////////////////////////////////////////*/

    address public brand; // Default to Legitimate Team
    mapping(uint256 => Product) public products; // A 
    mapping(uint256 => Item) public items; 
    mapping(uint256 => string) private _tokenURI;

    struct Product {
        string name;
        string[] variants; // e.g., [XS, S, M, L, XL, 0, 0, 0, black, red, white]
        uint256[] quantityPerVariant;
        uint256[3] inventory; // [available, reserved, sold]
    }

    struct Item {
        address[] owners;
        uint256 price;
        Location location;
        bool chip;
        bool digitization;
        bool shipped; 
    }

    enum Location {
        SELLER,
        LGT_HQ,
        LGT_PARNTERS,
        TRANSIT,
        BUYER
    }

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotBrand();

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier OnlyBrand {
        if (msg.sender != brand) revert NotBrand();
        _;
    }


    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        brand = msg.sender;
    }
    
    function tokenURI(uint256 tokenId) public view override virtual returns (string memory) {
        return _tokenURI[tokenId];
    }

    function mint(
        uint256 tokenId,
        string calldata uri // Not really necessary
    ) public virtual {
        _mint(brand, totalSupply++);

        _tokenURI[tokenId] = uri;
    }

    function burn(uint256 tokenId) public virtual {
        if (msg.sender != ownerOf[tokenId]) revert NotOwner();

        _burn(tokenId);
    }

    function updateBrand(address _brand) public OnlyBrand {
        brand = _brand;
    }
}