/**
 * @dev Initializes the contract by setting the token name, symbol, and owner.
 */
function initialize() public initializer

/**
 * @dev Lists a new NFT on the marketplace.
 * @param name The name of the NFT.
 * @param description The description of the NFT.
 * @param price The sale price of the NFT in Wei.
 * @param keyword An array of keywords associated with the NFT.
 * @param royaltyPercentage The percentage of the sale price to be paid as royalty.
 * @param royaltyRecipient The address to receive the royalty payment.
 * @param metadataURI The URI pointing to the metadata of the NFT on IPFS.
 */
function listNFT(string memory name, string memory description, uint256 price, string memory keyword, uint8 royaltyPercentage, address payable royaltyRecipient, string memory metadataURI) public onlyOwner

/**
 * @dev Allows a buyer to purchase a listed NFT.
 * @param tokenId The unique identifier of the NFT to be purchased.
 */
function buyNFT(uint256 tokenId) public payable nonReentrant

/**
    * @dev Function to retrieve all listed NFTs on the marketplace.
    * @return An array of NFT structs representing the listed NFTs.
    */
function getAllListedNFTs() public view returns (NFT[] memory)

/**
 * @dev Retrieves the NFTs associated with a specific keyword.
 * @param keyword The keyword to search for.
 * @return An array of token IDs associated with the given keyword.
 */
function getNFTsByKeyword(string memory keyword) public view returns (uint256[] memory)

/**
 * @dev Retrieves the NFTs owned by a specific address.
 * @param owner The address of the owner.
 * @return An array of token IDs owned by the given address.
 */
function getNFTsByOwner(address owner) public view returns (uint256[] memory)

/**
 * @dev Retrieves the metadata URI for a given token ID.
 * @param tokenId The token ID to retrieve the metadata URI for.
 * @return The metadata URI for the given token ID.
 */
function tokenURI(uint256 tokenId) public view virtual override returns (string memory)

/**
 * @dev Retrieves the metadata URI for a given token ID in a base64-encoded format (IPFS integration).
 * @param tokenId The token ID to retrieve the metadata URI for.
 * @return The base64-encoded metadata URI for the given token ID.
 */
function tokenURIBase64(uint256 tokenId) public view returns (string memory)

/**
 * @dev Implements the bulk listing of NFTs (gas optimized).
 * @param names An array of names for the NFTs.
 * @param descriptions An array of descriptions for the NFTs.
 * @param prices An array of prices for the NFTs.
 * @param keywords A 2-dimensional array of keywords for the NFTs.
 * @param royaltyPercentages An array of royalty percentages for the NFTs.
 * @param royaltyRecipients An array of royalty recipient addresses for the NFTs.
 * @param metadataURIs An array of metadata URIs for the NFTs.
 */
function bulkListNFTs(string[] memory names, string[] memory descriptions, uint256[] memory prices, string[] memory keywords, uint8[] memory royaltyPercentages, address payable[] memory royaltyRecipients, string[] memory metadataURIs) public onlyOwner

/**
 * @dev Implements the bulk buying of NFTs (gas optimized).
 * @param tokenIds An array of token IDs to be purchased.
 */
function bulkBuyNFTs(uint256[] memory tokenIds) public payable nonReentrant