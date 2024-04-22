// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

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
    ReentrancyGuardUpgradeable
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
        uint256 price_in_wei;
        bool isSold;
        uint8 royaltyPercentage;
        address payable royaltyRecipient;
        string metadataURI;
    }

    // Arrays to store listed NFTs
    NFT[] public nfts;

    // Mapping to keep track of existing tokens
    mapping(uint256 => bool) private _tokenExists;

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
        __ERC721_init("Creative Ferry NFT Marketplace", "CFNFTM");
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
    }

    /**
     * @dev Lists a new NFT on the marketplace.
     * @param name The name of the NFT.
     * @param description The description of the NFT.
     * @param price_in_ether The sale price of the NFT in Wei.
     * @param keywords An array of keywords associated with the NFT.
     * @param royaltyPercentage The percentage of the sale price to be paid as royalty.
     * @param royaltyRecipient The address to receive the royalty payment. This address is assigned by the NFT creator and continue to receive royalties in perpertuity for all secondary sales of their work.
     * @param metadataURI The URI pointing to the metadata of the NFT on IPFS.
     */
    function listNFT(
        string memory name,
        string memory description,
        uint256 price_in_ether,
        string[] memory keywords,
        uint8 royaltyPercentage,
        address payable royaltyRecipient,
        string memory metadataURI
    ) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        // Increment the token counter
        _tokenIdCounter.increment();

        // Convert the price from Ether to Wei
        uint256 price_in_wei = price_in_ether * 1 ether;

        // Create the NFT struct
        NFT memory newNFT = NFT(
            tokenId,
            payable(msg.sender),
            name,
            description,
            price_in_wei,
            false,
            royaltyPercentage,
            royaltyRecipient,
            metadataURI
        );

        nfts.push(newNFT);

        // Update mappings
        _tokenExists[tokenId] = true;
        for (uint256 i = 0; i < keywords.length; i++) {
            nftsByKeyword[keywords[i]].push(tokenId); // Update the mapping for each keyword
        }
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
            price_in_ether,
            metadataURI
        );
    }

    function listNFTForSale(uint256 tokenId, uint256 _price_in_ether) public {
        require(
            ownerOf(tokenId) == msg.sender,
            "Only the owner can list the NFT for sale"
        );
        require(_price_in_ether > 0, "Price must be greater than zero");

        setNewNFTPrice(tokenId, _price_in_ether);
    }

    /**
     * @dev Checks if a token exists in the marketplace.
     * @param tokenId The token ID to check for existence.
     * @return A boolean indicating whether the token exists or not.
     */
    function tokenExists(uint256 tokenId) public view returns (bool) {
        return _tokenExists[tokenId];
    }

    /**
     * @dev Retrieves the isSold value for a given token ID.
     * @param tokenId The token ID to retrieve the isSold value for.
     * @return The isSold value for the given token ID.
     */
    function getNFTIsSold(uint256 tokenId) public view returns (bool) {
        require(_tokenExists[tokenId], "NFT does not exist.");
        return nfts[tokenId].isSold;
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

        // Ensure the buyer is not the owner of the NFT
        require(nft.owner != msg.sender, "Cannot buy your own NFT.");

        // Ensure the provided Ether is sufficient
        require(msg.value >= nft.price_in_wei, "Not enough Ether provided.");

        // Calculate the royalty amount
        uint256 royaltyAmount = (nft.price_in_wei * nft.royaltyPercentage) /
            100;

        // Transfer the NFT ownership
        address payable oldOwner = nft.owner;
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
        emit NFTBought(tokenId, msg.sender, oldOwner, nft.price_in_wei);
        emit NFTTransferred(tokenId, oldOwner, msg.sender);
    }

    /**
     * @dev Retrieves the NFTs associated with a specific keyword.
     * @param keyword The keyword to search for.
     * @return An array of token IDs associated with the given keyword.
     */
    function getNFTsByKeyword(
        string memory keyword
    ) public view returns (uint256[] memory) {
        return nftsByKeyword[keyword];
    }

    /**
     * @dev Function to retrieve all listed NFTs on the marketplace.
     * @return An array of NFT structs representing the listed NFTs.
     */
    function getAllListedNFTs() public view returns (NFT[] memory) {
        // Count the number of listed NFTs
        uint256 listedNFTsCount = 0;
        for (uint256 i = 0; i < nfts.length; i++) {
            if (!nfts[i].isSold) {
                listedNFTsCount++;
            }
        }

        // Create a new array to store the listed NFTs
        NFT[] memory listedNFTs = new NFT[](listedNFTsCount);
        uint256 index = 0;

        // Iterate over the nfts array and add listed NFTs to the listedNFTs array
        for (uint256 i = 0; i < nfts.length; i++) {
            if (!nfts[i].isSold) {
                listedNFTs[index] = nfts[i];
                index++;
            }
        }

        // Return the array of listed NFTs
        return listedNFTs;
    }

    function setNewNFTPrice(uint256 tokenId, uint256 newPrice) public {
        require(
            _tokenExists[tokenId],
            "ERC721Metadata: URI query for nonexistent token"
        );
        require(
            ownerOf(tokenId) == msg.sender,
            "Only the owner can update the price"
        );

        nfts[tokenId].price_in_wei = newPrice;
    }

    /**
     * @dev Retrieves the NFTs tokenIds owned by a specific address.
     * @param owner The address of the owner.
     * @return An array of token IDs owned by the given address.
     */
    function getNFTsByOwner(
        address owner
    ) public view returns (uint256[] memory) {
        return nftsByOwner[owner];
    }

    /**
     * @dev Retrieves the NFTs structs owned by a specific address.
     * @param owner The address of the owner.
     * @return An array of NFT structs owned by the given address.
     */
    function getDetailedNFTsByOwner(
        address owner
    ) public view returns (NFT[] memory) {
        uint256[] memory tokenIds = nftsByOwner[owner];
        NFT[] memory nftsArray = new NFT[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            nftsArray[i] = getNFTbyId(tokenIds[i]);
        }

        return nftsArray;
    }

    /**
     * @dev Retrieves the NFT struct for a specific token ID.
     * @param tokenId The ID of the token.
     * @return The NFT struct for the given token ID.
     */
    function getNFTbyId(uint256 tokenId) public view returns (NFT memory) {
        return nfts[tokenId];
    }

    /**
     * @dev Sets the metadata URI for a given token ID.
     * @param tokenId The token ID to set the metadata URI for.
     * @param metadataURI The metadata URI to be set.
     */
    function _setTokenURI(
        uint256 tokenId,
        string memory metadataURI
    ) internal virtual {
        _tokenURIs[tokenId] = metadataURI;
    }

    /**
     * @dev Retrieves the metadata URI for a given token ID.
     * @param tokenId The token ID to retrieve the metadata URI for.
     * @return The metadata URI for the given token ID.
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            _tokenExists[tokenId],
            "ERC721Metadata: URI query for nonexistent token"
        );

        return _tokenURIs[tokenId];
    }

    /**
     * @dev Retrieves the metadata URI for a given token ID in a base64-encoded format (IPFS integration).
     * @param tokenId The token ID to retrieve the metadata URI for.
     * @return The base64-encoded metadata URI for the given token ID.
     */
    function tokenURIBase64(
        uint256 tokenId
    ) public view returns (string memory) {
        require(
            _tokenExists[tokenId],
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
     * @param keywords A two-dimensional array of keywords for the NFTs.
     * @param royaltyPercentages An array of royalty percentages for the NFTs.
     * @param royaltyRecipients An array of royalty recipient addresses for the NFTs.
     * @param metadataURIs An array of metadata URIs for the NFTs.
     */
    function bulkListNFTs(
        string[] memory names,
        string[] memory descriptions,
        uint256[] memory prices,
        string[][] memory keywords, // Change this to a two-dimensional array
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
                keywords[i], // Pass the array of keywords for this NFT
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
    function bulkBuyNFTs(
        uint256[] memory tokenIds
    ) public payable nonReentrant {
        uint256 totalPrice = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            NFT storage nft = nfts[tokenId];

            // Ensure the NFT is not already sold
            require(!nft.isSold, "NFT is already sold.");

            // Calculate the total price
            totalPrice += nft.price_in_wei;
        }

        // Ensure the provided Ether is sufficient
        require(msg.value >= totalPrice, "Not enough Ether provided.");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            NFT storage nft = nfts[tokenId];

            // Calculate the royalty amount
            uint256 royaltyAmount = (nft.price_in_wei * nft.royaltyPercentage) /
                100;

            // Transfer the NFT ownership
            address payable oldOwner = nft.owner;
            nft.owner = payable(msg.sender);
            nft.isSold = true;
            _transfer(oldOwner, msg.sender, tokenId);

            // Transfer funds to the seller and royalty recipient
            oldOwner.transfer(nft.price_in_wei - royaltyAmount);
            if (royaltyAmount > 0) {
                nft.royaltyRecipient.transfer(royaltyAmount);
                emit RoyaltyPaid(tokenId, nft.royaltyRecipient, royaltyAmount);
            }

            // Emit the NFTBought and NFTTransferred events
            emit NFTBought(tokenId, msg.sender, oldOwner, nft.price_in_wei);
            emit NFTTransferred(tokenId, oldOwner, msg.sender);
        }
    }
}
