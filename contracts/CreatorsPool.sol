//    Copyright (C) 2017 LikeCoin Foundation Limited
//
//    This file is part of LikeCoin Smart Contract.
//
//    LikeCoin Smart Contract is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    LikeCoin Smart Contract is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with LikeCoin Smart Contract.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/ownership/Claimable.sol";
import "./LikeCoin.sol";

contract CreatorsPool is Claimable {
    using SafeMath for uint256;

    LikeCoin public like = LikeCoin(0x0);
    uint public mintSlotLength = 0;
    uint public prevSlot = 0;
    uint256 public mintValue = 0;

    function CreatorsPool(address _likeAddr, uint _mintSlotLength, uint256 _mintValue) public {
        require(_mintValue > 0);
        require(_mintSlotLength > 0);
        like = LikeCoin(_likeAddr);
        mintValue = _mintValue;
        prevSlot = now / _mintSlotLength - 1;
    }

    function mint(uint256 _value) public {
        uint slotNow = now / mintSlotLength;
        uint256 mintAllowance = slotNow.sub(prevSlot).mul(mintValue);
        like.mintForCreatorsPool(mintAllowance);
    }

    function proposeTransfer(address _to, uint256 _value) public {
        require(ownerIndex[msg.sender] != 0);
        require(_value > 0);
        uint64 id = _nextId();
        proposals[id] = Proposal(id, msg.sender, threshold, 0);
        transferInfo[id] = TransferInfo(id, _to, _value);
        TransferProposal(id, msg.sender, _to, _value);
    }

    mapping (address => bool) ownerDuplicationCheck;

    function proposeSetOwners(address[] _newOwners, uint8 _newThreshold) public {
        require(ownerIndex[msg.sender] != 0);
        require(_newOwners.length < 256);
        require(_newOwners.length > 0);
        require(_newThreshold > 0);
        require(_newOwners.length >= _newThreshold);
        for (uint8 i = 0; i < _newOwners.length; ++i) {
            delete ownerDuplicationCheck[_newOwners[i]];
        }
        for (i = 0; i < _newOwners.length; ++i) {
            require(ownerDuplicationCheck[_newOwners[i]] == false);
            ownerDuplicationCheck[_newOwners[i]] = true;
        }
        uint64 id = _nextId();
        proposals[id] = Proposal(id, msg.sender, threshold, 0);
        setOwnersInfo[id] = SetOwnersInfo(id, _newThreshold, _newOwners);
        SetOwnersProposal(id, msg.sender, _newOwners, _newThreshold);
    }

    function confirmProposal(uint64 id) public {
        require(id >= minUsableId);
        require(proposals[id].id == id);
        require(proposals[id].confirmNeeded > 0);
        uint256 index = ownerIndex[msg.sender];
        require(index != 0);
        require((proposals[id].confirmedTable & index) == 0);
        proposals[id].confirmedTable |= index;
        proposals[id].confirmNeeded -= 1;
        ProposalConfirmation(id, msg.sender);
    }

    function executeProposal(uint64 id) public {
        require(id >= minUsableId);
        require(proposals[id].id == id);
        require(proposals[id].confirmNeeded == 0);
        uint256 index = ownerIndex[msg.sender];
        require(index != 0);
        if (transferInfo[id].id == id) {
            like.transfer(transferInfo[id].to, transferInfo[id].value);
            delete transferInfo[id];
        } else if (setOwnersInfo[id].id == id) {
            for (uint8 i = 0; i < owners.length; ++i) {
                delete ownerIndex[owners[i]];
            }
            owners.length = 0;
            for (i = 0; i < setOwnersInfo[id].newOwners.length; ++i) {
                owners.push(setOwnersInfo[id].newOwners[i]);
                ownerIndex[setOwnersInfo[id].newOwners[i]] = uint256(1) << i;
            }
            threshold = setOwnersInfo[id].newThreshold;
            minUsableId = nextId;
            delete setOwnersInfo[id];
        } else {
            revert();
        }
        delete proposals[id];
        ProposalExecution(id, msg.sender);
    }
}
