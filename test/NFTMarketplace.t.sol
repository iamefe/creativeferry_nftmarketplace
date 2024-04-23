// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NFTMarketplace.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace public marketplace;
    address payable public owner;
    address payable public buyer;
    address payable public royaltyRecipient;

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

    function setUp() public {
        marketplace = new NFTMarketplace();
        owner = payable(makeAddr("owner"));
        buyer = payable(makeAddr("buyer"));
        royaltyRecipient = payable(makeAddr("royaltyRecipient"));
        marketplace.initialize();
        vm.deal(owner, 100 ether);
        vm.deal(buyer, 100 ether);
    }

    function testListNFT() public {
        vm.startPrank(owner);
        string memory name = "Test NFT";
        string memory description = "This is a test NFT";
        uint256 price = 1 ether;
        string[] memory keywords = new string[](1);
        keywords[0] = "test";
        uint8 royaltyPercentage = 10;
        string memory metadataURI = "ipfs://test-metadata-uri";

        vm.expectEmit(true, true, true, true);
        emit NFTListed(0, owner, name, description, price, metadataURI);

        marketplace.listNFT(
            name,
            description,
            price,
            keywords,
            royaltyPercentage,
            royaltyRecipient,
            metadataURI
        );
        vm.stopPrank();

        assertEq(marketplace.tokenExists(0), true);
        NFTMarketplace.NFT memory nft = marketplace.getNFTbyId(0);
        assertEq(nft.name, name);
        assertEq(nft.description, description);
        assertEq(nft.price_in_wei, price * 1 ether);
        assertEq(nft.royaltyPercentage, royaltyPercentage);
        assertEq(nft.royaltyRecipient, royaltyRecipient);
        assertEq(nft.metadataURI, metadataURI);
        assertEq(marketplace.nftsByKeyword("test", 0), 0);
        assertEq(marketplace.nftsByOwner(owner, 0), 0);
        assertEq(marketplace.ownerOf(0), owner);
    }

    function testBuyNFT() public {
        testListNFT();

        vm.startPrank(buyer, buyer);
        vm.expectEmit(true, true, true, true);
        emit NFTBought(0, buyer, owner, marketplace.getNFTbyId(0).price_in_wei);
        vm.expectEmit(true, true, true, true);
        emit NFTTransferred(0, owner, buyer);
        vm.expectEmit(true, true, true, true);
        emit RoyaltyPaid(
            0,
            royaltyRecipient,
            (marketplace.getNFTbyId(0).price_in_wei * 10) / 100
        );

        marketplace.buyNFT{value: marketplace.getNFTbyId(0).price_in_wei}(0);
        vm.stopPrank();

        NFTMarketplace.NFT memory nft = marketplace.getNFTbyId(0);
        assertEq(nft.owner, buyer);
        assertEq(nft.isSold, true);
        assertEq(marketplace.ownerOf(0), buyer);
        assertEq(buyer.balance, 100 ether - nft.price_in_wei);
        assertEq(owner.balance, 100 ether - (nft.price_in_wei * 90) / 100);
        assertEq(royaltyRecipient.balance, (nft.price_in_wei * 10) / 100);
    }

    function testReListNFTForSale() public {
        testBuyNFT();

        vm.startPrank(buyer);
        uint256 newPrice = 2 ether;
        marketplace.reListNFTForSale(0, newPrice);
        vm.stopPrank();

        NFTMarketplace.NFT memory nft = marketplace.getNFTbyId(0);
        assertEq(nft.price_in_wei, newPrice * 1 ether);
        assertEq(nft.isSold, false);
    }

    function testBulkListNFTs() public {
        string[] memory names = new string[](2);
        names[0] = "Test NFT 1";
        names[1] = "Test NFT 2";

        string[] memory descriptions = new string[](2);
        descriptions[0] = "This is a test NFT 1";
        descriptions[1] = "This is a test NFT 2";

        uint256[] memory prices = new uint256[](2);
        prices[0] = 1 ether;
        prices[1] = 2 ether;

        string[][] memory keywords = new string[][](2);
        keywords[0] = new string[](1);
        keywords[0][0] = "test1";
        keywords[1] = new string[](1);
        keywords[1][0] = "test2";

        uint8[] memory royaltyPercentages = new uint8[](2);
        royaltyPercentages[0] = 10;
        royaltyPercentages[1] = 20;

        address payable[] memory royaltyRecipients = new address payable[](2);
        royaltyRecipients[0] = royaltyRecipient;
        royaltyRecipients[1] = royaltyRecipient;

        string[] memory metadataURIs = new string[](2);
        metadataURIs[0] = "ipfs://test-metadata-uri-1";
        metadataURIs[1] = "ipfs://test-metadata-uri-2";

        vm.startPrank(owner);
        marketplace.bulkListNFTs(
            names,
            descriptions,
            prices,
            keywords,
            royaltyPercentages,
            royaltyRecipients,
            metadataURIs
        );
        vm.stopPrank();

        assertEq(marketplace.tokenExists(0), true);
        assertEq(marketplace.tokenExists(1), true);
        NFTMarketplace.NFT memory nft1 = marketplace.getNFTbyId(0);
        NFTMarketplace.NFT memory nft2 = marketplace.getNFTbyId(1);
        assertEq(nft1.name, names[0]);
        assertEq(nft2.name, names[1]);
        assertEq(nft1.description, descriptions[0]);
        assertEq(nft2.description, descriptions[1]);
        assertEq(nft1.price_in_wei, prices[0] * 1 ether);
        assertEq(nft2.price_in_wei, prices[1] * 1 ether);
        assertEq(nft1.royaltyPercentage, royaltyPercentages[0]);
        assertEq(nft2.royaltyPercentage, royaltyPercentages[1]);
        assertEq(nft1.royaltyRecipient, royaltyRecipients[0]);
        assertEq(nft2.royaltyRecipient, royaltyRecipients[1]);
        assertEq(nft1.metadataURI, metadataURIs[0]);
        assertEq(nft2.metadataURI, metadataURIs[1]);
        assertEq(marketplace.nftsByKeyword("test1", 0), 0);
        assertEq(marketplace.nftsByKeyword("test2", 0), 1);
        assertEq(marketplace.nftsByOwner(owner, 0), 0);
        assertEq(marketplace.nftsByOwner(owner, 1), 1);
        assertEq(marketplace.ownerOf(0), owner);
        assertEq(marketplace.ownerOf(1), owner);
    }

    function testBulkBuyNFTs() public {
        testBulkListNFTs();

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint256 totalPrice = marketplace.getNFTbyId(0).price_in_wei +
            marketplace.getNFTbyId(1).price_in_wei;
        uint256 royaltyAmount1 = (marketplace.getNFTbyId(0).price_in_wei *
            marketplace.getNFTbyId(0).royaltyPercentage) / 100;
        uint256 royaltyAmount2 = (marketplace.getNFTbyId(1).price_in_wei *
            marketplace.getNFTbyId(1).royaltyPercentage) / 100;

        vm.startPrank(buyer, buyer);
        vm.expectEmit(true, true, true, true);
        emit NFTBought(0, buyer, owner, marketplace.getNFTbyId(0).price_in_wei);
        vm.expectEmit(true, true, true, true);
        emit NFTTransferred(0, owner, buyer);
        vm.expectEmit(true, true, true, true);
        emit RoyaltyPaid(0, royaltyRecipient, royaltyAmount1);
        vm.expectEmit(true, true, true, true);
        emit NFTBought(1, buyer, owner, marketplace.getNFTbyId(1).price_in_wei);
        vm.expectEmit(true, true, true, true);
        emit NFTTransferred(1, owner, buyer);
        vm.expectEmit(true, true, true, true);
        emit RoyaltyPaid(1, royaltyRecipient, royaltyAmount2);

        marketplace.bulkBuyNFTs{value: totalPrice}(tokenIds);
        vm.stopPrank();

        NFTMarketplace.NFT memory nft1 = marketplace.getNFTbyId(0);
        NFTMarketplace.NFT memory nft2 = marketplace.getNFTbyId(1);
        assertEq(nft1.owner, buyer);
        assertEq(nft1.isSold, true);
        assertEq(nft2.owner, buyer);
        assertEq(nft2.isSold, true);
        assertEq(marketplace.ownerOf(0), buyer);
        assertEq(marketplace.ownerOf(1), buyer);
        assertEq(buyer.balance, 100 ether - totalPrice);
        assertEq(
            owner.balance,
            100 ether - (totalPrice - royaltyAmount1 - royaltyAmount2)
        );
        assertEq(royaltyRecipient.balance, royaltyAmount1 + royaltyAmount2);
    }

    function testTokenURI() public {
        testListNFT();
        assertEq(
            marketplace.tokenURI(0),
            marketplace.getNFTbyId(0).metadataURI
        );
    }

    function testTokenURIBase64() public {
        testListNFT();
        NFTMarketplace.NFT memory nft = marketplace.getNFTbyId(0);
        string memory expectedBase64URI = string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
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
                )
            )
        );
        assertEq(marketplace.tokenURIBase64(0), expectedBase64URI);
    }

    function testFailListNFTNonOwner() public {
        vm.prank(buyer);
        marketplace.listNFT(
            "Test NFT",
            "This is a test NFT",
            1 ether,
            new string[](1),
            10,
            royaltyRecipient,
            "ipfs://test-metadata-uri"
        );
    }

    function testFailBuyOwnNFT() public {
        testListNFT();
        vm.prank(owner);
        marketplace.buyNFT{value: marketplace.getNFTbyId(0).price_in_wei}(0);
    }

    function testFailBuyInsufficientEther() public {
        testListNFT();
        vm.prank(buyer);
        marketplace.buyNFT{value: marketplace.getNFTbyId(0).price_in_wei - 1}(
            0
        );
    }

    function testFailBuyNonExistentNFT() public {
        vm.prank(buyer);
        marketplace.buyNFT{value: 1 ether}(0);
    }

    function testFailBuyAlreadySoldNFT() public {
        testBuyNFT();
        vm.prank(buyer);
        marketplace.buyNFT{value: marketplace.getNFTbyId(0).price_in_wei}(0);
    }

    function testFailBulkBuyInsufficientEther() public {
        testBulkListNFTs();
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        uint256 totalPrice = marketplace.getNFTbyId(0).price_in_wei +
            marketplace.getNFTbyId(1).price_in_wei;
        vm.prank(buyer);
        marketplace.bulkBuyNFTs{value: totalPrice - 1}(tokenIds);
    }

    function testGetAllListedNFTs() public {
        testBulkListNFTs();

        NFTMarketplace.NFT[] memory listedNFTs = marketplace.getAllListedNFTs();
        assertEq(listedNFTs.length, 2);
        assertEq(listedNFTs[0].owner, owner); // Corrected line
        assertEq(listedNFTs[1].owner, owner); // Corrected line
    }

    function testSetNewNFTPrice() public {
        testListNFT();

        vm.startPrank(owner);
        uint256 newPrice = 2 ether;
        marketplace.setNewNFTPrice(0, newPrice);
        vm.stopPrank();

        assertEq(marketplace.getNFTbyId(0).price_in_wei, newPrice * 1 ether);
    }

    function testGetNFTsByOwner() public {
        testBulkListNFTs();

        uint256[] memory ownerNFTs = marketplace.getNFTsByOwner(owner);
        assertEq(ownerNFTs.length, 2);
        assertEq(ownerNFTs[0], 0);
        assertEq(ownerNFTs[1], 1);
    }

    function testGetDetailedNFTsByOwner() public {
        testBulkListNFTs();

        NFTMarketplace.NFT[] memory ownerNFTs = marketplace
            .getDetailedNFTsByOwner(owner);
        assertEq(ownerNFTs.length, 2);
        assertEq(ownerNFTs[0].tokenId, 0);
        assertEq(ownerNFTs[1].tokenId, 1);
    }
}
