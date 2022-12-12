// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC721.sol";

interface IJobNft is IERC721{
    function getEmployerIdFromJobId(uint256 _jobId) external view returns (uint32);
    function getJobIdFromEmployee(address _employee) external view returns (uint256);
}
