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
    address public lgt;
    mapping(uint256 => Product) public products;
    uint256 public productId;
    mapping(uint256 => Item) public items;
    mapping(uint256 => string) private _tokenURI;

    struct Product {
        string name;
        string[] variants; // e.g., [XS, S, M, L, XL, BUFFER, black, red, white, BUFFER]
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

    error NoParity();

    error InvalidInventoryCount();

    error NotLegitimate();

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier OnlyBrand() {
        if (msg.sender != brand) revert NotBrand();
        _;
    }

    modifier OnlyLegitimate() {
        if (msg.sender != lgt) revert NotLegitimate();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {
        brand = msg.sender;
        lgt = msg.sender;
    }

    /*///////////////////////////////////////////////////////////////
                            INVENTORY LOGIC
    //////////////////////////////////////////////////////////////*/

    function createProduct(
        string calldata name,
        string[] calldata variants,
        uint256[] calldata quantity,
        uint256[3] calldata inventory
    ) public OnlyBrand OnlyLegitimate {
        if (variants.length != quantity.length) revert NoParity();

        // Create new product
        products[productId].name = name;
        products[productId].variants = variants;
        products[productId].quantityPerVariant = quantity;
        products[productId].inventory = inventory;

        // Check if total quantity matches across variants
        uint256 bufferCount;
        uint256 count;
        for (uint256 i = 0; i < products[productId].variants.length; i++) {
            if (compareStrings(products[productId].variants[i], "BUFFER")) {
                bufferCount++;
            } else {
                count += products[productId].quantityPerVariant[i];
            }
        }

        if (count % bufferCount != 0) revert InvalidInventoryCount();

        productId++;
    }

    function mintItem(
        string calldata name,
        string calldata variant,
        uint256 price,
        Location location,
        bool chip,
        bool digitization,
        bool shipped,
        string calldata uri // Not really necessary
    ) public virtual OnlyBrand OnlyLegitimate {
        // Create new item
        items[totalSupply].owners.push(msg.sender);
        items[totalSupply].price = price;
        items[totalSupply].location = location;
        items[totalSupply].chip = chip;
        items[totalSupply].digitization = digitization;
        items[totalSupply].shipped = shipped;

        // Mint new item
        _tokenURI[totalSupply] = uri;
        _mint(brand, totalSupply++);

        // Update Product inventory
        
    }

    function updateStatus(
        uint256 price,
        Location location,
        bool chip,
        bool digitization,
        bool shipped,
        string calldata uri
    ) public OnlyBrand OnlyLegitimate {
        items[totalSupply].price = price;
        items[totalSupply].location = location;
        items[totalSupply].chip = chip;
        items[totalSupply].digitization = digitization;
        items[totalSupply].shipped = shipped;
        _tokenURI[totalSupply] = uri;
    }

    /*///////////////////////////////////////////////////////////////
                            ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function burn(uint256 tokenId) public virtual OnlyBrand OnlyLegitimate {
        _burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return _tokenURI[tokenId];
    }

    /*///////////////////////////////////////////////////////////////
                            MISC
    //////////////////////////////////////////////////////////////*/

    function updateBrand(address _brand) public OnlyBrand OnlyLegitimate {
        brand = _brand;
    }

    function compareStrings(string memory a, string memory b)
        public
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }
}
