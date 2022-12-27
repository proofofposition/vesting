// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "popp-interfaces/IJobNFT.sol";

contract JobNftMock is
IJobNFT,
ERC721
{
    uint32 public employerId;
    uint256 public jobId;

    event NewJob(address employee);

    function canMintJob(string memory, address, uint32) external pure returns (bool){
        return true;
    }

    function approveMint(address, string memory) external {
    }

    function mintItem(address employee) external {
        emit NewJob(employee);
    }

    constructor(string memory, string memory) ERC721('POPPNFT', 'POPPNFT') {}

    function mintFor(address _employee, uint32) external {
        _mint(_employee, 1);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function getChainId() external view returns (uint256) {
        return block.chainid;
    }

    function setJobId(uint256 _jobId) external {
        jobId = _jobId;
    }

    function setEmployerId(uint32 _employerId) external {
        employerId = _employerId;
    }

    function getEmployerIdFromJobId(uint256) public view returns (uint32) {
        return employerId;
    }

    function getJobIdFromEmployeeAndEmployer(address, uint32) external view returns (uint256) {
        return jobId;
    }

    function isEmployedBy(address _employee, uint32 _employerId) external view returns (bool) {
        // to allow mocking
        return employerId != 2;
    }
}
