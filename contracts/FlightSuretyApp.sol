pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";
contract FlightSuretyApp {
    using SafeMath for uint256; 

    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address public contractOwner;          
    FlightSuretyData flightSuretyData;

    uint constant airlineRegistrationConstant = 5;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    constructor(address dataContract) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }
    
    modifier requireIsOperational() 
    {
        require(true, "Contract isn't operational");  
        _;
    }

    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    function isOperational() public view returns(bool) {
        return flightSuretyData.isOperational();  
    }

    function registerAirline(address newAirline) external returns(bool success, uint256 votes) {
        // requirements
        require(isOperational(), "Service is not available");
        require(flightSuretyData.isAirlineActivated(msg.sender), "Your airline is not activated");
        require(!flightSuretyData.isAirlineRegistered(newAirline), "This airline is already registered");
        require(!flightSuretyData.isAirlineVoted(newAirline, msg.sender), "You have already voted for this airline");

        flightSuretyData.addAirlineVotes(newAirline, msg.sender);
        address[] memory registeredAirlines = flightSuretyData.getRegisteredAirlines();
        address[] memory airlineVotes = flightSuretyData.getAirlineVotes(newAirline);

        if(registeredAirlines.length >= airlineRegistrationConstant) {
            if(airlineVotes.length >= registeredAirlines.length / 2) {
                flightSuretyData.registerAirline(newAirline);
                success = true;
            } else {
                success = false;
            }
        } else {
            flightSuretyData.registerAirline(newAirline);
            success = true;
        }

        return (success, airlineVotes.length);
    }

    function isAirlineRegistered(address newAirline) external view returns(bool) {
        require(isOperational(), "Service is not available");
        return flightSuretyData.isAirlineRegistered(newAirline);
    }

    function activateAirline(address airlineAddress) external payable {
        require(isOperational(), "Service is not available");
        require(flightSuretyData.isAirlineRegistered(airlineAddress), "This airline is not registered");
        require(!flightSuretyData.isAirlineActivated(airlineAddress), "This airline is already activated");
        require(msg.value == 10 ether, "Please submit 10 ether to activate your airline");
        flightSuretyData.activateAirline.value(msg.value)(airlineAddress);
    }

    function isAirlineActivated(address airlineAddress) external view returns(bool) {
        require(isOperational(), "Service is not available");
        return flightSuretyData.isAirlineActivated(airlineAddress);
    }

    function getActiveAirlines() external view returns(address[]) {
        require(isOperational(), "Service is not available");
        return flightSuretyData.getActiveAirlines();
    }

    function buyInsurance(address airline, string flight, uint256 timestamp, address passenger) external payable {
        require(isOperational(), "Service is not available");
        require(msg.value <= 1 ether, "Amount should be less than or equal to 1 ether");
        flightSuretyData.buyInsurance.value(msg.value)(airline, flight, timestamp, passenger, msg.value);
    }

    function claimInsuranceAmount(address airline, string flight, uint256 timestamp, address passenger) external {
        require(isOperational(), "Service is not available");
        flightSuretyData.claimInsuranceAmount(airline, flight, timestamp, airline, passenger);
    }

    function withdrawAmount() external {
        require(isOperational(), "Service is not available");
        flightSuretyData.withdrawAmount(msg.sender);
    }
    
    function processFlightStatus(address airline, string memory flight, uint256 timestamp, uint8 statusCode) internal pure {}

    function fetchFlightStatus(address airline, string flight, uint256 timestamp) external {
        require(flightSuretyData.isAirlineRegistered(airline), "This airline is not registered");
        require(flightSuretyData.isAirlineActivated(airline), "This airline is not activated");
        uint8 index = getRandomIndex(msg.sender);

        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    } 

    uint8 private nonce = 0;    
    uint256 public constant REGISTRATION_FEE = 1 ether;
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    mapping(address => Oracle) private oracles;
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    struct ResponseInfo {
        address requester;                              
        bool isOpen;                                   
        mapping(uint8 => address[]) responses;          
    }


    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);
    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);

    function registerOracle() external payable {
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
            isRegistered: true,
            indexes: indexes
        });
    }
    

    function submitOracleResponse(uint8 index, address airline, string flight, uint256 timestamp, uint8 statusCode) external {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");

        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getMyIndexes() view external returns(uint8[3]) {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }

    function getFlightKey(address airline, string flight, uint256 timestamp) pure internal returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function generateIndexes(address account) internal returns(uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        indexes[1] = indexes[0];

        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  
        }

        return random;
    }
}
