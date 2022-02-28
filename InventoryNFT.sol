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
        uint256[4] inventory; // [available, reserved, sold, shipped]
    }

    struct Item {
        uint256 productId;
        address[] owners;
        uint256 price;
        Location location;
        bool isChipped;
        bool isDigitized;
        bool readyForAuction;
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
        string[] calldata variants,
        uint256[] calldata quantity
    ) public OnlyBrand OnlyLegitimate {
        if (variants.length != quantity.length) revert NoParity();

        // Create new product
        products[productId].name = name;
        products[productId].variants = variants;
        products[productId].quantityPerVariant = quantity;

        // Check if total quantity matches across variants
        uint256 bufferCount;
        uint256 totalItemCount;
        for (uint256 i = 0; i < products[productId].variants.length; i++) {
            if (compareStrings(products[productId].variants[i], "BUFFER")) {
                bufferCount++;
            } else {
                totalItemCount += products[productId].quantityPerVariant[i];
            }
        }

        if (totalItemCount % bufferCount != 0) revert InvalidInventoryCount();

        productId++;
    }

    function mintItem(
        uint256 _productId,
        string[] calldata variants, // e.g., [XS, black]
        uint256 price,
        Location location,
        bool isChipped,
        bool isDigitized,
        string calldata uri // Not really necessary
    ) public virtual OnlyBrand OnlyLegitimate {
        if (compareStrings(products[_productId].name, ""))
            revert NoProductFound();

        // Create new item
        items[totalSupply].productId = _productId;
        items[totalSupply].owners.push(msg.sender);
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
                if (products[_productId].quantityPerVariant[i] == 0)
                    revert MaxQuantityReached();

                if (
                    compareStrings(
                        products[_productId].variants[i],
                        variants[j]
                    )
                ) {
                    products[_productId].quantityPerVariant[i]--;
                    products[_productId].inventory[0]++;
                } else {
                    revert NoVariantFound();
                }
            }
        }
    }

    function prepareItemForAuction(uint256[] calldata itemIds)
        public
        OnlyBrand
        OnlyLegitimate
    {
        for (uint256 i = 0; i < itemIds.length; i++) {
            if (items[itemIds[i]].isChipped && items[itemIds[i]].isDigitized) {
                items[itemIds[i]].readyForAuction == true;
            }
        }
    }

    function isItemBiddedOn(
        uint256[] calldata itemIds,
        bool[] calldata isBidded
    ) public OnlyBrand OnlyLegitimate {
        if (itemIds.length != isBidded.length) revert NoParity();

        uint256 numberItemBidded;

        for (uint256 i = 0; i < itemIds.length; i++) {
            if (items[itemIds[i]].readyForAuction && isBidded[i]) {
                numberItemBidded++;

                if (
                    numberItemBidded >
                    products[items[itemIds[i]].productId].inventory[0]
                ) revert MaxQuantityReached();
                products[items[itemIds[i]].productId].inventory[0]--;
                products[items[itemIds[i]].productId].inventory[1]++;
            } else {
                revert ItemNotAvailableForAuction();
            }
        }
    }

    function isItemSold(uint256[] calldata itemIds, bool[] calldata isSold)
        public
        OnlyBrand
        OnlyLegitimate
    {
        if (itemIds.length != isSold.length) revert NoParity();

        uint256 numberItemSold;

        for (uint256 i = 0; i < itemIds.length; i++) {
            if (items[itemIds[i]].readyForAuction && isSold[i]) {
                numberItemSold++;

                if (
                    numberItemSold >
                    products[items[itemIds[i]].productId].inventory[1]
                ) revert MaxQuantityReached();
                products[items[itemIds[i]].productId].inventory[1]--;
                products[items[itemIds[i]].productId].inventory[2]++;
                items[itemIds[i]].isSold = true;
            } else {
                revert ItemNotAvailableForAuction();
            }
        }
    }

    function isItemShipped(
        uint256[] calldata itemIds,
        bool[] calldata isShipped
    ) public OnlyBrand OnlyLegitimate {
        if (itemIds.length != isShipped.length) revert NoParity();

        uint256 numberItemShipped;

        for (uint256 i = 0; i < itemIds.length; i++) {
            if (items[itemIds[i]].readyForAuction && isShipped[i]) {
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

    function isItemDelivered(
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

    function updateProduct(
        uint256 _productId,
        string calldata name,
        string[] calldata variants,
        uint256[] calldata quantity
    ) public OnlyBrand OnlyLegitimate {
        if (variants.length != quantity.length) revert NoParity();

        // Update existing product
        products[_productId].name = name;
        products[_productId].variants = variants;
        products[_productId].quantityPerVariant = quantity;
    }

    function updateItem(
        uint256[] calldata itemIds,
        uint256 price,
        Location location,
        bool isChipped,
        bool isDigitized,
        bool isShipped,
        string calldata uri
    ) public OnlyBrand OnlyLegitimate {
        for (uint256 i = 0; i < itemIds.length; i++) {
            items[itemIds[i]].price = price;
            items[itemIds[i]].location = location;
            items[itemIds[i]].isChipped = isChipped;
            items[itemIds[i]].isDigitized = isDigitized;
            items[itemIds[i]].isShipped = isShipped;
            _tokenURI[itemIds[i]] = uri;
        }
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
