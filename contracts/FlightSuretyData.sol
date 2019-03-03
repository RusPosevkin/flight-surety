pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    address private contractOwner;
    bool private operational = true;
    mapping(address => uint256) private walletBalance;
    address[] private airlines;
    address[] private activeAirlines;
    mapping(address => bool) private activatedAirlines;
    mapping(address => address[]) private airlineVotes;
    mapping(bytes32 => Insurance) private flightInsuranceDetails;
    mapping(bytes32 => address[]) private flightInsurances;

    struct Insurance {
        bytes32 id;
        address owner;
        uint256 amount;
        bool isRefunded;
    }

    event airlineRegistered(address airlineAddress);
    event airlineFunded(address airlineAddress);
    event insurancePurchased(address airline, string flight, uint256 timestamp, address senderAddress, uint256 insuranceAmount);
    event insuranceClaimed(address airline, string flight, uint256 timestamp, address passenger, uint256 amountCreditedToPassenger);
    event amountWithdrawn(address senderAddress, uint amount);

    constructor() public {
        contractOwner = msg.sender;
        airlines.push(msg.sender);
        activatedAirlines[msg.sender] = false;
        activeAirlines.push(msg.sender);
    }

    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller isn't owner of contract");
        _;
    }

    modifier requireIsOperational() {
        require(operational, "Contract isn't operational");
        _;
    }


    function isOperational() external view returns (bool) {
        return operational;
    }

    function setOperatingStatus(bool mode) external requireContractOwner {
        require(mode != operational, "New mode should be different");
        operational = mode;
    }

    function getAirlineVotes(address newAirline) external view requireIsOperational returns(address[]) {
        return airlineVotes[newAirline];
    }

    function addAirlineVotes(address newAirline, address senderAddress) external requireIsOperational returns(address[]) {
        airlineVotes[newAirline].push(senderAddress);
    }

    function isAirlineVoted(address newAirline, address senderAddress) external view requireIsOperational returns (bool) {
        bool isAlreadyVoted = false;
        for(uint i = 0; i < airlineVotes[newAirline].length; i++) {
            if(airlineVotes[newAirline][i] == senderAddress) {
                isAlreadyVoted = true;
            }
        }
        return isAlreadyVoted;
    }

    function registerAirline(address newAirline) external requireIsOperational {
        airlines.push(newAirline);
        activatedAirlines[newAirline] = false;
        emit airlineRegistered(newAirline);
    }

    function isAirlineRegistered(address newAirline) external view requireIsOperational returns(bool) {
        bool isRegistered = false;
        for(uint i = 0; i < airlines.length; i++) {
            if(airlines[i] == newAirline) {
                isRegistered = true;
            }
        }
        return isRegistered;
    }

    function activateAirline(address airlineAddress) external payable requireIsOperational {
        activatedAirlines[airlineAddress] = true;
        activeAirlines.push(airlineAddress);
        fund(airlineAddress);
        emit airlineFunded(airlineAddress);
    }

    function getRegisteredAirlines() external view requireIsOperational returns(address[]) {
        return airlines;
    }

    function getActiveAirlines() external view requireIsOperational returns(address[]) {
        return activeAirlines;
    }

    function isAirlineActivated(address airlineAddress) external view requireIsOperational returns(bool) {
        return activatedAirlines[airlineAddress];
    }

    function buyInsurance(address airline, string flight, uint256 timestamp, address passenger, uint256 insuranceAmount) external payable requireIsOperational {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        bytes32 insuranceKey = keccak256(abi.encodePacked(flightKey, passenger));
        flightInsuranceDetails[insuranceKey] = Insurance({
            id: insuranceKey,
            owner: passenger,
            amount: insuranceAmount,
            isRefunded: false
        });
        flightInsurances[flightKey].push(passenger);
        fund(airline);
        emit insurancePurchased(airline, flight, timestamp, passenger, insuranceAmount);
    }

    function claimInsuranceAmount(address airline, string flight, uint256 timestamp, address airlineAddress, address passenger) external requireIsOperational {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        bytes32 insuranceKey = keccak256(abi.encodePacked(flightKey, passenger));
        require(flightInsuranceDetails[insuranceKey].id == insuranceKey, "You haven't purchased insurance for this flight.");
        require(!flightInsuranceDetails[insuranceKey].isRefunded, "You have already claimed the insurance.");
        uint256 currentAirlineBalance = walletBalance[airlineAddress];
        uint256 amountCreditedToPassenger = flightInsuranceDetails[insuranceKey].amount.mul(15).div(10);
        require(currentAirlineBalance >= amountCreditedToPassenger, "Airline doesn't have enough funds.");
        flightInsuranceDetails[insuranceKey].isRefunded = true;
        walletBalance[airlineAddress] = currentAirlineBalance.sub(amountCreditedToPassenger);
        walletBalance[passenger] = walletBalance[passenger].add(amountCreditedToPassenger);
        emit insuranceClaimed(airline, flight, timestamp, passenger, amountCreditedToPassenger);
    }

    function withdrawAmount(address senderAddress) external payable {
        require(walletBalance[senderAddress] > 0, "There are no enought cash in the wallet");
        uint256 withdrawAmount = walletBalance[senderAddress];
        walletBalance[senderAddress] = 0;
        senderAddress.transfer(withdrawAmount);
        emit amountWithdrawn(senderAddress, withdrawAmount);
    }

    function fund(address senderAddress) public payable {
        walletBalance[senderAddress] = walletBalance[senderAddress].add(msg.value);
    }

    function getFlightKey(address airline, string memory flight, uint256 timestamp) pure internal returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function() external payable {
        fund(msg.sender);
    }
}