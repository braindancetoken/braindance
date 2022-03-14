// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "hardhat/console.sol";

contract BDCToken is ERC20Capped {
    using Address for address;
    mapping(address => address) public referrers;
    mapping(address => address[]) private fans;

    constructor()
        ERC20("Brain Dance Computing", "BDC")
        ERC20Capped(6000000000 * 10**18)
    {
        _mint(msg.sender, 6000000000 * 10**18);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (
            referrers[to] == address(0) &&
            !from.isContract() &&
            !to.isContract()
        ) {
            referrers[to] = from;
            fans[from].push(to);
        }
    }

    function getFans(
        address account,
        uint256 page,
        uint256 size
    ) public view returns (address[] memory) {
        uint256 len = size;
        if (page * size + size > fans[account].length) {
            len = fans[account].length % size;
        }
        address[] memory _fans = new address[](len);
        uint256 startIdx = page * size;
        for (uint256 i = 0; i != size; i++) {
            if (startIdx + i >= fans[account].length) {
                break;
            }
            _fans[i] = fans[account][startIdx + i];
        }
        return _fans;
    }
}
