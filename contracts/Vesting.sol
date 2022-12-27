// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "popp-interfaces/IEmployerSft.sol";
import "popp-interfaces/IJobNFT.sol";

// Desired Features
// - Allow an employer to lock ERC20 tokens for an employee for a period of time
// - Allow an employer to lock ETH for an employee for a period of time
// - After the lock period, the employee can withdraw the tokens/ETH
// - If the employee no longer works for the employer, the employer can withdraw the tokens/ETH
// - a way of viewing a particular employee's vesting schedule
// - a way of viewing the sender's vesting schedule
contract Vesting is
Ownable
{
    IERC20 private token;
    IEmployerSft private immutable employerSft;
    IJobNFT private immutable jobNFT;

    struct VestingSchedule {
        uint32 employerId;
        address erc20Address;
        uint256 total;
        uint256 timestamp;
    }

    mapping(address => mapping(uint256 => VestingSchedule)) private vestingSchedules;

    constructor(address _jobNFTAddress, address _IEmployerSftAddress) {
        employerSft = IEmployerSft(_IEmployerSftAddress);
        jobNFT = IJobNFT(_jobNFTAddress);
    }

    receive() external payable {}

    fallback() external payable {}

    /**
    * @dev Creates a vesting schedule for a given employee and locks ERC20 tokens for a given time.
    * This schedule is mapped to the employee current job for a given employer.
    * Note: sender has to grant approval to this contract before using this function
    * @param _erc20Address The ERC20 token address
    * @param _employee The employee to create a vesting schedule for
    * @param _total The total amount of tokens to vest
    * @param _timestamp The timestamp to start vesting
     **/
    function ERC20Vest(
        address _erc20Address,
        address _employee,
        uint256 _total,
        uint256 _timestamp
    ) public {
        _vest(_erc20Address, _employee, _total, _timestamp);

        token = IERC20(_erc20Address);

        token.transferFrom(
            msg.sender,
            address(this),
            _total
        );
    }

    /**
    * @dev Creates a vesting schedule for a given employee and locks ETH for a given time
    * @param _employee The employee to create a vesting schedule for
    * @param _timestamp The timestamp to start vesting
     **/
    function ETHVest(
        address _employee,
        uint256 _timestamp
    ) public payable {
        // null address here means it's ETH
        _vest(address(0), _employee, msg.value, _timestamp);
    }

    /**
    * @dev Creates a vesting schedule for a given employee and locks ERC20 tokens for a given time.
    * This schedule is mapped to the employee current job for a given employer
    * @param _erc20Address The ERC20 token address
    * @param _employee The employee to create a vesting schedule for
    * @param _total The total amount of tokens to vest
    * @param _timestamp The timestamp to start vesting
     **/
    function _vest(
        address _erc20Address,
        address _employee,
        uint256 _total,
        uint256 _timestamp
    ) internal {
        require(
            _total > 0,
            "Total cannot be 0"
        );

        uint32 employerId = employerSft.employerIdFromWallet(msg.sender);

        require(
            employerId != 0,
            "You need to be verified as an employer to create a vesting schedule"
        );

        // here we determine the job id from the employer id (an employee can only hold one job nft per employer)
        uint256 jobId = jobNFT.getJobIdFromEmployeeAndEmployer(msg.sender, employerId);

        require(
            jobId != 0,
            "The given address doesn't work for your employer"
        );

        require(
            hasVestingSchedule(_employee, jobId) == false,
            "The employee already has a vesting schedule for this job"
        );

        VestingSchedule memory vestingSchedule = VestingSchedule(
            employerId,
            _erc20Address,
            _total,
            _timestamp
        );

        vestingSchedules[_employee][jobId] = vestingSchedule;
    }

    /**
    * @dev payout the vested amount of tokens to the employee
    * @param _jobId The job id associated with the vesting schedule
    **/
    function payout(uint256 _jobId) public {
        address employee = msg.sender;
        VestingSchedule memory vestingSchedule = vestingSchedules[employee][_jobId];

        require(
            vestingSchedule.total > 0,
            "Vesting schedule not found"
        );

        require(
            vestingSchedule.timestamp <= block.timestamp,
            "Vesting period has not passed"
        );

        // this to ensure the employee is still working for the given employer
        require(
            jobNFT.isEmployedBy(employee, vestingSchedule.employerId),
            "Address is not employed thus cannot be paid"
        );

        delete vestingSchedules[employee][_jobId];

        if (vestingSchedule.erc20Address == address(0)) {
            (bool sent,) = payable(employee).call{value : vestingSchedule.total}("");
            require(sent, "Failed to send Ether");
        } else {
            token = IERC20(vestingSchedule.erc20Address);
            token.transfer(employee, vestingSchedule.total);
        }
    }

    /**
    * @dev an employer can cancel a vesting schedule when the employee no longer works for them.
    * Note: this can only happen if the given employee is no longer employed by the given employer
    * @param _employee The employee for which to cancel the vesting schedule
    * @param _jobId The job id associated with the vesting schedule
    **/
    function cancel(address _employee, uint256 _jobId) public {
        address employer = msg.sender;
        VestingSchedule memory vestingSchedule = vestingSchedules[_employee][_jobId];

        require(
            vestingSchedule.total > 0,
            "Vesting schedule not found"
        );

        require(
            _jobId != jobNFT.getJobIdFromEmployeeAndEmployer(_employee, vestingSchedule.employerId),
            "Address is still employed, thus cannot be cancelled"
        );

        require(
            vestingSchedule.employerId == employerSft.employerIdFromWallet(employer),
            "Vesting schedule not found"
        );

        delete vestingSchedules[_employee][_jobId];

        if (vestingSchedule.erc20Address == address(0)) {
            (bool sent,) = payable(msg.sender).call{value : vestingSchedule.total}("");
            require(sent, "Failed to send Ether");
        } else {
            token = IERC20(vestingSchedule.erc20Address);
            token.transfer(msg.sender, vestingSchedule.total);
        }
    }

    /**
    * @dev returns the vesting schedule for the sender and job id
    * @param _jobId The job id associated with the vesting schedule
    **/
    function getMyVestingSchedule(uint256 _jobId) external view returns (VestingSchedule memory) {
        return vestingSchedules[msg.sender][_jobId];
    }

    /**
    * @dev returns the vesting schedule for a given employee and job id
    * @param _employee The employee to create a vesting schedule for
    * @param _jobId The job id associated with the vesting schedule
    **/
    function getVestingSchedule(address _employee, uint256 _jobId) external view returns (VestingSchedule memory) {
        return vestingSchedules[_employee][_jobId];
    }

    /**
    * @dev checks if given employee already has a vesting schedule for a given job id
    * @param _employee The employee to check
    * @param _jobId The job id to check
    **/
    function hasVestingSchedule(address _employee, uint256 _jobId) public view returns (bool) {
        return vestingSchedules[_employee][_jobId].total > 0;
    }
}
