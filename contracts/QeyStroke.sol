//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract QeyStroke is ERC1155Burnable, Ownable, ReentrancyGuard, Pausable, PaymentSplitter {
    using Strings for uint256;
    string public tokenURI;
    bytes32 public root;
    uint256 public supply;
    uint256 public tokenId = 0;
    uint256 public cost = 0.1 ether;
    bool public whitelistActive = false;
    bool public burnActive = false;
    string public extension = ".json";
    mapping(uint8 => uint256) parcelCount;
    mapping(uint256 => uint8) tokenToParcel;    
    mapping(address => uint256) holdings;
    address[] _addresses = [
        // dev wallet
        0x99151DEd55907fd2A256C882EA5c16D3f84340C9,
        // owner wallet
        0xd80AEC40A695f4262586af3ec2c493D45F29FA1d
    ];
    uint256[] _shares = [175,825];
    event ParcelMinted(uint256 tokenId, uint8 parcelID, address owner);
    event GenesisMinted(uint256 tokenId, uint256[] tokenIds, uint8[] parcelIDs, address owner);
    
    constructor(uint256 parcel1, uint256 parcel2, uint256 parcel3, uint256 parcel4) ERC1155(tokenURI) PaymentSplitter(_addresses, _shares) {
        parcelCount[1] = parcel1;
        parcelCount[2] = parcel2;
        parcelCount[3] = parcel3;
        parcelCount[4] = parcel4;
        setSupply(parcel1 + parcel2 + parcel3 + parcel4);
    }

    function whitelistMint(uint256 _amount, uint256 _tokenId, bytes32[] calldata proof) external payable nonReentrant {
        require(whitelistActive, "Whitelist is not active");
        require(_verify(_leaf(_msgSender(), _tokenId), proof), "Invalid");
        require(holdings[_msgSender()] + _amount <= _tokenId, "Cannot exceed allocated");
        require(_amount * cost == msg.value, "Incorrect ETH");
        callMint(_amount);
        holdings[_msgSender()] += _amount;
    }

    function mint(uint256 _amount) external payable nonReentrant whenNotPaused {
        require(_amount * cost == msg.value, "Incorrect ETH");
        callMint(_amount);
    }

    /**
        @dev filter out all parcels with supply > 0
        randomly choose one from the filtered list
     */
    function getParcelID(uint256 _tokenId) internal view returns (uint8) {
        uint8 resultCount;

        for(uint8 i = 1; i <= 4; i++) {
            if (parcelCount[i] > 0) { 
                resultCount++;
            }
        }

        require(resultCount > 0);

        uint8[] memory result = new uint8[](resultCount);
        uint256 j;

        for (uint8 i = 1; i <= 4; i++) {
            if (parcelCount[i] > 0) {
                result[j] = i;
                j++;
            }
        }
        uint256 _index = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, _tokenId))) % result.length;
        return result[_index];
    }

    /**
        @dev utility function for public mint and whitelist mint
        get parcel ID, decrement supply of parcel id and update
        mapping of token and parcelID for burn reference
     */
    function callMint(uint256 amount) internal {
        require(tokenId + amount <= supply, "Cannot exceed");
        for(uint256 i; i < amount; i++) {
            uint nextToken = tokenId + i;
            uint8 _parcelID = getParcelID(nextToken);
            parcelCount[_parcelID] -= 1;
            _mint(_msgSender(), nextToken, 1, "");
            tokenToParcel[nextToken] = _parcelID;            
            emit ParcelMinted(nextToken, _parcelID, _msgSender());
        }        
        tokenId += amount;
    }

    /** ================== ADMIN ONLY FUNCTIONS ================== */

    function toggleWhitelist() external onlyOwner {
        whitelistActive = !whitelistActive;
    }

    function toggleBurnActive() external onlyOwner {
        burnActive = !burnActive;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setSupply(uint256 _supply) public onlyOwner {
        supply = _supply;
    }

    function setExtension(string memory _extension) external onlyOwner {
        extension = _extension;
    }

    function setURI(string memory _tokenURI) external onlyOwner {
        tokenURI = _tokenURI;
    }

    function parcelID(uint256 id) public view returns (uint8) {
        return tokenToParcel[id];
    }

    function uri(uint256 id) public view override returns (string memory) {
	    return bytes(tokenURI).length > 0	? string(abi.encodePacked(tokenURI, id.toString(), extension)) : "";
    }

    /**
        @dev burning a single parcel 4 will mint a genesis that exceeds 3939
        emit event for subgraph to categorize correct genesis (should be category 6)
     */
    function burnOne(uint256 id) external {
        require(burnActive, "Burn not active");
        require(tokenToParcel[id] == 4, "First should be parcel 4");
        _burn(_msgSender(), id, 1);
        _mint(_msgSender(), tokenId, 1, "");        
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = id;
        uint8[] memory parcelIDs = new uint8[](1);
        parcelIDs[0] = tokenToParcel[id];
        emit GenesisMinted(tokenId, tokenIds, parcelIDs, _msgSender());
        tokenId++;
    }

    /**
        @dev burn 3 parcels of type 1,2 and 3 to mint a genesis that exceeds 3939
        emit event for subgraph to categorize correct genesis (categories 1 - 6)
     */
    function burnThree(uint256[] memory ids) external {
        require(burnActive, "Burn not active");
        uint256 first = ids[0];
        uint256 second = ids[1];
        uint256 third = ids[2];
        require(tokenToParcel[first] == 1, "First should be parcel 1");
        require(tokenToParcel[second] == 2, "Second should be parcel 2");
        require(tokenToParcel[third] == 3, "Third should be parcel 3");        
        uint256[] memory burnAmount = new uint256[](3);
        burnAmount[0] = 1;
        burnAmount[1] = 1;
        burnAmount[2] = 1;
        _burnBatch(_msgSender(), ids, burnAmount);
        _mint(_msgSender(), tokenId, 1, "");        
        uint8[] memory parcelIDs = new uint8[](3);
        parcelIDs[0] = tokenToParcel[first];
        parcelIDs[1] = tokenToParcel[second];
        parcelIDs[2] = tokenToParcel[third];
        emit GenesisMinted(tokenId, ids, parcelIDs, _msgSender());
        tokenId++;
    }

    function _leaf(address account, uint256 _tokenId)
    internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked(_tokenId, account));
    }

    function _verify(bytes32 leaf, bytes32[] memory proof)
    internal view returns (bool)
    {
        return MerkleProof.verify(proof, root, leaf);
    }
}
