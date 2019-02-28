pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Ownable.sol";

contract FlightSuretyData is Ownable {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract

    address[] multiCalls = new address[](0);
    uint8 AIRLINE_LENGTH_LIMIT = 5;
    bool isAirlineRegistrationOperational = true;

    address[] enabledAirlines = new address[](0);

    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    bool private has_initialized = false;
    bool private testingMode = false;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        string id;
        bool hasBeenInsured;
    }
    
    struct Airline {
        bool isRegistered;
        address account;
        uint256 ownership;
    }

    mapping(string => Flight) flights;
    mapping(address => Airline) airlines;
    mapping(string => address[]) flightInsurees;
    mapping(address => uint8) authorizedCaller;
    mapping(address => uint256) funds;
    mapping(bytes32 => uint256) flightSurety;
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
        (
        ) 
        public 
    {
        contractOwner = msg.sender;
        airlines[contractOwner] = Airline({
            isRegistered: true,
            account: contractOwner,
            ownership: 0
        });
        emit RegisterAirline(contractOwner);
    }

    event RegisterAirline
    (
        address indexed account
    );

    event RegisterFlight
    (
        string indexed account
    );

    event AuthorizedCaller(address caller);
    event DeAuthorizedCaller(address caller);
    event CreditInsured(address passenger, string flight, uint256 amount);


    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that checks that caller is contract owner
    */
    modifier requireIsCallerAuthorized()
    {
        require(authorizedCaller[msg.sender] == 1, "Caller is not authorized");
        _;
    }

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function authorizeCaller(address _caller) public onlyOwner returns(bool)
    {
        authorizedCaller[_caller] = 1;
        emit AuthorizedCaller(_caller);
        return true;
    }

    function deAuthorizeCaller(address _caller) public onlyOwner returns(bool)
    {
        authorizedCaller[_caller] = 0;
        emit DeAuthorizedCaller(_caller);
        return true;
    }

    function setOperatingStatus
        (
            bool mode,
            address sender
        )
        external
    {
        require(mode != operational, "mode should be different");
        require(airlines[sender].isRegistered, "Caller wasn't register");

        bool isDuplicate = false;
        for(uint c=0; c<multiCalls.length; c++) {
            if (multiCalls[c] == sender) {
                isDuplicate = true;
                break;
            }
        }

        require(!isDuplicate, "This function was already called");

        multiCalls.push(sender);
        if (multiCalls.length >= (enabledAirlines.length.div(2))) {
            operational = mode;
            multiCalls = new address[](0);
        }
    }

    function setTestingMode
        (
            bool mode
        )
        external
        requireContractOwner
        requireIsOperational
    {
        testingMode = mode;
    }

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
        public 
        view 
        returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
        (
            bool mode
        ) 
        external
        requireContractOwner 
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
        (   
            address airline,
            address owner
        )
        external
        requireIsCallerAuthorized
        requireIsOperational
    {
        require(!airlines[airline].isRegistered, "Airline was already registered");
        if (airline != contractOwner) {
            require(airlines[owner].isRegistered, "Non-existing airline");
            if (enabledAirlines.length < AIRLINE_LENGTH_LIMIT) {
                require(airline != owner, "Under five airlines, an airline cannot register itself");
                require(airlines[owner].ownership > 0, "Under five airlines, an airline without ownership cannot register other");

                airlines[airline] = Airline({
                    isRegistered: true,
                    account: airline,
                    ownership: 0
                    });

                emit RegisterAirline(airline); 
            } else {
                bool isDuplicate = false;
                for(uint c=0; c<multiCalls.length; c++) {
                    if (multiCalls[c] == msg.sender) {
                        isDuplicate = true;
                        break;
                    }
                }

                require(!isDuplicate, "This function was already called");

                multiCalls.push(msg.sender);
                if (multiCalls.length >= (enabledAirlines.length.div(2))) {
                    airlines[airline] = Airline({
                        isRegistered: true,
                        account: airline,
                        ownership: 0
                    });

                    multiCalls = new address[](0);
                    emit RegisterAirline(airline);
                }
            }
        }
    }

    function registerFlight
        (
            address airline,
            string flightId,
            uint256 timestamp
        )
        external
        requireIsCallerAuthorized
        requireIsOperational
    {

        require(airlines[airline].isRegistered, "Non-registered airline");
        flights[flightId] = Flight({
            isRegistered: true,
            statusCode: 0,
            updatedTimestamp: timestamp,
            airline: airline,
            id: flightId,
            hasBeenInsured: false
        });

        emit RegisterFlight(flightId);
    }

    function isAirline
        (
            address airline
        )
        external
        view
        requireIsCallerAuthorized
        requireIsOperational
        returns(bool)
    {
        return airlines[airline].isRegistered;
    }

    function getAirlineOwnership
        (
            address airline
        )
        external
        view
        requireIsCallerAuthorized
        requireIsOperational
        returns(uint256)
    {
        return airlines[airline].ownership;
    }

    function getActiveAirlines
        (
        )
        external
        view
        requireIsCallerAuthorized
        requireIsOperational
        returns(address[])
    {
        return enabledAirlines;
    }

    function flightSuretyInfo
        (
            address passenger,
            string flight
        )
        external
        requireIsCallerAuthorized
        requireIsOperational
        returns(uint256)
    {

        bytes32 key = keccak256(abi.encodePacked(passenger, flight));
        require(flightSurety[key] > 0, "There are no suretyr for this flight and passenger");
        return flightSurety[key];
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
        (
            address passenger,
            string flight
        )
        external
        payable
        requireIsOperational
    {
        require(msg.value <= 1 ether, "Maximum surety is 1 ether");
        bytes32 key = keccak256(abi.encodePacked(passenger, flight));
        require(!flights[flight].hasBeenInsured, "Surety was already paid");
        require(flightSurety[key] <= 0, "Passenger already bought surety");
        flightSurety[key] = msg.value;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
        (
            address passenger,
            string flight
        )
        external
        payable
        requireIsCallerAuthorized
        requireIsOperational
    {
         bytes32 key = keccak256(abi.encodePacked(passenger, flight));
        uint256 currentFund = flightSurety[key];
        require(currentFund > 0, "Nothing to refund");
        uint256 amountToCredit = currentFund.mul(15).div(10);
        flightSurety[key] = amountToCredit;
        emit CreditInsured(passenger, flight, amountToCredit);
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function withdraw
        (
            string flight,
            uint256 amount
        )
        external
        requireIsCallerAuthorized
        requireIsOperational
    {

        bytes32 key = keccak256(abi.encodePacked(msg.sender, flight));
        uint256 value = flightSurety[key];

        require(value >= amount, "Insufficient funds");

        flightSurety[key] = 0;
        msg.sender.transfer(amount);
        flightSurety[key] = value.sub(amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
        (
            address owner
        )
        public
        payable
        requireIsCallerAuthorized
        requireIsOperational
    {
        require(msg.value >= 10, "10 is the minimal amount");
        require(airlines[owner].isRegistered, "Airline wasn't register");

        uint256 cacheAmount = funds[owner];
        uint256 totalAmount = cacheAmount.add(msg.value);
        funds[owner] = 0;
        owner.transfer(totalAmount);

        if (airlines[owner].ownership != 1) {
            enabledAirlines.push(owner);
        }

        airlines[owner].ownership = 1;

        funds[owner] = totalAmount;
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
        external 
        payable 
        requireIsCallerAuthorized
        requireIsOperational
    {
        fund(msg.sender);
    }
}