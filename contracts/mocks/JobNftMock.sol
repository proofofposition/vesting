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

    function canMintJob(string memory _uri, address _minter, uint32 _employerTokenId) external view returns (bool){
        return true;
    }

    function approveMint(address employee, string memory uri) external {
    }

    function mintItem(address employee) external {
        emit NewJob(employee);
    }

    constructor(string memory name, string memory symbol) ERC721('POPPNFT', 'POPPNFT') {}

    function mintFor(address employee) external{
        _mint(employee, 1);
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

    function getEmployerIdFromJobId(uint256 _jobId) public view returns (uint32) {
        return employerId;
    }

    function getJobIdFromEmployee(address _employee) public view returns (uint256) {
        return jobId;
    }
}
