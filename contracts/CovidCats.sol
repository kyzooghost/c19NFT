/** TO-DO
 * 
 * Determine how to store metadata in a format that OpenSea will accept
 */


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CovidCats is ERC721, VRFConsumerBase, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // DECLARING NFT VARIABLES
    struct NFT {
        string variant;
        string background;
        string mask;
        string glasses;
        string hat;
        string vaccine;
    }

    NFT[] public covidNFT;

    event Mint(address indexed _minter, uint256 indexed _tokenID, string[6] traits);

    // DECLARING CHAINLINK VRF FUNCTION CONSTANTS
    bytes32 internal keyHash; //Public key against which randomness is generated
    uint256 internal fee; //Fee required to fulfil a VRF request
    mapping(bytes32 => address) requestToSender;
    mapping(address => bool) isClaiming;
    IERC20 public LINK_token;
    
    // TRAITS
    string[] private variant = [
        "Regular",
        "Delta",
        "Dead"
    ];

    uint256[] private variant_weights = [
        81,
        19,
        1
    ];

    string[] private background = [
        "White",
        "Black",
        "Red",
        "Blue"
    ];

    uint256[] private background_weights = [
        25,
        25,
        25,
        25
    ];

    string[] private mask = [
        "No Mask",
        "Basic Surgical Mask",
        "N95 Mask",
        "Floral Print Surgical Mask",
        "Floral N95 Mask"
    ];

    uint256[] private mask_weights = [
        20,
        20,
        20,
        20,
        20
    ];

    string[] private glasses = [
        "No Glasses",
        "Basic Sunglasses",
        "Basic Glasses"
    ];

    uint256[] private glasses_weights = [
        33,
        33,
        34
    ];

    string[] private hat = [
        "No Hat",
        "Cap"
    ];

    uint256[] private hat_weights = [
        50,
        50
    ];

    string[] private vaccine = [
        "Modern",
        "Astro"
    ];

    uint256[] private vaccine_weights = [
        50,
        50
    ];

    constructor( address _VRFCoordinator, address _linkToken, bytes32 _keyHash)
        VRFConsumerBase(_VRFCoordinator, _linkToken)
        ERC721("CovidCats", "CovidCat")
        Ownable() {
            LINK_token = IERC20(_linkToken);
            keyHash = _keyHash;
            fee = 0.1 * 10 ** 18;
    }

    /** 
     * Requests random number from Chainlink VRF function
     */
    function claim() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        require(isClaiming[msg.sender] == false, "YOU CANNOT CLAIM ANOTHER NFT YET");
        requestId = requestRandomness(keyHash, fee);
        requestToSender[requestId] = msg.sender;
        isClaiming[msg.sender] = true;
    }

    /**
     * Callback function used by VRF Coordinator
     * Using "Having multiple VRF requests in flight" pattern as per https://docs.chain.link/docs/chainlink-vrf-best-practices/
     * Also using "Getting multiple random numbers" pattern
     * Also using "Getting a random number within a range" pattern
     * NOTE that this function has a gas limit of 200,000 or it will as per Chainlink docs
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        address initiator = requestToSender[requestId];
        
        // Get tokenId for this NFT mint
        uint256 id = covidNFT.length;

        // Get 6 random numbers in the range from 1 to 100
        uint256[6] memory randomValues;
        
        for (uint256 i = 0; i < 6; i++) {
            randomValues[i] = uint256(keccak256(abi.encode(randomness, i)));
            randomValues[i] = (randomValues[i] % 100) + 1;
        }

        // Use above 6 random numbers and trait weights to randomly generate traits
        uint256 sum;
        
        string memory _variant;
        string memory _background;
        string memory _mask;
        string memory _glasses;
        string memory _hat;
        string memory _vaccine;

        for (uint i = 0; i < variant_weights.length; i++) {
            sum += variant_weights[i];
            if (sum >= randomValues[0]) {
                _variant = variant[i];
                sum = 0;
                break;
            }
        }

        for (uint i = 0; i < background_weights.length; i++) {
            sum += background_weights[i];
            if (sum >= randomValues[1]) {
                _background = background[i];
                sum = 0;
                break;
            }
        }

        for (uint i = 0; i < mask_weights.length; i++) {
            sum += mask_weights[i];
            if (sum >= randomValues[2]) {
                _mask = mask[i];
                sum = 0;
                break;
            }
        }

        for (uint i = 0; i < glasses_weights.length; i++) {
            sum += glasses_weights[i];
            if (sum >= randomValues[3]) {
                _glasses = glasses[i];
                sum = 0;
                break;
            }
        }

        for (uint i = 0; i < hat_weights.length; i++) {
            sum += hat_weights[i];
            if (sum >= randomValues[4]) {
                _hat = hat[i];
                sum = 0;
                break;
            }
        }

        for (uint i = 0; i < vaccine_weights.length; i++) {
            sum += vaccine_weights[i];
            if (sum >= randomValues[5]) {
                _vaccine = vaccine[i];
                sum = 0;
                break;
            }
        }
        
        // Push traits to NFT struct
        covidNFT.push(NFT(
            _variant,
            _background,
            _mask,
            _glasses,
            _hat,
            _vaccine
            )
        );

        // Mint NFT
        _safeMint(initiator, id);
        
        emit Mint(initiator, id, 
            [_variant,
            _background,
            _mask,
            _glasses,
            _hat,
            _vaccine]
            );

        isClaiming[initiator] = false;
    }

    // Withdraw function to avoid locking your LINK in the contract
    function withdrawLink() onlyOwner external {
        uint256 LINK_balance = LINK_token.balanceOf(address(this));
        LINK_token.safeTransfer(msg.sender, LINK_balance);
    }
}
