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
    uint256 public productId;
    mapping(uint256 => Product) public products;
    mapping(uint256 => Item) public items;
    mapping(uint256 => string) private _tokenURI;

    struct Product {
        string name;
        string[] variants; // e.g., [XS, S, M, L, XL, BUFFER, black, red, white, BUFFER]
        uint256[] quantityPerVariant;
        uint256[4] inventory; // [available, reserved, sold, shipped]
    }

    struct Item {
        uint256 productId;
        address owner;
        string[] variants;
        uint256 price;
        Location location;
        bool isChipped;
        bool isDigitized;
        bool canAuction;
        bool hasBid;
        bool isSold;
        bool isShipped;
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

    error NoProductFound();

    error QuantityMismatch();

    error NotReadyForAuction();
    
    error NoVariantFound();

    error ItemNotAvailableForAuction();

    error MaxQuantityReached();

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
        string[] memory variants,
        uint256[] calldata quantityPerVariant
    ) public OnlyBrand OnlyLegitimate {
        if (variants.length != quantityPerVariant.length) revert NoParity();

        products[productId].name = name;
        products[productId].variants = variants;
        products[productId].quantityPerVariant = quantityPerVariant;
        productId++;
    }

    function updateProduct(
        uint256 _productId,
        string calldata name,
        string[] memory variants,
        uint256[] calldata quantityPerVariant
    ) public OnlyBrand OnlyLegitimate {
        if (products[_productId].variants.length == 0) revert NoProductFound();
        if (variants.length != quantityPerVariant.length) revert NoParity();

        // Update existing product
        products[_productId].name = name;
        products[_productId].variants = variants;
        products[_productId].quantityPerVariant = quantityPerVariant;
    }

    function mintItem(
        uint256 _productId,
        string[] memory variants, // e.g., [XS, black]
        uint256 price,
        Location location,
        bool isChipped,
        bool isDigitized,
        string calldata uri // Not really necessary
    ) public virtual OnlyBrand OnlyLegitimate {
        if (_productId > productId) revert NoProductFound();

        // Create new item
        items[totalSupply].productId = _productId;
        items[totalSupply].owner = msg.sender;
        items[totalSupply].variants = variants;
        items[totalSupply].price = price;
        items[totalSupply].location = location;
        items[totalSupply].isChipped = isChipped;
        items[totalSupply].isDigitized = isDigitized;

        // Mint item
        _tokenURI[totalSupply] = uri;
        _mint(brand, totalSupply++);

        // Update Product inventory
        for (uint256 i = 0; i < products[_productId].variants.length; i++) {
            for (uint256 j = 0; j < variants.length; j++) {

                if (
                    compareStrings(
                        products[_productId].variants[i],
                        variants[j]
                    )
                ) {
                    if (products[_productId].quantityPerVariant[i] == 0) revert MaxQuantityReached();
                    products[_productId].quantityPerVariant[i]--;
                    products[_productId].inventory[0]++;
                }
            }
        }
    }

    function updateItem(
        uint256[] calldata itemIds,
        address owner,
        uint256 price,
        Location location,
        bool isChipped,
        bool isDigitized,
        string calldata uri
    ) public OnlyBrand OnlyLegitimate {
        for (uint256 i = 0; i < itemIds.length; i++) {
            items[itemIds[i]].owner = owner;
            items[itemIds[i]].price = price;
            items[itemIds[i]].location = location;
            items[itemIds[i]].isChipped = isChipped;
            items[itemIds[i]].isDigitized = isDigitized;
            _tokenURI[itemIds[i]] = uri;
        }
    }

    function readyForAuction(uint256[] calldata itemIds)
        public
        OnlyBrand
        OnlyLegitimate
    {
        for (uint256 i = 0; i < itemIds.length; i++) {
            if (!items[itemIds[i]].isChipped || !items[itemIds[i]].isDigitized) {
                revert NotReadyForAuction();
            } else {
                items[itemIds[i]].canAuction = true;
            }
        }
    }

    function setBidStatus(
        uint256[] calldata itemIds,
        bool[] calldata isBidded
    ) public OnlyBrand OnlyLegitimate {
        if (itemIds.length != isBidded.length) revert NoParity();

        for (uint256 i = 0; i < itemIds.length; i++) {
            if (items[itemIds[i]].canAuction && isBidded[i]) {
                if (products[items[itemIds[i]].productId].inventory[0] == 0)
                    revert MaxQuantityReached();
                products[items[itemIds[i]].productId].inventory[0]--;
                products[items[itemIds[i]].productId].inventory[1]++;
                items[itemIds[i]].hasBid = true;
            } else {
                revert ItemNotAvailableForAuction();
            }
        }
    }

    function setSaleStatus(uint256[] calldata itemIds, bool[] calldata isSold)
        public
        OnlyBrand
        OnlyLegitimate
    {
        if (itemIds.length != isSold.length) revert NoParity();

        for (uint256 i = 0; i < itemIds.length; i++) {
            if (items[itemIds[i]].hasBid && isSold[i]) {
                if (products[items[itemIds[i]].productId].inventory[1] == 0)
                    revert MaxQuantityReached();
                products[items[itemIds[i]].productId].inventory[1]--;
                products[items[itemIds[i]].productId].inventory[2]++;
                items[itemIds[i]].isSold = true;
            } else {
                revert ItemNotAvailableForAuction();
            }
        }
    }

    function setShippingStatus(
        uint256[] calldata itemIds,
        bool[] calldata isShipped
    ) public OnlyBrand OnlyLegitimate {
        if (itemIds.length != isShipped.length) revert NoParity();

        uint256 numberItemShipped;

        for (uint256 i = 0; i < itemIds.length; i++) {
            if (items[itemIds[i]].canAuction && isShipped[i]) {
                numberItemShipped++;

                if (
                    numberItemShipped >
                    products[items[itemIds[i]].productId].inventory[2]
                ) revert MaxQuantityReached();
                products[items[itemIds[i]].productId].inventory[2]--;
                products[items[itemIds[i]].productId].inventory[3]++;
                items[itemIds[i]].isShipped = true;
                items[itemIds[i]].location = Location.TRANSIT;
            } else {
                revert ItemNotAvailableForAuction();
            }
        }
    }

    function setDeliveryStatus(
        uint256[] calldata itemIds,
        bool[] calldata isDelivered
    ) public OnlyBrand OnlyLegitimate {
        if (itemIds.length != isDelivered.length) revert NoParity();

        for (uint256 i = 0; i < itemIds.length; i++) {
            isDelivered[i]
                ? items[itemIds[i]].location = Location.BUYER
                : items[itemIds[i]].location = Location.TRANSIT;
        }
    }

    /*///////////////////////////////////////////////////////////////
                        ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function burn(uint256 tokenId) public virtual OnlyBrand OnlyLegitimate {
        for (uint256 i = 0; i < products[items[tokenId].productId].variants.length; i++) {
            for (uint256 j = 0; j < items[tokenId].variants.length; j++) {
                if (
                    compareStrings(
                        products[items[tokenId].productId].variants[i],
                        items[tokenId].variants[j]
                    )
                ) {
                    if (products[items[tokenId].productId].inventory[0] == 0) revert MaxQuantityReached();
                    
                    // Update Product inventory according to Item status
                    if (items[tokenId].canAuction && !items[tokenId].hasBid) { products[items[tokenId].productId].inventory[0]--; }
                    if (items[tokenId].hasBid && !items[tokenId].isSold) { products[items[tokenId].productId].inventory[1]--; }
                    if (items[tokenId].isSold && !items[tokenId].isShipped) { products[items[tokenId].productId].inventory[2]--; }
                    if (items[tokenId].isShipped) { products[items[tokenId].productId].inventory[3]--; }
                } else {
                    revert NoVariantFound();
                }
            }
        } 
        
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
                        OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function updateBrand(address _brand) public OnlyBrand OnlyLegitimate {
        brand = _brand;
    }

    /*///////////////////////////////////////////////////////////////
                            HELPER
    //////////////////////////////////////////////////////////////*/

    function compareStrings(string memory a, string memory b)
        public
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }
}
