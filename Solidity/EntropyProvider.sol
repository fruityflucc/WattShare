// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract EnergyTrading {
    error Trade__ZeroEnergyRequired();
    error Trade__AlreadyFulfilled();
    error Trade__UnauthorizedAccess();
    error Trade__RefundFailed();
    error Trade__TransactionFailed();
    error Trade__InsufficientPublicFunds();

    uint public tradeCounter;
    uint public publicFundCounter;
    uint public publicFundBalance;
    bool public isPublicFundActive;

    struct Trade {
        uint id;
        string imageUrl;
        string title;
        string description;
        uint energyRequired; // Energy required in kWh
        uint energyContributed; // Energy contributed in kWh
        uint fundsAllocatedInWei; // Funds allocated for this trade in Wei
        uint fundsWithdrawnInWei; // Funds withdrawn from this trade in Wei
        address consumerAddress; // Address of the consumer initiating the trade
        address producerAddress; // Address of the producer fulfilling the trade
    }

    mapping(uint => Trade) public idToTrade;

    function createTrade(
        string memory _title,
        string memory _description,
        uint _energyRequired,
        uint _fundsAllocatedInWei,
        string memory _imageUrl
    ) public payable {
        tradeCounter++;

        if (_energyRequired <= 0 || _fundsAllocatedInWei <= 0) {
            revert Trade__ZeroEnergyRequired();
        }

        idToTrade[tradeCounter] = Trade({
            id: tradeCounter,
            imageUrl: _imageUrl,
            title: _title,
            description: _description,
            energyRequired: _energyRequired,
            energyContributed: 0,
            fundsAllocatedInWei: _fundsAllocatedInWei,
            fundsWithdrawnInWei: 0,
            consumerAddress: msg.sender,
            producerAddress: address(0)
        });
    }

    function contributeEnergy(uint _id, uint _energyContributed) public {
        Trade storage trade = idToTrade[_id];

        if (trade.energyContributed >= trade.energyRequired) {
            revert Trade__AlreadyFulfilled();
        }

        trade.energyContributed += _energyContributed;
        trade.producerAddress = msg.sender;

        if (trade.energyContributed > trade.energyRequired) {
            trade.energyContributed = trade.energyRequired; // Prevent over-contribution
        }

        if (trade.energyContributed == trade.energyRequired) {
            uint payment = trade.fundsAllocatedInWei;
            (bool success, ) = payable(trade.producerAddress).call{value: payment}("");
            if (!success) {
                revert Trade__TransactionFailed();
            }
            trade.fundsWithdrawnInWei = payment;
        }
    }

    function activatePublicFund() public {
        if (publicFundBalance < 1 ether) {
            revert Trade__InsufficientPublicFunds();
        }
        isPublicFundActive = true;
    }

    function allocatePublicFund(uint _id) public {
        if (!isPublicFundActive) {
            revert Trade__UnauthorizedAccess();
        }

        Trade storage trade = idToTrade[_id];
        if (trade.energyContributed >= trade.energyRequired) {
            revert Trade__AlreadyFulfilled();
        }

        uint allocation = publicFundBalance;
        publicFundBalance = 0;
        isPublicFundActive = false;

        trade.fundsAllocatedInWei += allocation;
        trade.fundsWithdrawnInWei += allocation;

        (bool success, ) = payable(trade.producerAddress).call{value: allocation}("");
        if (!success) {
            revert Trade__TransactionFailed();
        }
    }

    function fundPublicPool() external payable {
        publicFundBalance += msg.value;
        publicFundCounter++;
    }

    function withdrawExcessFunds(uint _id) public {
        Trade storage trade = idToTrade[_id];

        if (msg.sender != trade.consumerAddress) {
            revert Trade__UnauthorizedAccess();
        }

        uint excessFunds = trade.fundsAllocatedInWei - trade.fundsWithdrawnInWei;
        if (excessFunds > 0) {
            (bool success, ) = payable(trade.consumerAddress).call{value: excessFunds}("");
            if (!success) {
                revert Trade__RefundFailed();
            }
            trade.fundsWithdrawnInWei += excessFunds;
        }
    }

    receive() external payable {}

    fallback() external payable {}
}
