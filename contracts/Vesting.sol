// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "popp-interfaces/IJobNFT.sol";

contract Vesting is
Ownable
{
    IERC20 token;
    IJobNFT jobNFT;

    struct VestingSchedule {
        uint32 employerId;
        address erc20Address;
        uint256 total;
        uint256 timestamp;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    constructor(address _jobNFTAddress) {
        jobNFT = IJobNFT(_jobNFTAddress);
    }

    function ERC20Vest(
        address _erc20Address,
        address _employee,
        uint256 _total,
        uint256 _timestamp
    ) public {
        token = IERC20(_erc20Address);

        token.transferFrom(
            msg.sender,
            address(this),
            _total
        );

        _vest(_erc20Address, _employee, _total, _timestamp);
    }

    function ETHVest(
        address _employee,
        uint256 _total,
        uint256 _timestamp
    ) public payable {
        require(
            msg.value == _total,
            "Not enough ETH sent"
        );
        // null address here means it's ETH
        _vest(address(0), _employee, _total, _timestamp);
    }

    function _vest(
        address _erc20Address,
        address _employee,
        uint256 _total,
        uint256 _timestamp
    ) internal {
        uint32 employerId = getEmployerIdFromEmployee(_employee);
        require(
            _total > 0,
            "Total cannot be 0"
        );

        require(
            employerId != 0,
            "Employee has no employer"
        );

        VestingSchedule memory vestingSchedule = VestingSchedule(
            employerId,
            _erc20Address,
            _total,
            _timestamp
        );

        vestingSchedules[_employee] = vestingSchedule;
    }

    function payout() public {
        VestingSchedule memory vestingSchedule = vestingSchedules[msg.sender];
        require(
            vestingSchedule.total > 0,
            "Vesting schedule not found"
        );

        require(
            vestingSchedule.timestamp <= block.timestamp,
            "Vesting period has not passed"
        );

        require(
            vestingSchedule.employerId == getEmployerIdFromEmployee(msg.sender),
            "You are not employed by this employer"
        );
        // avoid re-entry
        delete vestingSchedules[msg.sender];

        if ( vestingSchedule.erc20Address == address(0) ) {
            payable(msg.sender).transfer(vestingSchedule.total);
        } else {
            token = IERC20(vestingSchedule.erc20Address);
            token.transfer(msg.sender, vestingSchedule.total);
        }
    }

    function cancel(address _to) public {
        VestingSchedule memory vestingSchedule = vestingSchedules[_to];
        require(
            vestingSchedule.total > 0,
            "Vesting schedule not found"
        );

        require(
            vestingSchedule.employerId != getEmployerIdFromEmployee(_to),
            "Address is still employed"
        );

        // avoid re-entry
        delete vestingSchedules[_to];

        if ( vestingSchedule.erc20Address == address(0) ) {
            payable(msg.sender).transfer(vestingSchedule.total);
        } else {
            token = IERC20(vestingSchedule.erc20Address);
            token.transfer(msg.sender, vestingSchedule.total);
        }
    }

    function getEmployerIdFromEmployee(address _address) public view returns (uint32) {
        return jobNFT.getEmployerIdFromJobId(jobNFT.getJobIdFromEmployee(_address));
    }

    function getMyVestingSchedule() external view returns (VestingSchedule memory) {
        return vestingSchedules[msg.sender];
    }
}
