// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract EnergyTrading {
    error ZeroEnergyProvided();
    error AlreadyFulfilled();
    error UnauthorizedAccess();
    error RefundFailed();
    error TransactionFailed();
    error InsufficientFunds();

    uint public tradeCounter;
    uint public publicFundBalance;
    bool public isPublicFundActive;

    struct EnergyTrade {
        uint id;
        string title;
        string description;
        uint energyRequired; // Energy required in kilowatt-hours (kWh)
        uint energyProvided; // Energy provided in kWh
        uint fundsAllocated; // Funds allocated in Wei
        uint fundsWithdrawn; // Funds withdrawn in Wei
        address requester; // Address of the energy consumer
        address provider; // Address of the energy producer
    }

    mapping(uint => EnergyTrade) public idToTrade;

    function newEnergyRequest(
        string memory _title,
        string memory _description,
        uint _energyRequired
    ) public payable {
        tradeCounter++;

        if (_energyRequired <= 0 || msg.value <= 0) {
            revert ZeroEnergyProvided();
        }

        idToTrade[tradeCounter] = EnergyTrade({
            id: tradeCounter,
            title: _title,
            description: _description,
            energyRequired: _energyRequired,
            energyProvided: 0,
            fundsAllocated: msg.value,
            fundsWithdrawn: 0,
            requester: msg.sender,
            provider: address(0)
        });
    }

    function provideEnergy(uint _id, uint _energyProvided) public {
        EnergyTrade storage trade = idToTrade[_id];

        if (trade.energyProvided >= trade.energyRequired) {
            revert AlreadyFulfilled();
        }

        trade.energyProvided += _energyProvided;
        trade.provider = msg.sender;

        if (trade.energyProvided > trade.energyRequired) {
            uint excessEnergy = trade.energyProvided - trade.energyRequired;
            trade.energyProvided -= excessEnergy;
        }

        if (trade.energyProvided == trade.energyRequired) {
            uint payment = trade.fundsAllocated;
            (bool success, ) = payable(trade.provider).call{value: payment}("");
            if (!success) {
                revert TransactionFailed();
            }
            trade.fundsWithdrawn = payment;
        }
    }

    function withdrawExcessFunds(uint _id) public {
        EnergyTrade storage trade = idToTrade[_id];
        if (msg.sender != trade.requester) {
            revert UnauthorizedAccess();
        }

        uint excessFunds = trade.fundsAllocated - trade.fundsWithdrawn;
        if (excessFunds > 0) {
            (bool success, ) = payable(trade.requester).call{value: excessFunds}("");
            if (!success) {
                revert RefundFailed();
            }
            trade.fundsWithdrawn += excessFunds;
        }
    }

    function contributeToPublicFund() external payable {
        publicFundBalance += msg.value;
    }

    function activatePublicFund() public {
        if (publicFundBalance < 1 ether) {
            revert InsufficientFunds();
        }
        isPublicFundActive = true;
    }

    function allocatePublicFund(uint _id) public {
        if (!isPublicFundActive) {
            revert UnauthorizedAccess();
        }

        EnergyTrade storage trade = idToTrade[_id];
        if (trade.energyProvided >= trade.energyRequired) {
            revert AlreadyFulfilled();
        }

        uint allocation = publicFundBalance;
        publicFundBalance = 0;
        isPublicFundActive = false;

        trade.fundsAllocated += allocation;
        trade.fundsWithdrawn += allocation;

        (bool success, ) = payable(trade.provider).call{value: allocation}("");
        if (!success) {
            revert TransactionFailed();
        }
    }

    receive() external payable {}

    fallback() external payable {}
}
