// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LetterOfCredit {
    using SafeMath for uint256;

    
    address public owner;
    mapping(address => bool) public sellers;
    mapping(address => bool) public buyers;
    mapping(address => bool) public issuingBanks;
    mapping(address => bool) public advisingBanks;

    struct LC {
        address seller;
        address buyer;
        address issuingBank;
        address advisingBank;
        bool initialized;
    }

    struct ProductSelection {
        string productName;
        uint256 quantity;
    }

    struct NegotiationDetails {
        uint256 proformaInvoice; 
        string orderId;
        uint256 amount;
        uint256 dateOfIssue;
        uint256 dateOfExpiry;
        string cancellation;
        bool approved;
    }

    struct LCApplication {
        uint256 proformaInvoice;
        string orderId;
        uint256 amount;
        uint256 dateOfIssue;
        uint256 dateOfExpiry;
        string cancellation;
    }

    struct BillOfLading {
        uint256 proformaInvoice;
        string orderId;
        uint256 amount;
        uint256 dateOfIssue;
        uint256 dateOfExpiry;
        string cancellation;
        bool verified;
        bool isPaid;
        uint8 state;
    }

   
    mapping(address => LC) public LCs;
    mapping(address => ProductSelection) public productSelections;
    mapping(address => NegotiationDetails) public negotiationDetails;
    mapping(address => mapping(address => LCApplication)) public lcApplications;
    mapping(address => mapping(address => LCApplication))
        public transferredLCApplications;
    mapping(address => mapping(uint256 => bool)) public shippedGoods;
    mapping(address => mapping(uint256 => BillOfLading)) public billsOfLading;
    mapping(address => uint256) escrowDeposit;


    event LCInitialized(
        address indexed seller,
        address indexed issuingBank,
        address indexed advisingBank
    );
    event ProductSelected(
        address indexed buyer,
        string productName,
        uint256 quantity
    );
    event DetailsNegotiated(
        address indexed seller,
        uint256 proformaInvoice,
        string orderId,
        uint256 amount,
        uint256 dateOfIssue,
        uint256 dateOfExpiry,
        string cancellation
    );
    event DetailsApproved(address indexed buyer);
    event LCState(address indexed buyer, bool initialized);

    event LCApplicationSubmitted(
        address indexed buyer,
        uint256 proformaInvoice,
        string orderId,
        uint256 amount,
        uint256 expiryDate,
        string cancellation
    );
    event LCApplicationVerified(
        address indexed advisingBank,
        address indexed buyer
    );
    event LCApplicationTransferredToSeller(
        address indexed seller,
        uint256 indexed proformaInvoice
    );
    event LCApplicationVerifiedBySeller(
        address indexed seller,
        uint256 indexed proformaInvoice
    );
    event GoodsShipped(
        address indexed seller,
        address indexed buyer,
        uint256 indexed proformaInvoice,
        string orderId
    );
    event BillOfLadingGenerated(
        address indexed buyer,
        uint256 indexed proformaInvoice,
        string orderId,
        uint256 amount,
        uint256 dateOfIssue,
        uint256 dateOfExpiry,
        string cancellation
    );
    event BillOfLadingTransferred(
        address indexed seller,
        address indexed advisingBank,
        uint256 indexed proformaInvoice
    );
    event BillOfLadingVerified(
        address indexed advisingBank,
        uint256 indexed proformaInvoice
    );
    event Debug(
        address buyer,
        address seller,
        uint256 proformaInvoice,
        uint256 storedProformaInvoice
    );

    event GoodsShippedByBuyer(
        address indexed buyer,
        uint256 indexed proformaInvoice
    );
    event PaymentMadeToAdvisingBank(
        address indexed issuingBank,
        address indexed advisingBank,
        uint256 indexed proformaInvoice
    );

    event SuccessfulPaymentByIssuingBank(address indexed issuingBank, address indexed buyer, address indexed seller, uint8 state, uint256 amount);
    event SuccessfulWithdrawlFromEscrow(address buyer, uint256 amount);

    
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only contract owner can call this function"
        );
        _;
    }

    modifier onlySeller() {
        require(sellers[msg.sender], "Only sellers can call this function");
        _;
    }

    modifier onlyBuyer() {
        require(buyers[msg.sender], "Only buyers can call this function");
        _;
    }

    modifier onlyIssuingBank() {
        require(
            issuingBanks[msg.sender],
            "Only issuing banks can call this function"
        );
        _;
    }

    modifier onlyAdvisingBank() {
        require(
            advisingBanks[msg.sender],
            "Only advising banks can call this function"
        );
        _;
    }

  
    constructor() {
        owner = msg.sender;
    }

    // Functions to add sellers, buyers, issuing banks, and advising banks
    function addSeller(address _seller) public onlyOwner {
        sellers[_seller] = true;
    }

    function addBuyer(address _buyer) public onlyOwner {
        buyers[_buyer] = true;
    }

    function addIssuingBank(address _issuingBank) public onlyOwner {
        issuingBanks[_issuingBank] = true;
    }

    function addAdvisingBank(address _advisingBank) public onlyOwner {
        advisingBanks[_advisingBank] = true;
    }

    function initializeLC(
        address _seller,
        address _issuingBank,
        address _advisingBank
    ) public {
        address _buyer = msg.sender;

        require(buyers[_buyer], "Only buyer can initialize LC");
        require(_seller != address(0), "Invalid seller address");
        require(_issuingBank != address(0), "Invalid issuing bank address");
        require(_advisingBank != address(0), "Invalid advising bank address");

        LCs[_buyer] = LC(_seller, _buyer, _issuingBank, _advisingBank, true);

        emit LCInitialized(_seller, _issuingBank, _advisingBank);
        emit LCState(_buyer, LCs[_buyer].initialized); // Add this line for logging
    }

    function selectProduct(string memory _productName, uint256 _quantity)
        public
        onlyBuyer
    {
        LC storage lc = LCs[msg.sender];
        require(lc.initialized, "LC not initialized");
        
        require(lc.seller != address(0), "Invalid seller address");

        productSelections[msg.sender] = ProductSelection(
            _productName,
            _quantity
        );
        emit ProductSelected(msg.sender, _productName, _quantity);
    }

   
    function negotiateDetails(
        address _buyer,
        uint256 _proformaInvoice,
        string memory _orderId,
        uint256 _amount,
        uint256 _dateOfIssue,
        uint256 _dateOfExpiry,
        string memory _cancellation
    ) public {
        address _seller = msg.sender;
        require(LCs[_buyer].initialized, "LC not initialized");
        require(
            msg.sender == LCs[_buyer].seller,
            "Only the seller can negotiate details"
        );
        require(escrowDeposit[_buyer] >= _amount, "not enough money in buyer's escrow account");

        negotiationDetails[_seller] = NegotiationDetails(
            _proformaInvoice,
            _orderId,
            _amount,
            _dateOfIssue,
            _dateOfExpiry,
            _cancellation,
            false
        );

        emit DetailsNegotiated(
            _seller,
            _proformaInvoice,
            _orderId,
            _amount,
            _dateOfIssue,
            _dateOfExpiry,
            _cancellation
        );
    }

    function approveNegotiation() public {
        address _buyer = msg.sender;
        require(LCs[_buyer].initialized, "LC not initialized");
        require(
            msg.sender == LCs[_buyer].buyer,
            "Only the buyer can approve negotiation details"
        );

        negotiationDetails[LCs[_buyer].seller].approved = true;

        emit DetailsApproved(_buyer);
    }

    
    function applyForLC(
        address _issuingBank,
        uint256 _proformaInvoice,
        string memory _orderId,
        uint256 _amount,
        uint256 _dateOfIssue,
        uint256 _dateOfExpiry,
        string memory _cancellation
    ) public onlyBuyer {
        require(
            issuingBanks[_issuingBank],
            "Only the issuing bank can be specified"
        );

        lcApplications[_issuingBank][msg.sender] = LCApplication(
            _proformaInvoice,
            _orderId,
            _amount,
            _dateOfIssue,
            _dateOfExpiry,
            _cancellation
        );

        emit LCApplicationSubmitted(
            msg.sender,
            _proformaInvoice,
            _orderId,
            _amount,
            _dateOfExpiry,
            _cancellation
        );
    }

   
    function transferLCApplication(address _advisingBank, address _buyer)
        public
        onlyIssuingBank
    {
        LCApplication memory lcApplication = lcApplications[msg.sender][_buyer];

        require(
            lcApplication.proformaInvoice != 0,
            "LC Application does not exist"
        );

        lcApplications[msg.sender][_buyer] = LCApplication(0, "", 0, 0, 0, "");

        lcApplications[_advisingBank][_buyer] = lcApplication;
    }

    
    function verifyLCApplication(address _buyer) public onlyAdvisingBank {
        address _advisingBank = msg.sender; 

        LCApplication storage lcApp = lcApplications[_advisingBank][_buyer];

        require(lcApp.proformaInvoice != 0, "LC application not found");

        emit LCApplicationVerified(_advisingBank, _buyer);
    }

    function transferLCApplicationToSeller(address _seller, address _buyer)
        public
        onlyAdvisingBank
    {
        LCApplication memory lcApplication = lcApplications[msg.sender][_buyer];

        require(
            lcApplication.proformaInvoice != 0,
            "LC Application does not exist"
        );

        lcApplications[msg.sender][_buyer] = LCApplication(0, "", 0, 0, 0, "");

        transferredLCApplications[msg.sender][_seller] = lcApplication;
    }

    
    function verifyTransferredLCApplication(
        address _buyer,
        address _advisingBank
    ) public {
        address _seller = msg.sender;
        LC storage lc = LCs[_buyer];

        require(lc.initialized, "LC not initialized");
        require(
            lc.seller == _seller,
            "Only the seller can verify the transferred LC application"
        );
        require(lc.buyer == _buyer, "Invalid buyer address");
        require(
            lc.advisingBank == _advisingBank,
            "Invalid advising bank address"
        );

        LCApplication storage lcApp = transferredLCApplications[_advisingBank][
            _seller
        ];

        require(
            lcApp.proformaInvoice != 0,
            "Transferred LC application not found"
        );

        emit LCApplicationVerifiedBySeller(_seller, lcApp.proformaInvoice);
    }

    function shipGoods(
        address _buyer,
        uint256 _proformaInvoice,
        string memory _orderId
    ) public onlySeller {
        LC storage lc = LCs[_buyer];

        require(lc.initialized, "LC not initialized");
        require(lc.seller == msg.sender, "Only the seller can ship the goods");
        require(
            !shippedGoods[msg.sender][_proformaInvoice],
            "Goods already shipped for this invoice"
        );

        shippedGoods[msg.sender][_proformaInvoice] = true;

        emit GoodsShipped(msg.sender, _buyer, _proformaInvoice, _orderId);
    }

    function generateBillOfLading(
        address _buyer,
        uint256 _proformaInvoice,
        string memory _orderId,
        uint256 _amount,
        uint256 _dateOfIssue,
        uint256 _dateOfExpiry,
        string memory _cancellation
    ) public onlySeller {
        LC storage lc = LCs[_buyer];

        require(lc.initialized, "LC not initialized");
        require(
            lc.seller == msg.sender,
            "Only the seller can generate a bill of lading"
        );

        // billsOfLading[msg.sender][_proformaInvoice] = BillOfLading(_proformaInvoice, _orderId, _amount, _dateOfIssue, _dateOfExpiry, _cancellation);
        billsOfLading[msg.sender][_proformaInvoice] = BillOfLading(
            _proformaInvoice,
            _orderId,
            _amount,
            _dateOfIssue,
            _dateOfExpiry,
            _cancellation,
            false,
            false,
            0
        );

        emit BillOfLadingGenerated(
            _buyer,
            _proformaInvoice,
            _orderId,
            _amount,
            _dateOfIssue,
            _dateOfExpiry,
            _cancellation
        );
    }


    function sendBillOfLadingToAdvisingBank(
        address _buyer,
        address _advisingBank,
        uint256 _proformaInvoice
    ) public onlySeller {
        LC storage lc = LCs[_buyer];

        require(lc.initialized, "LC not initialized");
        require(
            lc.seller == msg.sender,
            "Only the seller can send a bill of lading"
        );
        require(advisingBanks[_advisingBank], "Invalid advising bank address");

        BillOfLading storage bill = billsOfLading[msg.sender][_proformaInvoice];
        require(
            bill.proformaInvoice == _proformaInvoice,
            "Bill of lading not found"
        );
        require(billsOfLading[msg.sender][_proformaInvoice].state == 0, "bill of lading not generated by seller");

        billsOfLading[msg.sender][_proformaInvoice].state = 1;

        // Transfer the bill of lading to the advising bank
        // bill.proformaInvoice = 0; // Remove the bill of lading from the seller's record

        emit BillOfLadingTransferred(
            msg.sender,
            _advisingBank,
            _proformaInvoice
        );
    }

    function verifyBillOfLading(
        address _buyer,
        address _seller,
        uint256 _proformaInvoice
    ) public onlyAdvisingBank {
        LC storage lc = LCs[_buyer];

        require(lc.initialized, "LC not initialized");
        require(
            lc.advisingBank == msg.sender,
            "Only the advising bank can verify the bill of lading"
        );

        BillOfLading storage bill = billsOfLading[_seller][_proformaInvoice];
        require(bill.proformaInvoice != 0, "Bill of lading not found");
        require(!bill.verified, "Bill of lading already verified");
        require(billsOfLading[_seller][_proformaInvoice].state == 1, "bill of lading not transferred to advising bank");

        bill.verified = true;
        billsOfLading[_seller][_proformaInvoice].state = 2;

        emit BillOfLadingVerified(msg.sender, _proformaInvoice);
    }

    function sendBillOfLadingToIssuingBank(
        address _buyer,
        address _issuingBank,
        address _seller,
        uint256 _proformaInvoice
    ) public onlyAdvisingBank {
        LC storage lc = LCs[_buyer];

        require(lc.initialized, "LC not initialized");
        require(lc.issuingBank == _issuingBank, "Invalid issuing bank");
        require(
            billsOfLading[_seller][_proformaInvoice].proformaInvoice != 0,
            "Bill of lading not transferred to advising bank"
        );
        require(billsOfLading[_seller][_proformaInvoice].state == 2, "bill of lading not verified at advising bank");

        // Transfer the bill of lading to the issuing bank
        billsOfLading[_buyer][_proformaInvoice] = billsOfLading[_seller][
            _proformaInvoice
        ]; // Add bill of lading to the issuing bank record.
        billsOfLading[_buyer][_proformaInvoice].proformaInvoice = 0; // Remove the bill of lading from the advising bank's record.
        billsOfLading[_buyer][_proformaInvoice].state = 3;

        emit BillOfLadingTransferred(_seller, _issuingBank, _proformaInvoice);
    }

    function verifyBillOfLadingByIssuingBank(
        address _buyer,
        address _seller,
        uint256 _proformaInvoice
    ) public onlyIssuingBank {
        LC storage lc = LCs[_buyer];

        require(lc.initialized, "LC not initialized");
        require(
            lc.issuingBank == msg.sender,
            "Only the issuing bank can verify the bill of lading"
        );

        require(
            billsOfLading[_seller][_proformaInvoice].proformaInvoice != 0,
            "Bill of lading not transferred to issuing bank"
        );
        require(
            billsOfLading[_buyer][_proformaInvoice].proformaInvoice == 0,
            "Bill of lading not removed from advising bank record"
        );
        require(billsOfLading[_buyer][_proformaInvoice].state == 3, "bill of landing not transferred to issuing bank");
        billsOfLading[_buyer][_proformaInvoice].state = 4;

        emit BillOfLadingVerified(msg.sender, _proformaInvoice);
    }

    function sendBillOfLadingToBuyer(address _buyer, address _seller, uint256 _proformaInvoice)
        public
        onlyIssuingBank
    {
        require(
            billsOfLading[_seller][_proformaInvoice].proformaInvoice != 0,
            "bill of lading not found at issuing bank"
        );
        require(billsOfLading[_buyer][_proformaInvoice].state == 4, "bill of lading not verified at issuing bank");

        // transferring the bill of lading to buyer
        billsOfLading[_buyer][_proformaInvoice].proformaInvoice = 0;
        billsOfLading[_buyer][_proformaInvoice].state = 5;

        emit BillOfLadingTransferred(msg.sender, _buyer, _proformaInvoice);
    }

    function verifyBillOfLadingByBuyer(uint256 _proformaInvoice)
        public
        onlyBuyer
    {
        require(
            billsOfLading[msg.sender][_proformaInvoice].proformaInvoice == 0,
            "bill of landing not correctly transferred"
        );
        require(billsOfLading[msg.sender][_proformaInvoice].state == 5, "bill of lading not transferred to buyer");
        billsOfLading[msg.sender][_proformaInvoice].state = 6;
        emit BillOfLadingVerified(msg.sender, _proformaInvoice);
    }

    function payToAdvisingBankByIssuingBank(address _buyer, uint256 _proformaInvoice, address _seller, address _advisingBank) public onlyIssuingBank {
        require(billsOfLading[_buyer][_proformaInvoice].proformaInvoice == 0, "bill of lading not transferred to buyer");
        require(billsOfLading[_buyer][_proformaInvoice].state == 6, "bill of lading not verified by buyer");
        // make payment to advising bank
        
        BillOfLading memory billoflading = billsOfLading[_buyer][_proformaInvoice];
        uint8 state = billsOfLading[_buyer][_proformaInvoice].state;

        payAmountByIssuingBank(_buyer, billoflading.amount, _advisingBank);
        billsOfLading[_buyer][_proformaInvoice].state == 7;
        billsOfLading[_buyer][_proformaInvoice].isPaid = true;

        emit SuccessfulPaymentByIssuingBank(msg.sender, _buyer, _seller, state, billsOfLading[_buyer][_proformaInvoice].amount);
    }

    function addAmountToEscrowByBuyer(uint256 amount) onlyBuyer payable public {
        require(msg.value == amount, "amount and sent value do not match");
        escrowDeposit[msg.sender] += amount;
    }

    function payAmountByIssuingBank(address _buyer, uint256 _amount, address advisingBank) internal {
        require(_amount < escrowDeposit[_buyer], "insufficient amount in the escrow by buyer");
        escrowDeposit[_buyer] -= _amount;
        bool sent = payable(advisingBank).send(_amount);
        require(sent, "failure to send money from escrow account to ");
    }

     // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}


    
}
