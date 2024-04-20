// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// IPFS integration
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title NFTMarketplace
 * @notice This contract implements an NFT marketplace with IPFS integration and various features for production-readiness.
 */
contract NFTMarketplace is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721URIStorage
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    /**
     * @dev Struct representing an NFT in the marketplace.
     * @param tokenId The unique identifier of the NFT.
     * @param owner The address of the current owner of the NFT.
     * @param name The name of the NFT.
     * @param description The description of the NFT.
     * @param price The sale price of the NFT in Wei.
     * @param isSold A flag indicating whether the NFT has been sold or not.
     * @param royaltyPercentage The percentage of the sale price to be paid as royalty.
     * @param royaltyRecipient The address to receive the royalty payment.
     * @param metadataURI The URI pointing to the metadata of the NFT on IPFS.
     */
    struct NFT {
        uint256 tokenId;
        address payable owner;
        string name;
        string description;
        uint256 price;
        bool isSold;
        uint8 royaltyPercentage;
        address payable royaltyRecipient;
        string metadataURI;
    }

    // Arrays to store listed NFTs
    NFT[] public nfts;

    // Mappings to store NFTs by keyword and owner
    mapping(string => uint256[]) public nftsByKeyword;
    mapping(address => uint256[]) public nftsByOwner;

    // Mapping to store token URI in IPFS integration
    mapping(uint256 => string) private _tokenURIs;

    // Events
    event NFTListed(
        uint256 indexed tokenId,
        address indexed owner,
        string name,
        string description,
        uint256 price,
        string metadataURI
    );
    event NFTBought(
        uint256 indexed tokenId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );
    event NFTTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to
    );
    event RoyaltyPaid(
        uint256 indexed tokenId,
        address indexed recipient,
        uint256 amount
    );

    /**
     * @dev Initializes the contract by setting the token name, symbol, and owner.
     */
    function initialize() public initializer {
        __ERC721_init("NFT Marketplace", "NFTM");
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    /**
     * @dev Lists a new NFT on the marketplace.
     * @param name The name of the NFT.
     * @param description The description of the NFT.
     * @param price The sale price of the NFT in Wei.
     * @param keyword A keyword associated with the NFT.
     * @param royaltyPercentage The percentage of the sale price to be paid as royalty.
     * @param royaltyRecipient The address to receive the royalty payment.
     * @param metadataURI The URI pointing to the metadata of the NFT on IPFS.
     */
    function listNFT(
        string memory name,
        string memory description,
        uint256 price,
        string memory keyword,
        uint8 royaltyPercentage,
        address payable royaltyRecipient,
        string memory metadataURI
    ) public onlyOwner {
        // Increment the token counter
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Create the NFT struct
        nfts.push(
            NFT(
                tokenId,
                payable(msg.sender),
                name,
                description,
                price,
                false,
                royaltyPercentage,
                royaltyRecipient,
                metadataURI
            )
        );

        // Update mappings
        nftsByKeyword[keyword].push(tokenId);
        nftsByOwner[msg.sender].push(tokenId);

        // Mint the NFT to the seller
        _mint(msg.sender, tokenId);

        // Set token URI for IPFS integration
        _setTokenURI(tokenId, metadataURI);

        // Emit the NFTListed event
        emit NFTListed(
            tokenId,
            msg.sender,
            name,
            description,
            price,
            metadataURI
        );
    }

    /**
     * @dev Allows a buyer to purchase a listed NFT.
     * @param tokenId The unique identifier of the NFT to be purchased.
     */
    function buyNFT(uint256 tokenId) public payable nonReentrant {
        // Retrieve the NFT struct
        NFT storage nft = nfts[tokenId];

        // Ensure the NFT is not already sold
        require(!nft.isSold, "NFT is already sold.");

        // Ensure the provided Ether is sufficient
        require(msg.value >= nft.price, "Not enough Ether provided.");

        // Calculate the royalty amount
        uint256 royaltyAmount = (nft.price * nft.royaltyPercentage) / 100;

        // Transfer the NFT ownership
        address oldOwner = nft.owner;
        nft.owner = payable(msg.sender);
        nft.isSold = true;
        _transfer(oldOwner, msg.sender, tokenId);

        // Transfer funds to the seller and royalty recipient
        oldOwner.transfer(msg.value - royaltyAmount);
        if (royaltyAmount > 0) {
            nft.royaltyRecipient.transfer(royaltyAmount);
            emit RoyaltyPaid(tokenId, nft.royaltyRecipient, royaltyAmount);
        }

        // Emit the NFTBought and NFTTransferred events
        emit NFTBought(tokenId, msg.sender, oldOwner, nft.price);
        emit NFTTransferred(tokenId, oldOwner, msg.sender);
    }

    /**
     * @dev Retrieves the NFTs associated with a specific keyword.
     * @param keyword The keyword to search for.
     * @return An array of token IDs associated with the given keyword.
     */
    function getNFTsByKeyword(string memory keyword)
        public
        view
        returns (uint256[] memory)
    {
        return nftsByKeyword[keyword];
    }

    /**
     * @dev Retrieves the NFTs owned by a specific address.
     * @param owner The address of the owner.
     * @return An array of token IDs owned by the given address.
     */
    function getNFTsByOwner(address owner)
    public
    view
    returns (uint256[] memory)
    {
    return nftsByOwner[owner];
    }

    /**
 * @dev Retrieves the metadata URI for a given token ID.
 * @param tokenId The token ID to retrieve the metadata URI for.
 * @return The metadata URI for the given token ID.
 */
function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
{
    require(
        _exists(tokenId),
        "ERC721Metadata: URI query for nonexistent token"
    );

    return _tokenURIs[tokenId];
}

/**
 * @dev Sets the metadata URI for a given token ID.
 * @param tokenId The token ID to set the metadata URI for.
 * @param metadataURI The metadata URI to be set.
 */
function _setTokenURI(uint256 tokenId, string memory metadataURI)
    internal
    virtual
{
    _tokenURIs[tokenId] = metadataURI;
}

/**
 * @dev Retrieves the metadata URI for a given token ID in a base64-encoded format (IPFS integration).
 * @param tokenId The token ID to retrieve the metadata URI for.
 * @return The base64-encoded metadata URI for the given token ID.
 */
function tokenURIBase64(uint256 tokenId)
    public
    view
    returns (string memory)
{
    require(
        _exists(tokenId),
        "ERC721Metadata: URI query for nonexistent token"
    );

    // Retrieve the NFT struct
    NFT storage nft = nfts[tokenId];

    // Encode the metadata as a JSON string
    string memory json = Base64.encode(
        bytes(
            string(
                abi.encodePacked(
                    '{"name": "',
                    nft.name,
                    '", "description": "',
                    nft.description,
                    '", "image": "',
                    nft.metadataURI,
                    '"}'
                )
            )
        )
    );

    // Prepend the base64-encoded JSON with the data URI scheme
    string memory output = string(
        abi.encodePacked("data:application/json;base64,", json)
    );

    return output;
}

/**
 * @dev Implements the bulk listing of NFTs (gas optimized).
 * @param names An array of names for the NFTs.
 * @param descriptions An array of descriptions for the NFTs.
 * @param prices An array of prices for the NFTs.
 * @param keywords An array of keywords for the NFTs.
 * @param royaltyPercentages An array of royalty percentages for the NFTs.
 * @param royaltyRecipients An array of royalty recipient addresses for the NFTs.
 * @param metadataURIs An array of metadata URIs for the NFTs.
 */
function bulkListNFTs(
    string[] memory names,
    string[] memory descriptions,
    uint256[] memory prices,
    string[] memory keywords,
    uint8[] memory royaltyPercentages,
    address payable[] memory royaltyRecipients,
    string[] memory metadataURIs
) public onlyOwner {
    require(
        names.length == descriptions.length &&
            descriptions.length == prices.length &&
            prices.length == keywords.length &&
            keywords.length == royaltyPercentages.length &&
            royaltyPercentages.length == royaltyRecipients.length &&
            royaltyRecipients.length == metadataURIs.length,
        "Array lengths must be equal"
    );

    for (uint256 i = 0; i < names.length; i++) {
        listNFT(
            names[i],
            descriptions[i],
            prices[i],
            keywords[i],
            royaltyPercentages[i],
            royaltyRecipients[i],
            metadataURIs[i]
        );
    }
}

/**
 * @dev Implements the bulk buying of NFTs (gas optimized).
 * @param tokenIds An array of token IDs to be purchased.
 */
function bulkBuyNFTs(uint256[] memory tokenIds) public payable nonReentrant {
    uint256 totalPrice = 0;
    for (uint256 i = 0; i < tokenIds.length; i++) {
        uint256 tokenId = tokenIds[i];
        NFT storage nft = nfts[tokenId];

        // Ensure the NFT is not already sold
        require(!nft.isSold, "NFT is already sold.");

        // Calculate the total price
        totalPrice += nft.price;
    }

    // Ensure the provided Ether is sufficient
    require(msg.value >= totalPrice, "Not enough Ether provided.");

    for (uint256 i = 0; i < tokenIds.length; i++) {
        uint256 tokenId = tokenIds[i];
        NFT storage nft = nfts[tokenId];

        // Calculate the royalty amount
        uint256 royaltyAmount = (nft.price * nft.royaltyPercentage) / 100;

        // Transfer the NFT ownership
        address oldOwner = nft.owner;
        nft.owner = payable(msg.sender);
        nft.isSold = true;
        _transfer(oldOwner, msg.sender, tokenId);

        // Transfer funds to the seller and royalty recipient
        oldOwner.transfer(nft.price - royaltyAmount);
        if (royaltyAmount > 0) {
            nft.royaltyRecipient.transfer(royaltyAmount);
            emit RoyaltyPaid(tokenId, nft.royaltyRecipient, royaltyAmount);
        }

        // Emit the NFTBought and NFTTransferred events
        emit NFTBought(tokenId, msg.sender, oldOwner, nft.price);
        emit NFTTransferred(tokenId, oldOwner, msg.sender);
    }
}