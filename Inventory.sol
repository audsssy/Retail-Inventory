// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import "./InventoryNFT.sol";

contract Inventory is InventoryNFT {
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
        string brand;
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

    error NoItemFound();

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
        InventoryNFT(name_, symbol_)
    {
        brand = msg.sender;
        lgt = msg.sender;
    }

    /*///////////////////////////////////////////////////////////////
                        INVENTORY LOGIC
    //////////////////////////////////////////////////////////////*/

    function createProduct(
        string calldata _brand,
        string calldata name,
        string[] memory variants,
        uint256[] calldata quantityPerVariant
    ) public OnlyBrand OnlyLegitimate {
        if (variants.length != quantityPerVariant.length) revert NoParity();
        if (variants.length == 0) revert NoProductFound();

        products[productId].brand = _brand;
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
        if (variants.length != quantityPerVariant.length) revert NoParity();
        if (products[_productId].variants.length == 0) revert NoProductFound();

        // Update existing product
        products[_productId].name = name;
        products[_productId].variants = variants;
        products[_productId].quantityPerVariant = quantityPerVariant;
    }

    function getProducts(uint256 tokenId) public view returns (string memory, string memory, string[] memory, uint256[] memory, uint256[4] memory) {
        string memory _brand = products[tokenId].brand;
        string memory _name = products[tokenId].name;
        string[] memory _variants = products[tokenId].variants;
        uint256[] memory _quantityPerVariant = products[tokenId].quantityPerVariant;
        uint256[4] memory _inventory = products[tokenId].inventory;

        return (_brand, _name, _variants, _quantityPerVariant, _inventory);
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

        // Check if item variant is valid and if quantity allows
        bool available = false;
        available = checkProductAvailability(totalSupply, variants.length);

        // Create new item
        if (available) {
            items[totalSupply].productId = _productId;
            items[totalSupply].owner = msg.sender;
            items[totalSupply].variants = variants;
            items[totalSupply].price = price;
            items[totalSupply].location = location;
            items[totalSupply].isChipped = isChipped;
            items[totalSupply].isDigitized = isDigitized;

            // Mint item
            _tokenURI[totalSupply] = uri;
            _mint(brand, totalSupply);
            totalSupply++;
        }
    }

    function updateItem(
        uint256[] calldata tokenIds,
        address owner,
        uint256 price,
        Location location,
        bool isChipped,
        bool isDigitized,
        string calldata uri
    ) public OnlyBrand OnlyLegitimate {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (ownerOf[tokenIds[i]] == address(0)) revert NoItemFound();
            items[tokenIds[i]].owner = owner;
            items[tokenIds[i]].price = price;
            items[tokenIds[i]].location = location;
            items[tokenIds[i]].isChipped = isChipped;
            items[tokenIds[i]].isDigitized = isDigitized;
            _tokenURI[tokenIds[i]] = uri;
        }
    }

    function getItemVariants(uint256 tokenId) public view returns (string[] memory) {
        return (items[tokenId].variants);
    }

    function readyForAuction(uint256[] calldata tokenIds)
        public
        OnlyBrand
        OnlyLegitimate
    {

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!items[tokenIds[i]].isChipped || !items[tokenIds[i]].isDigitized) {
                revert NotReadyForAuction();
            } else {
                items[tokenIds[i]].canAuction = true;
                bool available = checkProductAvailability(tokenIds[i], items[tokenIds[i]].variants.length);
                if (available) {
                    products[items[tokenIds[i]].productId].quantityPerVariant[i]--;
                    products[items[tokenIds[i]].productId].inventory[0]++;
                }
            }
        }
    }

    function checkProductAvailability(uint256 tokenId, uint256 _itemVariantLength) internal view returns (bool) {
        uint256 _productId = items[tokenId].productId;
        uint256 productVariantlength = products[_productId].variants.length;
        bool available = false;

        // Update Product inventory
        for (uint256 i = 0; i < productVariantlength; i++) {
            for (uint256 j = 0; j < _itemVariantLength; j++) {

                if (
                    compareStrings(
                        products[_productId].variants[i],
                        items[tokenId].variants[j]
                    )
                ) {
                    if (products[_productId].quantityPerVariant[i] == 0) revert MaxQuantityReached();
                } else {
                    revert NoProductFound();
                }
            }
        }

        available = true;
        return (available);
    }

    function setBidStatus(
        uint256[] calldata tokenIds,
        bool[] calldata isBidded
    ) public OnlyBrand OnlyLegitimate {
        if (tokenIds.length != isBidded.length) revert NoParity();

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (items[tokenIds[i]].canAuction && isBidded[i]) {
                if (products[items[tokenIds[i]].productId].inventory[0] == 0)
                    revert MaxQuantityReached();
                products[items[tokenIds[i]].productId].inventory[0]--;
                products[items[tokenIds[i]].productId].inventory[1]++;
                items[tokenIds[i]].hasBid = true;
            } else {
                revert ItemNotAvailableForAuction();
            }
        }
    }

    function setSaleStatus(uint256[] calldata tokenIds, bool[] calldata isSold)
        public
        OnlyBrand
        OnlyLegitimate
    {
        if (tokenIds.length != isSold.length) revert NoParity();

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (items[tokenIds[i]].hasBid && isSold[i]) {
                if (products[items[tokenIds[i]].productId].inventory[1] == 0)
                    revert MaxQuantityReached();
                products[items[tokenIds[i]].productId].inventory[1]--;
                products[items[tokenIds[i]].productId].inventory[2]++;
                items[tokenIds[i]].isSold = true;
            } else {
                revert ItemNotAvailableForAuction();
            }
        }
    }

    function setShippingStatus(
        uint256[] calldata tokenIds,
        bool[] calldata isShipped
    ) public OnlyBrand OnlyLegitimate {
        if (tokenIds.length != isShipped.length) revert NoParity();

        uint256 numberItemShipped;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (items[tokenIds[i]].canAuction && isShipped[i]) {
                numberItemShipped++;

                if (
                    numberItemShipped >
                    products[items[tokenIds[i]].productId].inventory[2]
                ) revert MaxQuantityReached();
                products[items[tokenIds[i]].productId].inventory[2]--;
                products[items[tokenIds[i]].productId].inventory[3]++;
                items[tokenIds[i]].isShipped = true;
                items[tokenIds[i]].location = Location.TRANSIT;
            } else {
                revert ItemNotAvailableForAuction();
            }
        }
    }

    function setDeliveryStatus(
        uint256[] calldata tokenIds,
        bool[] calldata isDelivered
    ) public OnlyBrand OnlyLegitimate {
        if (tokenIds.length != isDelivered.length) revert NoParity();

        for (uint256 i = 0; i < tokenIds.length; i++) {
            isDelivered[i]
                ? items[tokenIds[i]].location = Location.BUYER
                : items[tokenIds[i]].location = Location.TRANSIT;
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
